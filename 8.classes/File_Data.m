classdef File_Data < handle
    properties (SetAccess = private)
        name
        file_loader
        signal
        segments
        big_data_handler
    end

    properties (SetAccess = protected)
        pipeline
    end
    
    methods
        function obj = File_Data(path, pipeline)
            obj.pipeline = pipeline;
            obj.name = Files_Paths_Handler.path_to_name(path); % maybe change the way we get the name from path
            obj.create_file_loader(path);

            obj.file_loader.verify_reliable_file(obj.pipeline);

            [signal_array, markers] = obj.file_loader.get_signal_and_markers();

            obj.signal = Signal(signal_array, markers, obj.pipeline);
            obj.segments = Segments(obj.signal, obj.pipeline);

        end

        function signal = get_signal(obj)
            signal = obj.signal.get_signal();
        end

        function signal = get_filtered_signal(obj)
            signal = obj.signal.get_filtered_signal();
        end

        function label_per_sample = get_label_per_sample(obj)
            label_per_sample = obj.signal.get_label_per_sample();
        end
        
        function [time_series, features, labels] = get_segments_data(obj)
            if isempty(obj.big_data_handler)
                [time_series, features, labels] = obj.segments.get_segments_data();
            else
                [time_series, features, labels] = obj.big_data_handler.load_segments_data();
            end
        end

        function labels = get_labels(obj)
            labels = obj.segments.get_labels();
        end

        function segments_end_times = get_segments_end_times(obj)
            segments_end_idx = obj.segments.get_segments_ends_idx();
            segments_end_times = segments_end_idx./obj.pipeline.sample_rate;
        end

        function data_store = get_data_store(obj, oversample)
            if isempty(obj.big_data_handler)
                data_label_cell = obj.segments.data_label_cell(oversampled = oversample);
                data_store = arrayDatastore(data_label_cell, 'ReadSize', 1, 'IterationDimension', 1, 'OutputType', 'same'); 
            else
                ds_paths = obj.big_data_handler.get_data_store_paths(oversampled = oversample);
                ds_file_set = matlab.io.datastore.FileSet(ds_paths);
                data_store = fileDatastore(ds_file_set, "ReadFcn", @load_data, 'UniformRead',true, ...
                    "FileExtensions", ".mat");
            end

            % the loading file function for the file datastore
            function data = load_data(file)
                load(file, 'data')
            end
        end

        function name = get_name(obj)
            name = obj.name;
        end
    end

    methods (Access = ?Data_Base)
        function invoke_big_data(obj, path)
            % need to add signal big data handling!
            path = fullfile(path, obj.name);
            obj.big_data_handler = Big_Data_Files_Handler(path);
            
            obj.big_data_handler.set_segments_data(obj.segments);
%             obj.big_data_handler.set_signal_data(obj.signal);
        end
    end

    methods (Access = protected)
        function create_file_loader(obj, path)
            [~, ~, file_extention] = fileparts(path);
            full_path = which(path);
            switch lower(file_extention)
                case '.xdf'
                    obj.file_loader = Xdf_File_Loader(full_path);
                case '.edf'
                    obj.file_loader = Edf_File_Loader(full_path);
            end
        end

    end

end