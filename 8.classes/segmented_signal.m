classdef segmented_signal < handle
    properties (SetAccess = protected, GetAccess = protected)
        signal
        signal_filtered
        pipeline
        segments_signal             
        segments_features % extracted features
        segments_ends_idx % the time point that each segments ends in
        labels 
        markers
    end

    methods (Access = public)
        %% constructor
        function obj = segmented_signal(signal, markers, pipeline)
            if nargin == 0
                return
            end
            obj.pipeline = pipeline;
            obj.markers = markers;
            obj.signal = signal;
            obj.labels = Labels_Handler(pipeline.class_names, pipeline.class_marker);

            obj.reject_signal_times_unrelated_to_expirement();
            obj.signal_filtered = obj.create_filtered_signal();
            obj.segment_signal();
            obj.label_segments();
            obj.reject_marked_segments();

            obj.segments_signal = segment_preprocessing.filter(obj.segments_signal, obj.pipeline);
            obj.segments_signal = segment_preprocessing.create_sequence(obj.segments_signal, obj.pipeline);
            obj.segments_signal = segment_preprocessing.normalize(obj.segments_signal, obj.pipeline);
            obj.segments_features = segment_preprocessing.extract_features(obj.segments_signal, obj.pipeline);
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
        
        %% ds related functions
        function data_label_cell = create_data_label_cell(obj)
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

        function data_label_cell = create_data_label_cell_oversampled(obj)
            obj.oversample();
            data_label_cell = obj.create_data_label_cell();
            obj.undo_oversample();
        end

        function data_label_cell = create_data_label_cell_oversampled_only(obj)
            obj.oversample();
            data_label_cell = obj.create_data_label_cell();
            data_label_cell = data_label_cell(length(obj.segments_ends_idx) + 1:end, :);
            obj.undo_oversample();
        end

        %% getters
        function signal = get_signal(obj)
            signal = obj.signal;
        end

        function signal_filtered = get_signal_filtered(obj)
            signal_filtered = obj.signal_filtered;
        end

        function categorical_labels = get_categorical_labels(obj)
            categorical_labels = obj.labels.get_categorical_labels();
        end
    
        function label_per_sample = get_label_per_sample(obj)
            label_per_sample = obj.create_label_per_sample();
        end

        function segments_ends_idx = get_segments_ends_idx(obj)
            segments_ends_idx = obj.segments_ends_idx;
        end

    end
    
    methods (Access = protected)

        function signal_filtered = create_filtered_signal(obj)
            signal_filtered = segment_preprocessing.filter(obj.signal, obj.pipeline);
            buffer_start_size = obj.pipeline.buffer_start;
            signal_filtered = cat(2,zeros(size(obj.signal,1), buffer_start_size), signal_filtered); % pad with zeros to keep aligned with original signal
        end

        function reject_signal_times_unrelated_to_expirement(obj)
            % reject data before\after expirement starts\ends
            start_latency = obj.markers.get_marker_latencies(obj.pipeline.expi_start_marker);
            end_latency = obj.markers.get_marker_latencies(obj.pipeline.expi_end_marker);

            obj.signal = obj.signal(:, start_latency:end_latency); % remove data
            obj.markers.adjust_latencies_by(-start_latency + 1) % adjust the markers latencies to be aligned with the new signal
        end
 
        function segment_signal(obj)
            if strcmp(obj.pipeline.segmentation_method, 'continuous')
                obj.continuous_segmentation();
            else
                obj.discrete_segmentation();
            end
            % adjust segments dims to match matlab NN input layers - [Spatial Spatial Channel Batch]
            % we have a fixed Channel dim that equals 1...
            obj.segments_signal = permute(obj.segments_signal, [1 2 4 3]);  
        end

        function continuous_segmentation(obj)
            segments_step_size = obj.pipeline.segments_step_size_sec;
            buffer_end_size = obj.pipeline.buffer_end;

            num_segments = obj.calc_number_of_segments();
            num_samples_in_segment = obj.num_samples_in_segment('BC');
            num_electrodes = size(obj.signal, 1);
            obj.segments_signal = zeros(num_electrodes, num_samples_in_segment, num_segments);
            
            obj.segments_ends_idx = zeros(num_segments, 1);
            start_idx = 1;
            for i = 1:num_segments
                % create the ith segment
                segment_idx = (start_idx : start_idx + num_samples_in_segment - 1); % data indices to segment
                obj.segments_signal(:,:,i) = obj.signal(:,segment_idx); % enter the current segment into segments
                obj.segments_ends_idx(i) = segment_idx(end) - buffer_end_size;
                start_idx = start_idx + floor(segments_step_size*obj.pipeline.sample_rate); % add step size to the starting index
            end
        end

        function label_segments(obj)
            label_per_sample = obj.create_label_per_sample();
            % extract variables from the pipeline object
            segment_threshold = obj.pipeline.segment_labeling_threshold;
            num_segments = obj.calc_number_of_segments();
            
            labels_array = repmat({'idle'},num_segments,1);
            labels_array = categorical(labels_array);

            for i = 1:num_segments
                segment_indices = obj.get_signal_indices_of_segment_num(i);
                if obj.reject_segment_or_not(segment_indices)
                    labels_array(i) = 'reject';
                    continue
                end
                % find the ith label
                sample_label_indices = obj.get_signal_indices_for_labeling_of_segment_num(i);
                seg_samples_labels = label_per_sample(sample_label_indices);
                curr_labels = unique(seg_samples_labels);
                for j = 1:length(curr_labels)
                    class_percent = sum(seg_samples_labels == curr_labels(j))/length(seg_samples_labels);
                    if class_percent >= segment_threshold 
                        labels_array(i) = curr_labels(j);
                        break
                    end
                end
            end
            obj.labels.set_labels(labels_array);
        end
        
        function sample_label = create_label_per_sample(obj)
            num_samples_in_signal = size(obj.signal, 2);
            sample_label = cell(num_samples_in_signal, 1);

            for i = 1:num_samples_in_signal
                last_marker = obj.markers.get_latest_marker_before_sample_number(i);
                sample_label{i} = obj.labels.get_label_from_marker(last_marker); % assume its idle, if not it will be replaced
            end
            sample_label = categorical(sample_label);
            sample_label = reordercats(sample_label);
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

        function indices = get_signal_indices_of_segment_num(obj, num)
            switch obj.pipeline.segmentation_method
                case 'continuous'
                    segment_length = obj.num_samples_in_segment('AC');
                case 'discrete'
                    segment_length = obj.num_samples_in_segment('AD');
            end
            segment_end_idx = obj.segments_ends_idx(num);
            indices = (segment_end_idx - segment_length + 1):(obj.segments_ends_idx(num));
        end

        function indices = get_signal_indices_for_labeling_of_segment_num(obj, num)
            indices = obj.get_signal_indices_of_segment_num(num);

            sequence_len = obj.pipeline.sequence_len;
            seq_step_size = floor(obj.pipeline.sequence_step_size*obj.pipeline.sample_rate);
            % consider only the indices of the last segment in the sequence
            indices = indices(seq_step_size*(sequence_len - 1) + 1: end); 
        end

        function bool = reject_segment_or_not(obj, segment_indices)
            % check for unphysiological amplitudes in the segment
            if max(max(abs(obj.signal_filtered(:,segment_indices)))) > 100
                bool = true;
                return
            end
            % check for abnormalities in a chunk - area that includes the segment 
            sample_rate = obj.pipeline.sample_rate;
            num_samples_before_segment = sample_rate*10; % manually selected values
            num_samples_after_segment = sample_rate*3;
            half_window = 10; 
            threshold = 20;

            chunk_indices = (segment_indices(1) - num_samples_before_segment):(segment_indices(end) + num_samples_after_segment);
            chunk_indices = obj.handle_out_of_range_indices_for_signal(chunk_indices);

            [max_values, max_indices] = max(abs(obj.signal_filtered(:,chunk_indices)), [], 2);
            [~, max_idx] = max(max_values);
            idx = max_indices(max_idx) + chunk_indices(1);

            chunk_indices = (idx - half_window):(idx + half_window);
            chunk_indices = obj.handle_out_of_range_indices_for_signal(chunk_indices);
            inspected_signal = obj.signal_filtered(:,chunk_indices);
            max_values = max(abs(inspected_signal), [], 2);
            max_values = sort(max_values, "descend");
            max_values_diff = max_values(1:end-1) - max_values(2:end);
            if any(max_values_diff > threshold)
                bool = true;
                return
            end
            bool = false; % if no abnormalities then return false...
        end

        function indices = handle_out_of_range_indices_for_signal(obj, indices)
            indices(indices < 1 | indices > size(obj.signal,2)) = [];
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

        function reject_marked_segments(obj)
            reject_indices = obj.labels.reject_marked_labels();
            obj.segments_signal(:,:,:,reject_indices) = [];
            obj.segments_ends_idx(reject_indices) = [];
        end

        function oversample(obj)
            categorical_labels = obj.labels.get_categorical_labels();
            obj.segments_features = segment_preprocessing.oversample(obj.segments_features, categorical_labels);
            [obj.segments_signal, categorical_labels] = segment_preprocessing.oversample(obj.segments_signal, categorical_labels);
            obj.labels.set_labels(categorical_labels);
        end

        function undo_oversample(obj)
            num_original_segments = length(obj.segments_ends_idx);
            obj.segments_signal(:,:,:,:,num_original_segments + 1:end) = [];
            if ~isempty(obj.segments_features)
                obj.segments_features(:,:,:,:,num_original_segments + 1:end) = [];
            end
            categorical_labels = obj.labels.get_categorical_labels();
            categorical_labels(num_original_segments + 1:end) = [];
            obj.labels.set_labels(categorical_labels);
        end
    end
end
