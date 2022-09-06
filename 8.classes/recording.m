classdef recording < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        name                   % the name of the recording (str cell array)
        pipeline                % my pipeline object
        segmented_signal        % segmented signal object
        big_data_files_handler  % big data files handler object
        data_store              % data store object
        use_big_data = false;
        labels_handler
    end

    methods
        %% construct the object - load a file, segment and preprocess it
        function obj = recording(files_paths_handler, pipeline)
            % inputs:
            %   file_path - a path of an EDF\XDF file of a recording session
            %   pipeline (optional) - a my pipeline object, default is
            %                            the default my pipeline object

            if nargin == 0 || isempty(files_paths_handler) % support empty objects
                return
            elseif nargin == 1 % use default my_pipeline object
                obj.pipeline = my_pipeline();
            else
                obj.pipeline = pipeline;
            end

            obj.labels_handler = Labels_Handler(obj.pipeline.class_names, obj.pipeline.class_marker);

            f = waitbar(0, 'preprocessing data, pls wait');
            paths = files_paths_handler.get_paths();
            for i = 1:length(paths)
                waitbar(i/length(paths), f, ['preprocessing data, recording ' num2str(i) ' out of ' num2str(length(paths))]); % update the wait bar
                obj.add_segmented_signal_from(paths{i});
            end
            delete(f); % close the wait bar
        end

        function categories = get_labels_categories(obj)
            categories = obj.labels_handler.get_categories();
        end

        function print_data_distribution(obj, title)
            labels = [];
            for i = 1:length(obj.segmented_signal)
                labels = cat(1, labels, obj.segmented_signal(i).get_categorical_labels());
            end
            disp([title 'data distribution']); 
            tabulate(labels)
        end
        
        function merge_recordings(obj, new_rec) % not in used yet
            % this function checks if recordings object are suitable for
            % merging and merges them
            obj.pipeline.merge_with(new_rec.pipeline);
            obj.name = cat(1, obj.name, new_rec.name); % needs to be sorted 
            obj.segmented_signal = cat(1, obj.segmented_signal, new_rec.segmented_signal); % needs to be sorted as well
            obj.big_data_files_handler.merge(new_rec.big_data_files_handler, new_rec.pipeline);
        end
        
        function pipeline = get_pipeline(obj)
            pipeline = obj.pipeline;
        end
        %% behavior methods
        % overriding the isempty function
        function bool = isempty(obj)
            if isempty(obj.name)
                bool = true;
            else
                bool = false;
            end
        end

        %% preprocessing methods

        % create a data store (DS) from the obj segments and labels
        function create_ds(obj, args)
            % this function is used to create a data store from the object
            % segments\features according to the value of 'feat_or_data'
            % property in the object's my_pipeline object.
            arguments
                obj
                args.oversample = false
            end

            if isempty(obj)
                return
            end

            data_label_cell = {};
            for i = 1:length(obj.segmented_signal)
                if args.oversample
                    curr_data_label_cell = obj.segmented_signal(i).create_data_label_cell_oversampled();
                else
                    curr_data_label_cell = obj.segmented_signal(i).create_data_label_cell();
                end
                data_label_cell = cat(1, data_label_cell, curr_data_label_cell);
            end
            read_size = obj.pipeline.mini_batch_size;
            obj.data_store = arrayDatastore(data_label_cell, 'ReadSize', read_size, 'IterationDimension', 1, 'OutputType', 'same');
        end
   
        function ds = get_ds(obj)
            ds = obj.data_store;
        end
        
        function labels = get_labels_of_ds(obj)
            labels = [];
            while hasdata(obj.data_store)
                batch = read(obj.data_store);
                curr_labels = cellfun(@(X) X, batch(:,2));
                labels = cat(1, labels, curr_labels);
            end
            reset(obj.data_store);
        end
        % data augmentation
        function augment(obj)
            % this function is used to create a new object with an
            % augmented data store, you can control the augmentations from
            % the constant object
            % Outputs: new_obj - a copy of the object with an augmented
            %                    data store
            if ~isempty(obj)
                if ~isempty(obj.data_store)
                    obj.create_ds();
                end
                % using global variable so we could transfer the
                % probabilities into the augment_data function (can't use
                % them as inputs to the function...)
                global my_x_flip_p
                global my_wgn_p
                my_x_flip_p = obj.pipeline.x_flip_p;
                my_wgn_p = obj.pipeline.wgn_p;
                obj.data_store = transform(obj.data_store, @augment_data);
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
                    
                    aug_data = [data labels]; 

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

        % remove augmentations from data store
        function remove_augment(obj)
            % this function removes the augmentations from the object data
            % store
            if ~isempty(obj.data_store)
                obj.data_store = obj.data_store.UnderlyingDatastores{1};
            end          
        end
        
        %% visualizations
        % visualize segments predictions
        function visualize_predictions(obj, predictions, options)
            % this function is used to visualize the model predictions
            % Inputs: title - a title for the plot ('train', 'val', 'test')
            arguments
                obj
                predictions
                options.title = '';
            end
            % if no data just return
            if isempty(obj) 
                disp([options.title ' - no data to visualize']);
                return
            end

            [label_per_sample, segments_ends_idx, labels_array, x_line] = obj.get_arrays_for_predictions_plot();
            time = (0:(length(label_per_sample) - 1))./obj.pipeline.sample_rate;
            segments_ends_time = time(segments_ends_idx);

            % plot the labels and predictions over time
            figure('Name', [options.title ' - classification visualization']);
            plot(time, label_per_sample, 'r_', 'MarkerSize', 3, 'LineWidth', 15); hold on;
            plot(segments_ends_time(predictions == labels_array), predictions(predictions == labels_array), 'b_', 'MarkerSize', 2, 'LineWidth', 12); hold on;
            plot(segments_ends_time(predictions ~= labels_array), predictions(predictions ~= labels_array), 'black_', 'MarkerSize', 2, 'LineWidth', 12);
            xlabel('time'); ylabel('labels'); legend({'movment timing', 'predictions - correct', 'predictions - incorrect'}); xline(time(x_line));
        end
        
        % data visualization
        function plot_data(obj, args)
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
                for i = 1:length(obj.name)
                    signal = cat(2, signal, obj.segmented_signal(i).get_signal());
                    x_lines = cat(1, x_lines, length(signal));
                end
                figure("Name", 'raw data'); plot(signal.'); xline(x_lines);
                legend(legend_names); title('raw data');
            end
            % filtered raw data
            if args.filt
                filt_signal = []; x_lines = [];
                for i = 1:length(obj.name)
                    filt_signal = cat(2, filt_signal, obj.segmented_signal(i).get_signal_filtered());
                    x_lines = cat(1, x_lines, length(filt_signal));
                end
                figure("Name", 'filtered data'); plot(filt_signal.'); xline(x_lines);
                legend(legend_names); title('filtered raw data');
                ylim(quantile(filt_signal(1,:), [0.05, 0.95]).*5)
            end
            % fft
            if args.fft
                figure('Name', 'fft - filtered raw data');
                num_rows = ceil(length(obj.name)/3);
                for i = 1:length(obj.name)
                    filt_signal = obj.segmented_signal(i).get_signal_filtered();
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
        function add_segmented_signal_from(obj, path)
            rec_name = files_paths_handler.path_to_name(path);

            file_loader = xdf_file_loader(path);
            [reject_recording, sample_rate] = file_loader.should_be_rejected_due_sample_rate(obj.pipeline.sample_rate);
            if reject_recording
                disp(['recording ' rec_name ' effective sample rate is - ' num2str(sample_rate) '. this recording is not being used']);
                return
            end
            [signal, markers] = file_loader.get_signal_and_markers();
            signal(obj.pipeline.electrodes_to_remove,:) = []; % remove unused channels
            
            seg_signal = segmented_signal(signal, markers, obj.pipeline); %#ok<CPROPLC> 
            obj.handle_big_data_if_needed(seg_signal, rec_name);
            
            obj.segmented_signal = cat(1, obj.segmented_signal, seg_signal);
            obj.name{end + 1} = rec_name;
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
    
        function [label_per_sample, segments_ends_idx, labels_array, x_lines] = get_arrays_for_predictions_plot(obj)
            label_per_sample = []; segments_ends_idx = []; labels_array = []; x_lines = [];
            for i = 1:length(obj.segmented_signal)
                curr_segments_ends_idx = obj.segmented_signal(i).get_segments_ends_idx() + length(label_per_sample);
                segments_ends_idx = cat(1, segments_ends_idx, curr_segments_ends_idx);
                label_per_sample = cat(1, label_per_sample, obj.segmented_signal(i).get_label_per_sample());
                labels_array = cat(1, labels_array, obj.segmented_signal(i).get_labels_array());
                x_lines = cat(1, x_lines, length(label_per_sample));
            end
        end
    end
end
