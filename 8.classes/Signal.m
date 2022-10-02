classdef Signal < handle
    properties (SetAccess = protected)
        signal
        signal_filtered
        label_per_sample
        stream_markers
        pipeline
    end

    methods
        function obj = Signal(signal, stream_markers, pipeline)
            obj.signal = signal;
            obj.stream_markers = stream_markers;
            obj.pipeline = pipeline;

            obj.remove_redundant_electrodes();
            obj.reject_data_beyond_expirement();
            obj.signal_filtered = Segments_Utils.filter(obj.signal, obj.pipeline);
            obj.label_samples();
        end

        function signal = get_signal(obj)
            signal = obj.signal;
        end

        function filtered_signal = get_filtered_signal(obj)
            filtered_signal = obj.signal_filtered;
        end

        function label_per_sample = get_label_per_sample(obj)
            label_per_sample = obj.label_per_sample;
        end

        function sub_signal = get_sub_signal_from(obj, indices)
            sub_signal = obj.signal(:,indices);
        end

        function bool = is_physiological_at(obj, indices)
            % we need to check abnormalities in the filtered signal hence
            % we will convert the indices to match it (buffers have been removed) 
            indices_filt_sig = indices - obj.pipeline.buffer_start;
            % check for unphysiological amplitudes in the sub signal
            if max(max(abs(obj.signal_filtered(:,indices_filt_sig)))) > 100
                bool = false;
                return
            end
            % check for abnormalities in a chunk - area that includes the sub signal
            sample_rate = obj.pipeline.sample_rate;
            num_samples_before_segment = sample_rate*10; % manually selected values
            num_samples_after_segment = sample_rate*3;
            half_window = 10; 
            threshold = 20;

            chunk_indices = (indices_filt_sig(1) - num_samples_before_segment):(indices_filt_sig(end) + num_samples_after_segment);
            chunk_indices(chunk_indices < 1 | chunk_indices > size(obj.signal_filtered,2)) = []; % handle out of range indices

            [max_values, max_indices] = max(abs(obj.signal_filtered(:,chunk_indices)), [], 2);
            [~, max_idx] = max(max_values);
            idx = max_indices(max_idx) + chunk_indices(1);

            chunk_indices = (idx - half_window):(idx + half_window);
            chunk_indices(chunk_indices < 1 | chunk_indices > size(obj.signal_filtered,2)) = []; % handle out of range indices
            inspected_signal = obj.signal_filtered(:,chunk_indices);
            max_values = max(abs(inspected_signal), [], 2);
            max_values = sort(max_values, "descend");
            max_values_diff = max_values(1:end-1) - max_values(2:end);
            if any(max_values_diff > threshold)
                bool = false;
                return
            end
            bool = true; % if no abnormalities then return true...
        end

        function labels_per_sample = get_labels_by_indices(obj, indices)
            labels_per_sample = obj.label_per_sample(indices);
        end

        function num_electrodes = get_num_electrodes(obj)
            num_electrodes = size(obj.signal, 1);
        end

    end

    methods (Access = protected)
        function remove_redundant_electrodes(obj)
            electrodes_to_remove = obj.pipeline.electrodes_to_remove;
            obj.signal(electrodes_to_remove,:) = [];
        end

        function reject_data_beyond_expirement(obj)
            % reject data before\after expirement starts\ends
            start_latency = obj.stream_markers.get_marker_latencies(obj.pipeline.expi_start_marker);
            end_latency = obj.stream_markers.get_marker_latencies(obj.pipeline.expi_end_marker);

            obj.signal = obj.signal(:, start_latency:end_latency); % remove data
            obj.stream_markers.adjust_latencies_by(-start_latency + 1) % adjust the markers latencies to be aligned with the new signal
        end

        function label_samples(obj)
            num_samples_in_signal = size(obj.signal, 2);
            obj.label_per_sample = cell(num_samples_in_signal, 1);

            labels = Labels_Handler(obj.pipeline.class_names, obj.pipeline.class_markers);

            for i = 1:num_samples_in_signal
                last_marker = obj.stream_markers.get_latest_marker_before_sample_number(i);
                obj.label_per_sample{i} = labels.get_str_label_from_marker(last_marker); 
            end
            obj.label_per_sample = categorical(obj.label_per_sample);
        end

    end
end