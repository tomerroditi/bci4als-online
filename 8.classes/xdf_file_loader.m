classdef xdf_file_loader < file_loader
    properties
        signal_structure
        markers_structure
    end

    methods 
        function obj = xdf_file_loader(file_path)
            [~, xdf_struct] = evalc("load_xdf([file_path '\EEG.xdf'])"); % suppress anoying warnings
            if length(fields(xdf_struct{1})) == 4
                obj.signal_structure = xdf_struct{1};
                obj.markers_structure = xdf_struct{2};
            else
                obj.signal_structure = xdf_struct{2};
                obj.markers_structure = xdf_struct{1};
            end
        end

        function [signal, markers] = get_signal_and_markers(obj)
            signal = obj.extract_raw_signal();
            markers = obj.extract_markers();
        end

        function signal = extract_raw_signal(obj)
            signal  = obj.signal_structure.time_series;
        end

        function markers = extract_markers(obj)
            latencies = obj.calc_latencies_of_markers();
            marker_stamps =  obj.markers_structure.time_series;
            markers = stream_markers(marker_stamps, latencies);
        end

        function latencies = calc_latencies_of_markers(obj)
            markers_time_stamps  = obj.markers_structure.time_stamps;
            signal_time_stamps = obj.signal_structure.time_stamps;
            latencies = zeros(size(markers_time_stamps));
            % latencies are the number of samples in the signal stream
            % before each marker time stamps 
            for i = 1:length(latencies)
                [~,I] = min(abs(signal_time_stamps - markers_time_stamps(i))); % streams are not synced hence we get the closest time point
                latencies(i) = I;
            end
        end

        function [bool, effective_sample_rate] = should_be_rejected_due_sample_rate(obj, desired_sample_rate)
            effective_sample_rate = obj.signal_structure.info.effective_srate;
            if effective_sample_rate > desired_sample_rate + 0.5 || effective_sample_rate < desired_sample_rate - 0.5
                bool = true;
            else
                bool = false;
            end
        end
    end
end