classdef multi_recording < handle & matlab.mixin.Copyable & recording
    properties (SetAccess = protected)
        rec_idx     % indices of segments of each recording
        num_rec = 0;   % number of recording files in the object
        big_data = false;  % a flag to mark for big data object
        big_data_root_path % the path to the segments\features data files (for big data)
        rsmpl = false; % a flag of a resampled object or not - only the data store is resampled (by saving new files with the resampled data)
    end
    properties 
        group
    end

    methods
        %% define the object - notice that there are 2 options, big data and in memory data
        function obj = multi_recording(recorders, folders, pipeline)
            % recorders - a cell array with recorders names from the
            %             recordings folder
            % folders - a cell array with each recorder folder to aggregate
            % my_pipeline - a my_pipeline object with the pipeline settings

            if nargin > 0 % support empty objects
                if nargin == 2
                    obj.my_pipeline = my_pipeline();
                else
                    obj.my_pipeline = pipeline;
                end
                paths = create_paths(recorders, folders);
                % create a waitbar to show progress
                f = waitbar(0, 'preprocessing data, pls wait');
                % preprocess the data files
                for i = 1:length(paths)
                    waitbar(i/length(paths), f, ['preprocessing data, recording ' num2str(i) ' out of ' num2str(length(paths))]); % update the wait bar
                    rec = recording(paths{i}, obj.my_pipeline); % create a class member for each path
                    if i == 1
                    % ######## insert here a function to determine if to use big data or not #########
                        if obj.big_data
                            obj.big_data_root_path = new_data_folder();
                        end
                    end
                    obj.append_rec(rec);
                end
                delete(f); %close the wait bar
            end
        end

        %% adding or extracting recordings from the multi recording 
        % append a new recording
        function append_rec(obj, new_rec)
            % this function adds a new recording or multi recording, new_rec, into
            % the objec, essentially concatenating recordings objects.
            % Inputs: new_rec - a recording\multi recording object 
            if isempty(new_rec) 
                return
            elseif isempty(new_rec.segments)
                disp(['recording - ' new_rec.Name{1} ' has no usefull data, hence its exluded from the multi recording object']);
                return
            elseif isa(new_rec, 'multi_recording') % recursive part.. might be called once
                if new_rec.num_rec > 1 
                    for i = 1:new_rec.num_rec
                        new_obj = pop_rec(obj, i);
                        obj.append_rec(new_obj)
                    end
                end
            end
            if isempty(obj)
                obj.my_pipeline = new_rec.my_pipeline;
                obj.file_type = new_rec.file_type;
            end
            % check for file type consistency
            if ~strcmp(obj.file_type, new_rec.file_type)
                error('you are trying to aggregate data from different file types which indicates for different experiments and headsets!')
            elseif obj.my_pipeline ~= new_rec.my_pipeline
                error('you are trying to aggregate data with different pipelines!')
            end
            % concatenate data
            if ~obj.big_data
                obj.features = cat(5, obj.features, new_rec.features);
                obj.segments = cat(5, obj.segments, new_rec.segments);
            end
            obj.supp_vec        = cat(2, obj.supp_vec, new_rec.supp_vec);
            obj.sample_time     = cat(2, obj.sample_time, new_rec.sample_time);
            obj.raw_data        = cat(2, obj.raw_data, new_rec.raw_data);
            obj.raw_data_filt   = cat(2, obj.raw_data_filt, new_rec.raw_data_filt);
            obj.path            = cat(1, obj.path, new_rec.path);
            obj.Name            = cat(1, obj.Name, new_rec.Name);
            obj.markers         = cat(1, obj.markers, {new_rec.markers});
            obj.labels          = cat(1, obj.labels, new_rec.labels);
            % construct and concatenate the data indices of each recording file
            if isempty(obj.rec_idx) % create the first idx_rec row
                seg_idx = 1:length(new_rec.labels);
                raw_idx = 1:size(new_rec.raw_data, 2);
                filt_idx = 1:size(new_rec.raw_data_filt, 2);
                supp_vec_idx = 1:size(new_rec.supp_vec,2);
                sample_time_idx = 1:size(new_rec.sample_time,2);
            else % create the values of the new rec_idx row
                seg_idx = obj.rec_idx{end,2}(end) + (1:length(new_rec.labels)); % segments indices
                raw_idx = obj.rec_idx{end,3}(end) + (1:size(new_rec.raw_data, 2)); % raw data indices
                filt_idx = obj.rec_idx{end,4}(end) + (1:size(new_rec.raw_data_filt, 2)); % filtered data indices
                supp_vec_idx = obj.rec_idx{end,5}(end) + (1:size(new_rec.supp_vec, 2)); % supp_vec indices
                sample_time_idx = obj.rec_idx{end,6}(end) + (1:size(new_rec.sample_time, 2)); % sampled times indices
            end
            obj.rec_idx = cat(1, obj.rec_idx, {new_rec.Name{1}, seg_idx, raw_idx, filt_idx, supp_vec_idx, sample_time_idx});
            [obj.supp_vec, obj.sample_time] = fix_times(obj.supp_vec, obj.sample_time); % fix time points
            obj.num_rec = obj.num_rec + 1; % extract number of recordings 

            % save big data if needed
            if obj.big_data
                obj.save_data(new_rec.Name{1}, new_rec.segments, new_rec.features, new_rec.labels, new_rec.my_pipeline, 'source')
            end
        end
        
        % extract recordings by index
        function new_obj = pop_rec(obj, indices)
            % this function is used to extract a subset of recordings as a
            % multi recording object from the multi recording
            % Inputs: rec_idx - indices of recordings to extract as a subset
            % Outputs: new_obj - the subset of the multi recording object
            new_obj = copy(obj);
            new_obj.rec_idx = obj.rec_idx(indices,:);
            new_obj.num_rec = size(new_obj.rec_idx,1);
            if isempty(obj.big_data_root_path)
                new_obj.segments = obj.segments(:,:,:,:,cat(2, new_obj.rec_idx{:,2}));
                if ~isempty(obj.features)
                    new_obj.features = obj.features(:,:,:,:,cat(2, new_obj.rec_idx{:,2}));
                end
            end
            % extract the data of the recordings
            new_obj.labels = obj.labels(cat(2, new_obj.rec_idx{:,2}));
            new_obj.raw_data = obj.raw_data(:,cat(2, new_obj.rec_idx{:,3}));
            new_obj.raw_data_filt = obj.raw_data_filt(:,cat(2, new_obj.rec_idx{:,4}));
            new_obj.supp_vec = obj.supp_vec(:,cat(2, new_obj.rec_idx{:,5}));
            new_obj.sample_time = obj.sample_time(:,cat(2, new_obj.rec_idx{:,6}));
            new_obj.path = obj.path(indices);
            new_obj.Name = obj.Name(indices);
            new_obj.markers = obj.markers{indices};
            % fix times 
            [new_obj.supp_vec, new_obj.sample_time] = fix_times_1(new_obj.supp_vec, new_obj.sample_time);
            % resampled data is gone if we are not ussing big data, we will
            % set it to false in both cases for consistency.
            new_obj.rsmpl = false;
            % construct a data store if the original object had one
            if ~isempty(obj.data_store)
                new_obj.create_ds()
                if isa(obj.data_store, 'TransformedDatastore')
                    new_obj.augment();
                end
            else
                new_obj.data_store = [];
            end
        end

        %% preprocessing methods
        % creating a data store 
        function create_ds(obj)
            if ~obj.big_data
                create_ds@recording(obj)
            else % create the paths for the data store
                paths = {};
                if strcmp(obj.my_pipeline.feat_or_data, 'data')
                    folder = 'segments';
                else
                    folder = 'features';
                end
                for i = 1:size(obj.rec_idx,1)
                    paths{end+1} = fullfile(obj.big_data_root_path, obj.rec_idx{i,1}, folder, 'source');
                    if obj.rsmpl
                        paths{end+1} = fullfile(obj.big_data_root_path, obj.rec_idx{i,1}, folder, 'resample');
                    end
                end
                file_set = matlab.io.datastore.FileSet(paths);
                obj.data_store = fileDatastore(file_set, "ReadFcn", @load_file, 'UniformRead',true, ...
                    "FileExtensions", ".mat");
            end
        end

        % oversample data
        function rsmpl_data(obj)
            if obj.rsmpl  % do nothing if already oversampled
                return
            elseif ~obj.big_data % if not a big data recording then use the same resample function
               rsmpl_data@recording(obj);
               obj.rsmpl = true;
            else % oversampling of big data objects
                for i = 1:obj.num_rec
                    [segments, features, labels] = load_rec_data(obj, i);
                    [~,~,features, ~] = resample_data(features, labels);
                    [~,~,segments, labels] = resample_data(segments, labels);
                    obj.save_data(obj.rec_idx{i,1}, segments, features, labels, obj.my_pipeline, 'resample')
                end
                obj.rsmpl = true;
            end
        end

        % remove oversampled segments\features
        function remove_rsmpl_data(obj)
            % this function removes the oversampled segments and features
            % from the object segments and features, in big data cases its
            % just changes rsmple to false
            if ~obj.big_data
                remove_rsmpl_data@recording(obj)
            else
                obj.rsmpl = false;
                % update the data store to remove oversampled data
                if ~isempty(obj.data_store)
                    obj.create_ds();
                end
            end
        end

        %% visualizations
        function plot_data(obj, args)
            % this function is used to visualize the signals in the object,
            % set the optional inputs to true for the desired visualizations. 
            arguments
                obj
                args.raw = false;
                args.filt = false;
                args.fft = false;
            end
            % create Xline indices to seperate recordings
            indices_raw = cellfun(@(X) X(end), obj.rec_idx(:,3), 'UniformOutput', true);
            indices_filt = cellfun(@(X) X(end), obj.rec_idx(:,4), 'UniformOutput', true);
            legend_names = {'channel 1','channel 2','channel 3','channel 4','channel 5',...
                'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'};
            % raw data
            if args.raw
                figure("Name", 'raw data'); plot(obj.raw_data.'); xline(indices_raw);
                legend(legend_names); title('raw data');
            end
            % filtered raw data
            if args.filt
                figure("Name", 'filtered data'); plot(obj.raw_data_filt.'); xline(indices_filt);
                legend(legend_names); title('filtered raw data');
                ylim(quantile(obj.raw_data_filt(1,:), [0.05, 0.95]).*5)
            end
            % fft
            if args.fft
                figure('Name', 'fft - filtered raw data');
                num_rows = ceil(size(obj.rec_idx,1)/3);
                for i = 1:obj.num_rec
                    [pxx_filt, freq_1] = pwelch(obj.raw_data_filt(:,obj.rec_idx{i,4}).', obj.my_pipeline.sample_rate);
                    subplot(num_rows,3,i);
                    plot(freq_1(1:ceil(length(pxx_filt)/2)).*obj.my_pipeline.sample_rate./pi, pxx_filt(1:ceil(length(pxx_filt)/2),:).');
                    xlabel('frequency [HZ]'); ylabel('power [DB/HZ]');
                end
                legend(legend_names);
            end
        end

        %% big data related methods
        % save recording files - segment, features and labels
        function save_data(obj, name, segments, features, labels, my_pipeline, folder)
            warning('off', 'MATLAB:MKDIR:DirectoryExists');
            % create categorical labels, add all categories and reorder them
            labels = addcats(categorical(labels), arrayfun(@num2str, my_pipeline.class_label, 'UniformOutput', false));
            labels = squeeze(num2cell(reordercats(labels), 2));
            % create the recording folder
            mkdir(fullfile(obj.big_data_root_path, name));
            % save segments - saved as {segment, label}
            if ~isempty(segments)
                segments = squeeze(num2cell(segments, [1,2,3,4]));
                mkdir(fullfile(obj.big_data_root_path, name, 'segments', folder));
                for i = 1:length(labels)
                    Seg.('data') = [segments(i), labels(i)];
                    save(fullfile(obj.big_data_root_path, name, 'segments', folder, num2str(i,'%05.f')), '-struct', 'Seg');
                end
            end
            % save features - saved as {feature, label}
            if ~isempty(features)
                features = squeeze(num2cell(features, [1,2,3,4]));
                mkdir(fullfile(obj.big_data_root_path, name, 'features', folder));
                for i = 1:length(labels)
                    Feat.('data') = [features(i), labels(i)];
                    save(fullfile(obj.big_data_root_path, name, 'features', folder, num2str(i,'%05.f')), '-struct', 'Feat');
                end                   
            end
            warning('on', 'MATLAB:MKDIR:DirectoryExists');
        end 

        % load recording files - segments, features, labels
        function [segments, features, labels] = load_rec_data(obj, k)
            if ~obj.big_data
                disp('no data to load, "load_rec_data" is a method for big data objects only');
                segments = []; features = []; labels = [];
            else
                folders = {'segments', 'features'};
                for i = 1:size(folders,2)
                    curr_folder = fullfile(obj.big_data_root_path, obj.rec_idx{k,1}, folders{i});
                    if ~exist(curr_folder, 'dir') % skip if data dont exist (no features)
                        features = [];
                        continue 
                    end
                    % extract files
                    files = dir(fullfile(curr_folder, 'source', '*.mat'));
                    curr_data = {};
                    for j = 1:length(files)
                        load(fullfile(curr_folder, 'source', files(j).name))
                        curr_data = cat(1, curr_data, data);
                    end
                    if i == 1
                        labels = cellfun(@double, curr_data(:,2));
                        segments = cell2mat(permute(curr_data(:,1), [2,3,4,5,1]));
                    else
                        features = cell2mat(permute(curr_data(:,1), [2,3,4,5,1]));
                    end
                end
            end
        end
    end
end

% the loading file function to create the big data datastore
function [data]  = load_file(file)
    load(file); % load the data variable (a cell array)
end