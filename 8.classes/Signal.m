classdef Signal < handle
    properties
        signal
        label_per_sample
        stream_markers
        pipeline
    end

    methods
        function obj = Signal(signal, stream_markers, pipeline)
            obj.signal = signal;
            obj.stream_markers = stream_markers;
            obj.pipeline = pipeline;

            obj.reject_data_beyond_expirement();
            obj.label_samples();
        end

        function signal = get_signal(obj)
            signal = obj.signal;
        end

        function filtered_signal = get_filtered_signal(obj)
            filtered_signal = Segment_Utils.filter(obj.signal);
        end

        function label_per_sample = get_label_per_sample(obj)
            label_per_sample = obj.label_per_sample;
        end

        function segment = get_sub_signal_by_indices(obj, indices)
            segment = obj.signal(indices);
            if obj.is_unphysiological(segment)
                segment = [];
            end
        end

        function labels_per_sample = get_labels_by_indices(obj, indices)
            labels_per_sample = obj.label_per_sample(indices);
        end

        function num_electrodes = get_num_electrodes(obj)
            num_electrodes = size(obj.signal, 1);
        end

    end

    methods (Access = protected)
        function label_samples(obj)
            num_samples_in_signal = size(obj.signal, 2);
            obj.label_per_sample = cell(num_samples_in_signal, 1);

            for i = 1:num_samples_in_signal
                last_marker = obj.stream_markers.get_latest_marker_before_sample_number(i);
                obj.label_per_sample{i} = obj.labels.get_label_from_marker(last_marker); % assume its idle, if not it will be replaced
            end
            obj.label_per_sample = cellfun(@(X) X, obj.label_per_sample);
        end
   
        function reject_data_beyond_expirement(obj)
            % reject data before\after expirement starts\ends
            start_latency = obj.stream_markers.get_marker_latencies(obj.pipeline.expi_start_marker);
            end_latency = obj.stream_markers.get_marker_latencies(obj.pipeline.expi_end_marker);

            obj.signal = obj.signal(:, start_latency:end_latency); % remove data
            obj.stream_markers.adjust_latencies_by(-start_latency + 1) % adjust the markers latencies to be aligned with the new signal
        end

    end
end