classdef Segments < handle
    properties (SetAccess = protected)
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
            obj.labels = Labels_Handler(pipeline.class_names, pipeline.class_markers);

            obj.segment_signal(signal);
            
            obj.segments_signal = Segments_Utils.filter(obj.segments_signal, obj.pipeline);
            obj.segments_signal = Segments_Utils.create_sequence(obj.segments_signal, obj.pipeline);
            obj.segments_signal = Segments_Utils.normalize(obj.segments_signal, obj.pipeline);
            obj.segments_features = Segments_Utils.extract_features(obj.segments_signal, obj.pipeline);
        end

        %% getters
        function labels = get_labels(obj)
            labels = obj.labels.get_labels();
        end
   
        function segments_ends_idx = get_segments_ends_idx(obj)
            segments_ends_idx = obj.segments_ends_idx;
        end

        function [time_series, features, labels] = get_segments_data(obj)
            time_series = obj.segments_signal;
            features = obj.segments_features;
            labels = obj.get_labels();
        end

        function data_label_cell = data_label_cell(obj, args)
            arguments
                obj
                args.data_type = [];
                args.oversampled = false
            end

            if isempty(args.data_type)
                if isempty(obj.segments_features)
                    args.data_type = 'time series';
                else
                    args.data_type = 'features';
                end
            end
            
            if args.oversampled
                obj.oversample();
            end

            labels_array = obj.labels.get_cell_of_categorical_labels();
            if strcmp(args.data_type, 'time series')
                data = obj.segments_signal;
            elseif strcmp(args.data_type, 'features')
                data = obj.segments_features;
            else
                error(['data type "' args.data_type '" is not supported, choose from {"features", "time series"}']);
            end

            if args.oversampled
                obj.undo_oversample();
            end

            if isempty(data)
                data_label_cell = [];
                return
            end
            
            data = squeeze(num2cell(data, [1,2,3,4]));
            data_label_cell = [data, labels_array];
        end

        function data_label_cell = data_label_cell_oversampled_only(obj, args)
            arguments
                obj
                args.data_type
            end

            data_label_cell = obj.data_label_cell(data_type = args.data_type, oversampled = true);
            last_original_segment_idx = length(obj.segments_ends_idx);
            data_label_cell = data_label_cell(last_original_segment_idx + 1:end, :);
        end
    
        function clear_segments(obj)
            obj.segments_signal = [];
            obj.segments_features = [];
        end
        
    end
    
    methods (Access = protected)

        function segment_signal(obj, signal)
            obj.continuous_segmentation(signal);

            % adjust segments dims to match matlab NN input layers - [Spatial Spatial Channel Batch]
            % we have a fixed Channel dim that equals 1...
            % if you create a sequence it will turn into [Spatial Spatial Channel sequence Batch]
            obj.segments_signal = permute(obj.segments_signal, [1 2 4 3]);  
        end

        function continuous_segmentation(obj, signal)
            % initialize place holders
            signal_len = size(signal.get_signal, 2);
            num_segments = obj.calc_number_of_segments(signal_len);
            num_samples_in_segment = obj.num_samples_in_segment('B');
            num_electrodes = signal.get_num_electrodes(); 
            obj.segments_signal = zeros(num_electrodes, num_samples_in_segment, num_segments);
            obj.segments_ends_idx = zeros(num_segments, 1);
            labels_str_cell = cell(num_segments,1);

            reject_idx = [];
            start_idx = 1;
            buffer_end_len = obj.pipeline.buffer_end;
            step_size = floor(obj.pipeline.segments_step_size_sec*obj.pipeline.sample_rate);

            for i = 1:num_segments
                data_indices = (start_idx : start_idx + num_samples_in_segment - 1);
                indices_for_physo_check = data_indices(obj.pipeline.buffer_start + 1:end - obj.pipeline.buffer_end);
                if signal.is_physiological_at(indices_for_physo_check)
                    % create the ith segment and its label
                    obj.segments_signal(:,:,i) = signal.get_sub_signal_from(data_indices); 
                    obj.segments_ends_idx(i) = data_indices(end) - buffer_end_len;
    
                    labels_indices = obj.data_indices_to_label_indices(data_indices);
                    samples_labels = signal.get_labels_by_indices(labels_indices);
                    labels_str_cell{i} = obj.str_label_from_samples_labels(samples_labels);
                else 
                    reject_idx(end + 1) = i; %#ok<AGROW> 
                end
                start_idx = start_idx + step_size; 
            end
            % remove unused segments data
            obj.segments_signal(:,:,reject_idx) = [];
            obj.segments_ends_idx(reject_idx) = [];
            labels_str_cell(reject_idx) = [];

            obj.labels.set_labels(labels_str_cell)
        end

        function num_segments = calc_number_of_segments(obj, num_samples_in_signal)
            step_size = floor(obj.pipeline.segments_step_size_sec*obj.pipeline.sample_rate);
            num_samples_in_segment = obj.num_samples_in_segment('B');
            num_segments = floor((num_samples_in_signal - num_samples_in_segment)/step_size) + 1;
        end

        function num_samples = num_samples_in_segment(obj, string)
            segment_duration   = obj.pipeline.segment_duration_sec;
            sequence_len       = obj.pipeline.sequence_len;
            sequence_step_size = obj.pipeline.sequence_step_size;
            buffer_start       = obj.pipeline.buffer_start;
            buffer_end         = obj.pipeline.buffer_end;
            sample_rate        = obj.pipeline.sample_rate;

            switch string
                case 'B' % Before (filters and sequencing) 
                    num_samples = floor(segment_duration*sample_rate) + buffer_start + buffer_end +...
                                  floor(sequence_step_size*sample_rate)*(sequence_len - 1);
                case 'A' % After (filters and sequencing) 
                    num_samples = floor(segment_duration*sample_rate);
            end
        end

        function indices = data_indices_to_label_indices(obj, indices)
            % trim the buffers indices
            buffer_start = obj.pipeline.buffer_start;
            buffer_end = obj.pipeline.buffer_end;
            indices = indices(buffer_start + 1: end - buffer_end);

            % consider only the last segment indices in the sequence
            sequence_len = obj.pipeline.sequence_len;
            seq_step_size = floor(obj.pipeline.sequence_step_size*obj.pipeline.sample_rate);
            indices = indices(seq_step_size*(sequence_len - 1) + 1: end); 
        end

        function label = str_label_from_samples_labels(obj, samples_labels)
            threshold = obj.pipeline.segment_labeling_threshold;
            catg = categories(samples_labels);
            count = countcats(samples_labels);
            percentages = count./length(samples_labels);

            idle_idx = strcmpi(catg, 'idle');
            catg(idle_idx) = [];
            percentages(idle_idx) = [];

            if any(percentages > threshold)
                [~, I] = max(percentages); % in case we got more than 1 class
                label = catg{I};
            else
                label = 'idle'; 
            end
        end


        function oversample(obj)
            labels_array = obj.labels.get_labels();
            obj.segments_features = Segments_Utils.oversample(obj.segments_features, labels_array);
            [obj.segments_signal, labels_array] = Segments_Utils.oversample(obj.segments_signal, labels_array);
            obj.labels.set_labels(labels_array);
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