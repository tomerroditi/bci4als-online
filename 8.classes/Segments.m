classdef Segments < handle
    properties (SetAccess = protected, GetAccess = protected)
        file_name

        signal
        pipeline
        segments_signal             
        segments_features % extracted features
        segments_ends_idx % the sample index that each segment ends in
        labels
        
    end

    methods (Access = public)
        %% constructor
        function obj = Segments(signal, pipeline)
            if nargin == 0
                return
            end
            obj.pipeline = pipeline;
            obj.signal = signal;
            obj.labels = Labels_Handler(pipeline.class_names, pipeline.class_markers);

            obj.segment_signal();

            segment_utils = Segments_Utils(obj.pipeline);

            bool_array = segment_utils.is_unphysiological(obj.segments_signal, obj.segments_ends_idx, signal.get_filtered_signal);

            obj.reject_unphysiological_segments(bool_array);
            
            obj.segments_signal = segment_utils.filter(obj.segments_signal);
            obj.segments_signal = segment_utils.create_sequence(obj.segments_signal);
            obj.segments_signal = segment_utils.normalize(obj.segments_signal);
            obj.segments_features = segment_utils.extract_features(obj.segments_signal);
        end

        %% 
        function bool = isempty(obj)
            if isempty(obj.segments_signal)
                bool = true;
            else
                bool = false;
            end
        end
        
        function clear_segments(obj)
            obj.segments_signal = [];
            obj.segments_features = [];
        end
        
        function set_file_name(obj, name)
            obj.file_name = name;
        end

        %% getters
        function labels = get_labels(obj)
            labels = obj.labels.get_labels();
        end
   
        function segments_ends_idx = get_segments_ends_idx(obj)
            segments_ends_idx = obj.segments_ends_idx;
        end
        
        function data_store = get_data_store(obj, oversample)
            if oversample
                data_label_cell = obj.data_label_cell_oversampled();
            else
                data_label_cell = obj.data_label_cell();
            end
            data_store = arrayDatastore(data_label_cell, 'ReadSize', 1, 'IterationDimension', 1, 'OutputType', 'same');
        end
