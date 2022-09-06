classdef big_data_files_handler < handle
    properties (SetAccess = protected, GetAccess = protected)
        path
        recordings_names = {};
    end

    methods
        % constructor - just create a new folder and store its path in the object property 
        function obj = big_data_files_handler()
            listing = dir('9.data');
            names = extractfield(listing, 'name');
            names(strcmp(names,'.') | strcmp(names,'..') | strcmp(names, 'readme.txt')) = []; 
            if isempty(names)
                folder_name = num2str(1, '%03.f');
            else
                names = cellfun(@str2num, names); % convert str to double
                folder_name = num2str(max(names) + 1, '%03.f');
            end
            obj.path = fullfile('9.data', folder_name); % refer to the local path within the package scope
            mkdir(obj.path);
        end

        function merge(obj, big_data_files_handler)
            % need to build that
        end

        %% save recording segments data in seperate files in the format - {time_series, label} & {features, label}
        function add_segmented_signal(obj, segmented_signal, rec_name)
            % will need to add in the future saving of both segments and
            % features regardless of what we use to train the model
            obj.add_recording_name(rec_name);
            obj.create_folder_for_saved_data(rec_name);

            data_label = segmented_signal.create_data_label_cell();
            data_label_oversampled_only = segmented_signal.create_data_label_cell_oversampled_only();

            obj.save_time_series_label(data_label, rec_name);
            obj.save_oversampled_time_series_label(data_label_oversampled_only, rec_name);
        end

        function add_recording_name(obj, recording_name)
            obj.recordings_names = cat(1, obj.recordings_names, recording_name);
        end

        function folder_path = create_folder_for_saved_data(obj, recording_name)
            folder_path = fullfile(obj.path, recording_name);
            mkdir(folder_path);
        end

        function save_time_series_label(obj, time_series_label, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'time series', 'source');
            mkdir(folder_path);
            obj.save_data_in_single_files(time_series_label, folder_path)
        end

        function save_feature_label(obj, feature_label, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'features', 'source');
            mkdir(folder_path);
            obj.save_data_in_single_files(feature_label, folder_path)
        end

        function save_oversampled_time_series_label(obj, time_series_label, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'time series', 'oversampled');
            mkdir(folder_path);
            obj.save_data_in_single_files(time_series_label, folder_path)
        end

        function save_oversampled_feature_label(obj, feature_label, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'features', 'oversampled');
            mkdir(folder_path);
            obj.save_data_in_single_files(feature_label, folder_path)
        end

        %% load recording files - segments, features, labels
        function [time_series, features, labels] = load_recording_data(obj, recording_name)
            [time_series, labels] = obj.load_time_series_label(recording_name);
            features = obj.load_feature_label(recording_name);
        end

        function [time_series, labels] = load_time_series_label(obj, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'time series', 'source', '*.mat');
            files = dir(folder_path);
            [time_series, labels] = load_and_concat_data_files(files);
        end

        function [time_series, labels] = load_feature_label(obj, recording_name)
            folder_path = fullfile(obj.path, recording_name, 'feature', 'source', '*.mat');
            files = dir(folder_path);
            [time_series, labels] = load_and_concat_data_files(files);
        end
    end

    methods (Static)
        function save_data_in_single_files(data, folder_path)
            for i = 1:length(data)
                S.('data') = data{i};
                save(fullfile(folder_path, num2str(i,'%05.f')), '-struct', 'S');
            end
        end

        function [data, labels] = load_and_concat_data_files(files)
            data_labels = {};
            for j = 1:length(files)
                load(fullfile(files(j).folder, files(j).name))
                data_labels = cat(1, data_labels, data);
            end
            labels = cellfun(@double, data_labels(:,2));
            data = cell2mat(permute(data_labels(:,1), [2,3,4,5,1]));
        end
    end
end
