classdef Data_Base < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        files_handler   % files paths handler obj
        pipeline        % data pipeline object
        data            % array of file data obj
        big_data_path   % big data path
    end

    methods (Access = public)
        %% constructor
        function obj = Data_Base(files_paths_handler, pipeline)
            % inputs:
            % - files_paths_handler: a files paths handler object with the
            % desired files to load and process
            % - pipeline: a my pipeline object 
        
            if isempty(files_paths_handler) % support empty objects
                return
            end

            obj.pipeline = pipeline;
            obj.files_handler = files_paths_handler;

            obj.process_files();
        end

%         function merge_with(obj, data_base) % not in use yet
%             % this function checks if recordings object are suitable for
%             % merging and merges them
%             obj.pipeline.merge_with(new_rec.pipeline);
%             obj.segmented_signal = cat(1, obj.segmented_signal, new_rec.segmented_signal); % needs to be sorted as well
%             obj.big_data_files_handler.merge(new_rec.big_data_files_handler, new_rec.pipeline);
%         end
        
        %% getters
        function sub_data_base = get_sub_data_base(obj, files_logical_idx)
            sub_data_base = copy(obj);
            sub_data_base.data = sub_data_base.data(files_logical_idx);
            sub_data_base.files_handler = copy(obj.files_handler);
            sub_data_base.files_handler.reject_path([], ~files_logical_idx);
        end

        function classes = get_classes(obj)
            classes = obj.pipeline.class_names;
        end

        function files_handler = get_files_handler(obj)
            files_handler = obj.files_handler;
        end

        function pipeline = get_pipeline(obj)
            pipeline = obj.pipeline;
        end

        function labels = get_labels(obj)
            [~, labels] = obj.get_data_info();
        end
        
        function data_store = get_data_store(obj, args)
            % this function is used to create a data store from the object
            % segments\features according to the value of 'feat_or_data'
            % property in the object's my_pipeline object.
            arguments
                obj
                args.oversample = false
                args.augment = false
            end

            ds = cell(length(obj.data),1);
            for i = 1:length(obj.data)
                ds{i} = obj.data(i).get_data_store(args.oversample);
            end

            data_store = MyCombinedDatastore(ds{:}); % same as CombinedDatastore but concatenate vertically!

            if args.augment
                data_store = obj.augment_data_store(data_store);
            end
        end
        
        function [segments_ends_time, labels, label_per_time_point, time, end_file_time ,names] = get_data_info(obj) % maybe add time as output
            time = 0; label_per_time_point = []; segments_ends_time = []; labels = []; end_file_time = []; names = {};
            for i = 1:length(obj.data)
                curr_label_per_time_point = obj.data(i).get_label_per_sample();
                curr_time = (1:length(curr_label_per_time_point)).'./obj.pipeline.sample_rate + time(end);
                curr_segments_end_times = obj.data(i).get_segments_end_times() + time(end);
                curr_lables = obj.data(i).get_labels();
                curr_name = obj.data(i).get_name();

                label_per_time_point = cat(1, label_per_time_point, curr_label_per_time_point);
                time = cat(1, time, curr_time);
                segments_ends_time = cat(1, segments_ends_time, curr_segments_end_times);
                labels = cat(1, labels, curr_lables);
                end_file_time = cat(1, end_file_time, time(end));
                names = cat(1, names, curr_name);
            end  
            time(1) = []; % remove initiale zero
        end

        function num_files = num_files(obj)
            num_files = obj.files_handler.get_number_of_files();
        end
        
        %% behavior methods
        function bool = isempty(obj)
            if isempty(obj.files_handler)
                bool = true;
            else
                bool = false;
            end
        end

        %% visualizations
        function print_data_distribution(obj, title)
            labels = obj.get_labels();
            disp([title 'data distribution']); 
            tabulate(labels)
        end
        
        function plot_segments(obj)
            % if no data just return
            if isempty(obj) 
                disp('no data to visualize segments predictions');
                return
            end

            [segments_ends_time, labels, label_per_time_point, rec_end] = obj.get_data_info();
            time = (0:(length(label_per_time_point) - 1))./obj.pipeline.sample_rate;

            % plot the labels and predictions over time
            figure();
            plot(time, label_per_time_point, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(segments_ends_time, labels, 'b_', 'MarkerSize', 2, 'LineWidth', 12); hold on;
            xlabel('time [sec]'); ylabel('labels'); legend({'movment timing', 'segments labels'}); xline(time(rec_end));
            title('segments labels over time');
        end

        function plot_segments_predictions(obj, predictions, args)
            % this function is used to visualize the model predictions
            % Inputs: title - a title for the plot ('train', 'val', 'test')
            arguments
                obj
                predictions
                args.group = 'new';
            end
            % if no data just return
            if isempty(obj) 
                disp('no data to visualize segments predictions');
                return
            end

            [segments_ends_time, labels, label_per_time_point, time, end_file_time, names] = obj.get_data_info();
            labels = addcats(labels, {'file name'});
            % plot the labels and predictions over time
            figure();
            plot(time, label_per_time_point, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(segments_ends_time(predictions == labels), predictions(predictions == labels), 'b_', 'MarkerSize', 2, 'LineWidth', 12); hold on;
            plot(segments_ends_time(predictions ~= labels), predictions(predictions ~= labels), 'black_', 'MarkerSize', 2, 'LineWidth', 12);
            xlabel('time [sec]'); ylabel('labels'); legend({'movment timing', 'predictions - correct', 'predictions - incorrect'});
            xline(end_file_time);
            offsets = cat(1, end_file_time(1)./2, diff(end_file_time)./2);
            x_loc = end_file_time - offsets;
            y_loc = repmat(categorical({'file name'}), numel(end_file_time), 1);
            txt = text(x_loc, y_loc, names, 'vert', 'middle', 'horiz', 'center');
            set(txt,'Rotation',90)
            title([args.group ' - segments predictions']);
        end
        
        function plot_gesture_predictions(obj, gesture_pred, gesture_pred_start_times, args)
            arguments
                obj
                gesture_pred
                gesture_pred_start_times
                args.group = 'new';
            end
            % if no data just return
            if isempty(obj) 
                disp('no data to visualize segments predictions');
                return
            end
            [seg_end_time, labels, label_per_sample, time, end_file_time, names] = obj.get_data_info();
            [gesture_true, gesture_true_start_time] = Gestures_Utils.get_true_gestures_from(seg_end_time, labels);

            % fix the gestures arrays to be aligned
            gest_CM = Gesture_CM(gesture_true, gesture_true_start_time, gesture_pred, gesture_pred_start_times);
            [gesture_true, gesture_true_start_time] = gest_CM.get_true_gestures();
            [gesture_pred, gesture_pred_start_times] = gest_CM.get_predicted_gestures();

            % plot the labels and predictions over time
            figure();
            plot(time, label_per_sample, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(gesture_pred_start_times, gesture_pred, 'bo', 'MarkerSize', 10)
            plot(gesture_true_start_time, gesture_true, 'blacko', 'MarkerSize', 6, 'MarkerFaceColor','auto')
            xlabel('time [sec]'); ylabel('labels'); legend({'movment timing', 'predicted gestures timings', 'true gestures timings'});
            xline(end_file_time);
            offsets = cat(1, end_file_time(1)./2, diff(end_file_time)./2);
            x_loc = end_file_time - offsets;
            y_loc = repmat(categorical({'file name'}), numel(end_file_time), 1);
            txt = text(x_loc, y_loc, names, 'vert', 'middle', 'horiz', 'center');
            set(txt,'Rotation',90)
            title([args.group ' - gestures predictions']);
        end

        function plot_signal(obj, args)
            % this function is used to visualize the signals in the object,
            % set the optional inputs to true for the desired visualizations. 
            arguments
                obj
                args.raw = false;
                args.filt = false;
                args.fft = false;
            end
            legend_names = {'channel 1','channel 2','channel 3','channel 4','channel 5',...
                'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'};
            % raw data
            if args.raw
                signal = []; x_lines = [];
                for i = 1:length(obj.data)
                    signal = cat(2, signal, obj.data(i).get_signal());
                    x_lines = cat(1, x_lines, length(signal));
                end
                figure("Name", 'raw data'); plot(signal.'); xline(x_lines);
                legend(legend_names); title('raw data');
            end
            % filtered raw data
            if args.filt
                filt_signal = []; x_lines = [];
                for i = 1:length(obj.data)
                    filt_signal = cat(2, filt_signal, obj.data(i).get_signal_filtered());
                    x_lines = cat(1, x_lines, length(filt_signal));
                end
                figure("Name", 'filtered data'); plot(filt_signal.'); xline(x_lines);
                legend(legend_names); title('filtered raw data');
                ylim(quantile(filt_signal(1,:), [0.05, 0.95]).*5)
            end
            % fft
            if args.fft
                figure('Name', 'fft - filtered raw data');
                num_rows = ceil(length(obj.data)/3);
                for i = 1:length(obj.data)
                    filt_signal = obj.data(i).get_signal_filtered();
                    [pxx_filt, freq_1] = pwelch(filt_signal.', obj.pipeline.sample_rate);
                    subplot(num_rows,3,i);
                    plot(freq_1(1:ceil(length(pxx_filt)/2)).*obj.pipeline.sample_rate./pi, pxx_filt(1:ceil(length(pxx_filt)/2),:).');
                    xlabel('frequency [HZ]'); ylabel('power [DB/HZ]');
                end
                legend(legend_names);
            end
        end
    
    end

    methods (Access = protected)
        function process_files(obj)
            f = waitbar(0, 'preprocessing data, pls wait');
            paths = obj.files_handler.get_paths();
            for i = 1:length(paths)
                waitbar(i/length(paths), f, ['preprocessing data, recording ' num2str(i) ' out of ' num2str(length(paths))]); % update the wait bar
                obj.add_data_from(paths{i});
            end
            delete(f); % close the wait bar
        end

        function add_data_from(obj, path)
            try
                file_data = File_Data(path, obj.pipeline);
            catch ME
                name = Files_Paths_Handler.path_to_name(path);
                switch ME.identifier
                    case 'FileLoader:SampleRate'
                        disp(['recording ' name ': ' ME.message newline 'This file is not being used']);
                        obj.files_handler.reject_path(path)
                    case '' 
                        disp(['recording ' name ': ' ME.message]);
                        obj.files_handler.reject_path(path)
                    otherwise
                        rethrow(ME)
                end
                return
            end

            if obj.pipeline.big_data
                obj.handle_big_data(file_data);
            end
            obj.data = cat(1, obj.data, file_data);
        end

        function handle_big_data(obj, file_data)
            if isempty(obj.big_data_path)
                obj.create_big_data_folder();  
            end
            file_data.invoke_big_data(obj.big_data_path)
        end

        function create_big_data_folder(obj)
            path_handler = Path_Handler();
            listing = dir(fullfile(path_handler.root_path, '9.data'));
            name_lst = extractfield(listing, 'name');
            name_lst(strcmp(name_lst,'.') | strcmp(name_lst,'..') | strcmp(name_lst, 'readme.txt')) = []; 
            if isempty(name_lst)
                folder_name = num2str(1, '%03.f');
            else
                name_lst = cellfun(@str2num, name_lst); % convert str to double
                folder_name = num2str(max(name_lst) + 1, '%03.f');
            end
            obj.big_data_path = fullfile(path_handler.root_path, '9.data', folder_name);
            mkdir(obj.big_data_path);
        end
    
        function data_store = augment_data_store(obj, data_store)
            % this function is used to create a new object with an
            % augmented data store, you can control the augmentations from
            % the constant object
            % Outputs: new_obj - a copy of the object with an augmented
            %                    data store
            if ~isempty(obj)
                % using global variable so we could transfer the
                % parameters into the augment_data function (can't use
                % them as inputs to the function...)
                global augmentation_params
                augmentation_params = obj.pipeline.augmentation_params;

                data_store = transform(data_store, @Segments_Utils.augment_data);
            end
        end
    end

    methods (Static)
        function labels = get_synched_labels_from_data_store(data_store)
            reset(data_store); % make sure all data is available to read
            labels = [];
            underlying_data_stores = data_store.UnderlyingDatastores;
            for i = 1:numel(underlying_data_stores)
                while hasdata(underlying_data_stores{i})
                    batch = read(underlying_data_stores{i});
                    curr_labels = cellfun(@(X) X, batch(:,2));
                    labels = cat(1, labels, curr_labels);
                end
                reset(underlying_data_stores{i});
            end
        end
        
        function labels = get_labels_from_data_store(data_store)
            reset(data_store); % make sure all data is available to read
            labels = [];
            while hasdata(data_store)
                batch = read(data_store);
                curr_labels = cellfun(@(X) X, batch(:,2));
                labels = cat(1, labels, curr_labels);
            end
            reset(data_store);
        end
    end
end