end
    
    methods (Access = protected)
        function segment_signal(obj)
            if strcmp(obj.pipeline.segmentation_method, 'continuous')
                obj.continuous_segmentation();
            else
                obj.discrete_segmentation(); % not implemented yet
            end
            % adjust segments dims to match matlab NN input layers - [Spatial Spatial Channel Batch]
            % we have a fixed Channel dim that equals 1...
            obj.segments_signal = permute(obj.segments_signal, [1 2 4 3]);  
        end

        function continuous_segmentation(obj)
            segments_step_size = obj.pipeline.segments_step_size_sec;
            buffer_end_size = obj.pipeline.buffer_end;

            % initialize a place holder for segments_signal
            num_segments = obj.calc_number_of_segments();
            num_samples_in_segment = obj.num_samples_in_segment('BC');
            num_electrodes = obj.signal.get_num_electrodes(); 
            obj.segments_signal = zeros(num_electrodes, num_samples_in_segment, num_segments);
            
            obj.segments_ends_idx = zeros(num_segments, 1);

            start_idx = 1;
            step_size = floor(segments_step_size*obj.pipeline.sample_rate);
            for i = 1:num_segments
                % create the ith segment and its label
                data_indices = (start_idx : start_idx + num_samples_in_segment - 1); % data indices to segment
                obj.segments_signal(:,:,i) = obj.signal.get_sub_signal_by_indices(data_indices); % enter the current segment into segments
                obj.segments_ends_idx(i) = data_indices(end) - buffer_end_size;

                labels_indices = obj.data_indices_to_label_indices(data_indices);
                samples_labels = obj.signal.get_labels_by_indices(labels_indices);
                label = obj.label_from_samples_labels(samples_labels);
                obj.labels.append(label)

                start_idx = start_idx + step_size; % add step size to the starting index
            end
        end

        function num_segments = calc_number_of_segments(obj)
            switch obj.pipeline.segmentation_method
                case 'continuous'
                    step_size = floor(obj.pipeline.segments_step_size_sec*obj.pipeline.sample_rate);
                    num_samples = obj.num_samples_in_segment('BC');
                    num_segments = floor((size(obj.signal,2) - num_samples)/step_size) + 1;
                case 'discrete'

            end
        end

        function indices = data_indices_to_label_indices(obj, indices)
            sequence_len = obj.pipeline.sequence_len;
            seq_step_size = floor(obj.pipeline.sequence_step_size*obj.pipeline.sample_rate);
            % consider only the indices of the last segment in the sequence
            indices = indices(seq_step_size*(sequence_len - 1) + 1: end); 
        end

        function label = label_from_samples_labels(obj, samples_labels)
            label = 'idle'; % we will label as idle if no class passes the threshold percentage
            segment_threshold = obj.pipeline.segment_labeling_threshold;
            curr_labels = unique(samples_labels);
            for j = 1:length(curr_labels)
                class_percent = sum(samples_labels == curr_labels(j))/length(samples_labels);
                if class_percent >= segment_threshold 
                    label = curr_labels(j);
                    break
                end
            end
        end
       
        function reject_unphysiological_segments(obj, reject_indices)
            obj.segments_signal(:,:,:,reject_indices) = [];
            obj.segments_ends_idx(reject_indices) = [];
            obj.labels.reject_by_idx(reject_indices);
        end

        function num_samples = num_samples_in_segment(obj, string)
            segment_duration   = obj.pipeline.segment_duration_sec;
            sequence_len       = obj.pipeline.sequence_len;
            sequence_step_size = obj.pipeline.sequence_step_size;
            buffer_start       = obj.pipeline.buffer_start;
            buffer_end         = obj.pipeline.buffer_end;
            sample_rate        = obj.pipeline.sample_rate;

            switch string
                case 'BC' % Before (filters and sequencing), Continuous 
                    num_samples = floor(segment_duration*sample_rate) + buffer_start + buffer_end +...
                                  floor(sequence_step_size*sample_rate)*(sequence_len - 1);
                case 'AC' % After (filters and sequencing), Continuous 
                    num_samples = floor(segment_duration*sample_rate);
                case 'BD' % Before (filters and sequencing), Discrete 

                case 'AD' % After (filters and sequencing), Discrete 
            end
        end




        function data_label_cell = data_label_cell(obj)
            % create cells of the labels - notice we need to feed the datastore with
            % categorical instead of numeric labels
            categorical_labels = obj.labels.get_cell_of_categorical_labels();
            if isempty(obj.segments_features)
                data = obj.segments_signal;
            else
                data = obj.segments_features;
            end
            data = squeeze(num2cell(data, [1,2,3,4]));
            data_label_cell = [data, categorical_labels];
        end

        function data_label_cell = data_label_cell_oversampled(obj)
            obj.oversample();
            data_label_cell = obj.data_label_cell();
            obj.undo_oversample();
        end

        function data_label_cell = data_label_cell_oversampled_only(obj)
            obj.oversample();
            data_label_cell = obj.data_label_cell();
            data_label_cell = data_label_cell(:, length(obj.segments_ends_idx) + 1:end);
            obj.undo_oversample();
        end
        
        function oversample(obj)
            labels = obj.labels.get_labels();
            obj.segments_features = segment_preprocessing.oversample(obj.segments_features, labels);
            [obj.segments_signal, labels] = segment_preprocessing.oversample(obj.segments_signal, labels);
            obj.labels.set_labels(labels);
        end

        function undo_oversample(obj)
            num_original_segments = length(obj.segments_ends_idx);
            obj.segments_signal(:,:,:,:,num_original_segments + 1:end) = [];
            if ~isempty(obj.segments_features)
                obj.segments_features(:,:,:,:,num_original_segments + 1:end) = [];
            end
            categorical_labels = obj.labels.get_labels();
            categorical_labels(num_original_segments + 1:end) = [];
            obj.labels.set_labels(categorical_labels);
        end
    end
end
