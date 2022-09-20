classdef recording < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        files_handler
        pipeline                % my pipeline object
        signals
        segments        % segmented signal object
        big_data_files_handler  % big data files handler object
        use_big_data = false;
    end

    methods (Access = public)
        %% constructor
        function obj = recording(files_paths_handler, pipeline)
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

%         function merge_recordings(obj, new_rec) % not in use yet
%             % this function checks if recordings object are suitable for
%             % merging and merges them
%             obj.pipeline.merge_with(new_rec.pipeline);
%             obj.segmented_signal = cat(1, obj.segmented_signal, new_rec.segmented_signal); % needs to be sorted as well
%             obj.big_data_files_handler.merge(new_rec.big_data_files_handler, new_rec.pipeline);
%         end
        
        %% getters
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
            labels = [];
            for i = 1:length(obj.segments)
                labels = cat(1, labels, obj.segments(i).get_labels());
            end
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

            ds = cell(length(obj.segments),1);
            for i = 1:length(obj.segments)
                ds{i} = obj.segments(i).get_data_store(args.oversample);
            end

            data_store = MyCombinedDatastore(ds{:}); % same as CombinedDatastore but concatenate vertically!

            if args.augment
                data_store = obj.augment_data_store(data_store);
            end
        end
        
        function [gestures, gest_start_indices] = get_gestures(obj) % to be removed
            % this function is used to extract the executed gestures and their indices (respectively to the labels)
            % in the recording

            [seg_end_idx, labels] = obj.segments_info();

            not_idle_indices = labels ~= 'idle';

            difference = diff(not_idle_indices);
            new_gest_start_indices = find(difference == 1) + 1;
            if not_idle_indices(1) == 1
                new_gest_start_indices = cat(1, 1, new_gest_start_indices); % add the first gesture
            end

            gestures = labels(new_gest_start_indices);
            gest_start_indices = seg_end_idx(new_gest_start_indices);
        end
        
        function [gestures, gest_start_indices] = get_predicted_gestures(obj, segment_label_pred, confidence, cool_time)% to be removed
            [gestures, gest_start_indices] = obj.labels_to_gestures(segment_label_pred, confidence, cool_time);
        end

        %% overriding behavior methods
        function bool = isempty(obj)
            if isempty(obj.files_handler)
                bool = true;
            else
                bool = false;
            end
        end

        %% visualizations
        function print_data_distribution(obj, title)
            labels = [];
            for i = 1:length(obj.segments)
                labels = cat(1, labels, obj.segments(i).get_labels());
            end
            disp([title 'data distribution']); 
            tabulate(labels)
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

            [segments_ends_idx, labels, label_per_sample, rec_end] = obj.segments_info();
            time = (0:(length(label_per_sample) - 1))./obj.pipeline.sample_rate;
            segments_ends_time = time(segments_ends_idx);

            % plot the labels and predictions over time
            figure();
            plot(time, label_per_sample, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(segments_ends_time(predictions == labels), predictions(predictions == labels), 'b_', 'MarkerSize', 2, 'LineWidth', 12); hold on;
            plot(segments_ends_time(predictions ~= labels), predictions(predictions ~= labels), 'black_', 'MarkerSize', 2, 'LineWidth', 12);
            xlabel('time [sec]'); ylabel('labels'); legend({'movment timing', 'predictions - correct', 'predictions - incorrect'}); xline(time(rec_end));
            title([args.group ' - segments predictions']);
        end
        
        function plot_gesture_predictions(obj, gesture_pred, gesture_pred_indices, args) % consider removing it
            arguments
                obj
                gesture_pred
                gesture_pred_indices
                args.group = 'new';
            end
            % if no data just return
            if isempty(obj) 
                disp('no data to visualize segments predictions');
                return
            end

            [gesture_true, gesture_true_indices] = obj.get_gestures();
            [~, ~, label_per_sample, rec_end] = obj.segments_info();
            time = (0:(length(label_per_sample) - 1))./obj.pipeline.sample_rate;

            % plot the labels and predictions over time
            figure();
            plot(time, label_per_sample, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(time(gesture_pred_indices), gesture_pred, 'bo', 'MarkerSize', 10)
            plot(time(gesture_true_indices), gesture_true, 'blacko', 'MarkerSize', 6, 'MarkerFaceColor','auto')
            xlabel('time [sec]'); ylabel('labels'); legend({'movment timing', 'predicted gestures timings', 'true gestures timings'}); 
            title([args.group ' - gestures predictions']); xline(time(rec_end));
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
                for i = 1:length(obj.signals)
                    signal = cat(2, signal, obj.signals(i).get_signal());
                    x_lines = cat(1, x_lines, length(signal));
                end
                figure("Name", 'raw data'); plot(signal.'); xline(x_lines);
                legend(legend_names); title('raw data');
            end
            % filtered raw data
            if args.filt
                filt_signal = []; x_lines = [];
                for i = 1:length(obj.signals)
                    filt_signal = cat(2, filt_signal, obj.signals(i).get_signal_filtered());
                    x_lines = cat(1, x_lines, length(filt_signal));
                end
                figure("Name", 'filtered data'); plot(filt_signal.'); xline(x_lines);
                legend(legend_names); title('filtered raw data');
                ylim(quantile(filt_signal(1,:), [0.05, 0.95]).*5)
            end
            % fft
            if args.fft
                figure('Name', 'fft - filtered raw data');
                num_rows = ceil(length(obj.signals)/3);
                for i = 1:length(obj.signals)
                    filt_signal = obj.signals(i).get_signal_filtered();
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
            file_name = files_paths_handler.path_to_name(path);

            file_loader = xdf_file_loader(path);
            [reject_recording, sample_rate] = file_loader.should_be_rejected_due_sample_rate(obj.pipeline.sample_rate);
            if reject_recording
                obj.files_handler.reject_file(path)
                disp(['recording ' file_name ' effective sample rate is - ' num2str(sample_rate) '. this recording is not being used']);
                return
            end
            [raw_signal, stream_markers] = file_loader.get_signal_and_markers();
            raw_signal(obj.pipeline.electrodes_to_remove,:) = []; % remove unused channels

            curr_signal = Signal(raw_signal, stream_markers);
            curr_segments = Segments(curr_signal, obj.pipeline);
            
            curr_segments.set_file_name(file_name);

            obj.handle_big_data_if_needed(seg_signal, file_name);
            
            obj.signals = cat(1, obj.signal, curr_signal);
            obj.segments = cat(1, obj.segments, curr_segments);
        end

        function handle_big_data_if_needed(obj, seg_signal, rec_name)
            if isempty(obj.big_data_files_handler) && obj.use_big_data
                obj.big_data_files_handler = big_data_files_handler(); %#ok<CPROPLC> 
            end
            if obj.use_big_data
                obj.big_data_files_handler.add_segmented_signal(seg_signal, rec_name);
                seg_signal.clear_segments(); % segments are saved in the data folder
            end
        end
    
        function [segments_ends_idx, labels, label_per_sample, rec_end] = segments_info(obj)
            label_per_sample = []; segments_ends_idx = []; labels = []; rec_end = [];
            for i = 1:length(obj.segments)
                curr_segments_ends_idx = obj.segments(i).get_segments_ends_idx() + length(label_per_sample);
                segments_ends_idx = cat(1, segments_ends_idx, curr_segments_ends_idx);
                label_per_sample = cat(1, label_per_sample, obj.signals(i).get_label_per_sample());
                labels = cat(1, labels, obj.segments(i).get_labels());
                rec_end = cat(1, rec_end, length(label_per_sample));
            end
        end

        function data_store = augment_data_store(obj, data_store)
            % this function is used to create a new object with an
            % augmented data store, you can control the augmentations from
            % the constant object
            % Outputs: new_obj - a copy of the object with an augmented
            %                    data store
            if ~isempty(obj)
                % using global variable so we could transfer the
                % probabilities into the augment_data function (can't use
                % them as inputs to the function...)
                global my_x_flip_p
                global my_wgn_p
                my_x_flip_p = obj.pipeline.x_flip_p;
                my_wgn_p = obj.pipeline.wgn_p;
                data_store = transform(data_store, @augment_data);
            end
            % defining the function here for memory improvements
            function aug_data = augment_data(datastore)
                    % this function creates an augmented data from the processed data the
                    % NN recieves
                    %
                    % Inputs:
                    %   datastore: a cell array containing the data in the first
                    %             column and the labels (as categorical objects) in the second
                    %             column
                    %
                    % outputs:
                    %   aug_data: a cell array containing the augmented data in the first
                    %             column and the labels (as categorical objects) in the second
                    %             column
                                        
                    % seperate data and labels
                    data = datastore(:,1);
                    labels = datastore(:,2); 
                    
                    N = size(data,1); % extract number of samples
                    
                    % aplly x flip with P probability 
                    P = my_x_flip_p;
                    indices_flip = randperm(N, round(N*P));
                    data(indices_flip) = cellfun(@(X) flip(X,2), data(indices_flip), "UniformOutput", false);
                    
                    % aplly white gaussian noise with P probability
                    P = my_wgn_p;
                    indices_noise = randperm(N, round(N*P));
                    data(indices_noise) = cellfun(@(X) awgn_func(X, 20), data(indices_noise), "UniformOutput", false);
                    
                    aug_data = [data, labels]; 

                        function x = awgn_func(x, snr)
                            for i = 1:size(x,3)
                                for j = 1:size(x,4)
                                    temp_x = x(:,:,i,j).'; 
                                    temp_x = awgn(temp_x, snr, 'measured');
                                    x(:,:,i,j) = temp_x.';
                                end
                            end
                        end
                end
        end
    
        function [gestures, gest_indices] = labels_to_gestures(obj, labels, confidence, cool_time) % to be removed
            gestures = []; gest_indices = 0;
            seg_end_idx = obj.segments_info();

            num_indices_between_following_segments = floor(obj.pipeline.segments_step_size_sec*obj.pipeline.sample_rate);
            min_indices_between_gestures = round(cool_time/obj.pipeline.segments_step_size_sec)*num_indices_between_following_segments;

            for j = confidence:length(labels)
                curr_labels = labels(j - confidence + 1:j);
                curr_seg_end_idx = seg_end_idx(j - confidence + 1:j);
                if any(curr_labels == 'idle') ||...
                        length(unique(curr_labels)) ~= 1 ||...
                        any(diff(curr_seg_end_idx) ~= num_indices_between_following_segments) ||...
                        seg_end_idx(j) - gest_indices(end) < min_indices_between_gestures
                    continue
                else
                    gestures = cat(1, gestures, labels(j));
                    gest_indices = cat(1, gest_indices, seg_end_idx(j));
                end
            end
            gest_indices(1) = []; % remove the initiale zero
        end
    end

    methods (Static)
        function labels = get_labels_from_data_store(data_store)
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
