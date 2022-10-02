classdef Stream_Markers < handle
    properties
        marker_stamps   % cell array with the marker names stream
        marker_latencies % numerical array with each marker latency
    end

    methods
        function obj = Stream_Markers(marker_stamps, latencies)
            obj.marker_stamps = marker_stamps;
            obj.marker_latencies = latencies;
        end

        function marker = get_latest_marker_before_sample_number(obj, sample_number)
            sample_diff = sample_number - obj.marker_latencies;
            latest_marker_index = find(sample_diff < 0, 1) - 1;
            if isempty(latest_marker_index)
                marker = obj.marker_stamps{end};
            else
                marker = obj.marker_stamps{latest_marker_index};
            end
        end

        function latencies = get_marker_latencies(obj, marker)
            indices = strcmp(obj.marker_stamps, marker);
            latencies = obj.marker_latencies(indices);
        end

        function adjust_latencies_by(obj, num)
            obj.marker_latencies = obj.marker_latencies + num;
        end
    end
end