classdef Big_Data_Files_Handler < handle
    properties (SetAccess = protected)
        path
    end

    methods
        function obj = Big_Data_Files_Handler(path)
            obj.path = path;
        end

        function set_segments_data(obj, segments)
        % save segments data in seperate files in the format - {time_series, label} and {features, label}
            mkdir(obj.path) 

            TS_label = segments.data_label_cell(data_type = 'time series');
            feat_label = segments.data_label_cell(data_type = 'features');

            TS_label_oversampled = segments.data_label_cell_oversampled_only(data_type = 'time series');
            feat_label_oversampled = segments.data_label_cell_oversampled_only(data_type = 'features');

            obj.save_time_series_label(TS_label);
            obj.save_oversampled_time_series_label(TS_label_oversampled);

            if ~isempty(feat_label)
                obj.save_feature_label(feat_label);
                obj.save_oversampled_feature_label(feat_label_oversampled);
            end

            segments.clear_segments(); % reduce memory usage
        end

        function [time_series, features, labels] = get_segments_data(obj, args)
            arguments
                obj
                args.oversampled = false
            end
            [time_series, features, labels] = obj.load_segments_data(args.oversampled);
        end

%         function set_signal(obj, signal) % to be built
% 
%         end
        
%         function get_signal(obj) % to be built
% 
%         end
        
        function paths = get_data_store_paths(obj, args)
            arguments
                obj
                args.oversampled = false
            end
            if exist(fullfile(obj.path, 'features', 'source'), 'dir')
                paths{1} = fullfile(obj.path, 'features', 'source');
                if args.oversampled
                    paths{2} = fullfile(obj.path, 'features', 'oversampled');
                end
            else
                paths{1} = fullfile(obj.path, 'time series', 'source');
                if args.oversampled
                    paths{2} = fullfile(obj.path, 'time series', 'oversampled');
                end
            end
        end
        
        %% save data files methods - consider merging the functions into one function
        function save_time_series_label(obj, time_series_label)
            folder_path = fullfile(obj.path, 'time series', 'source');
            mkdir(folder_path);
            obj.save_data_in_seperate_files(time_series_label, folder_path)
        end

        function save_oversampled_time_series_label(obj, time_series_label)
            folder_path = fullfile(obj.path, 'time series', 'oversampled');
            mkdir(folder_path);
            obj.save_data_in_seperate_files(time_series_label, folder_path)
        end

        function save_feature_label(obj, feature_label)
            folder_path = fullfile(obj.path, 'features', 'source');
            mkdir(folder_path);
            obj.save_data_in_seperate_files(feature_label, folder_path)
        end

        function save_oversampled_feature_label(obj, feature_label)
            folder_path = fullfile(obj.path, 'features', 'oversampled');
            mkdir(folder_path);
            obj.save_data_in_seperate_files(feature_label, folder_path)
        end

        function save_data_in_seperate_files(~, data, folder_path)
            for i = 1:length(data)
                S.('data') = data(i,:);
                save(fullfile(folder_path, num2str(i,'%05.f')), '-struct', 'S');
            end
        end
        
        %% load data files methods - consider merging some of these functions
        function [time_series, features, labels] = load_segments_data(obj)
            [time_series, labels] = obj.load_time_series_label();
            features = obj.load_feature_label();
        end

        function [time_series, labels] = load_time_series_label(obj)
            folder_path = fullfile(obj.path, 'time series', 'source', '*.mat');
            [time_series, labels] = obj.load_and_concat_files_from(folder_path);
        end

        function [features, labels] = load_feature_label(obj)
            folder_path = fullfile(obj.path, 'feature', 'source', '*.mat');
            [features, labels] = obj.load_and_concat_files_from(folder_path);
        end

        function [time_series, labels] = load_oversampled_time_series_label(obj)
            folder_path = fullfile(obj.path, 'time series', 'oversampled', '*.mat');
            [time_series, labels] = obj.load_and_concat_files_from(folder_path);
        end

        function [features, labels] = load_oversampled_feature_label(obj)
            folder_path = fullfile(obj.path, 'feature', 'oversampled', '*.mat');
            [features, labels] = obj.load_and_concat_files_from(folder_path);
        end

        function [data, labels] = load_and_concat_files_from(~, folder_path)
            files = dir(folder_path);
            data_labels = {};
            for j = 1:length(files)
                load(fullfile(files(j).folder, files(j).name), 'data')
                data_labels = cat(1, data_labels, data);
            end
            labels = cellfun(@double, data_labels(:,2));
            data = cell2mat(permute(data_labels(:,1), [2,3,4,5,1]));
        end
    end
end
