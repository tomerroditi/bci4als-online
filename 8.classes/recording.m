classdef recording < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        path                    % the path of the data file (str array\cell)
        Name                    % the name of the recording (str array\cell)
        raw_data                % raw data from file
        raw_data_filt           % filtered raw data
        markers                 % markers structure (str array\cell)
        segments                % segmented data
        features                % extracted features
        labels                  % data labels
        supp_vec                % 2D row array containing each time point and its label
        data_store              % a data store containing the segments and labels
        sample_time             % the time point that each segments ends in
        my_pipeline             % the my_pipeline object of the recording
        file_type               % data file type - 'edf','xdf'
    end

    methods
        %% construct the object - load a file, segment and filter its data
        function obj = recording(file_path, my_pipeline)
            % inputs:
            %   file_path - a path an EDF\XDF file of a recording
            %   my_pipeline - a my pipeline object
            if nargin > 0 % support empty objects
                if nargin == 1
                    obj.my_pipeline = my_pipeline();
                else
                    obj.my_pipeline = my_pipeline;
                end
                obj.path = {file_path};
                % set a name for the obj according to its file path
                strs = split(file_path, '\');
                obj.Name = {[strs{end - 1} ' - ' strs{end}]};
                %%%% load the raw data and markers %%%%
                if ~isempty(dir([file_path '\*.xdf']))
                    obj.file_type = 'xdf';
                    % check for effective sample rate and reject recording
                    % that its under 124.5 or above 125.5 HZ (we will allow a small error)
                    [~,xdf_struct] = evalc("load_xdf([file_path '\EEG.xdf'])");
                    if length(fields(xdf_struct{1})) == 4
                        SR = xdf_struct{1}.info.effective_srate;
                    else
                        SR = xdf_struct{2}.info.effective_srate;
                    end
                    if SR < 124.5 || SR > 125.5
                        disp(['recording ' obj.Name{1} ' effective sample rate is - ' num2str(SR) '. dont use that recording, returning it as an empty object for now']);
                        obj = recording();
                        return
                    end
                    % load the raw data and events from the xdf file - using evalc function to suppress any printing from eeglab functions
                    [~, EEG] = evalc("pop_loadxdf([file_path '\EEG.xdf'], 'streamtype', 'EEG')");
                    obj.raw_data = EEG.data;
                    obj.markers = EEG.event;
                    obj.raw_data(obj.my_pipeline.removed_chan,:) = []; % remove unused channels
                elseif ~isempty(dir([file_path '\*.edf'])) 
                    obj.file_type = 'edf';
                    [obj.raw_data, obj.markers] = edf2data(file_path); % extract data from edf files
                    obj.raw_data(obj.my_pipeline.removed_chan,:) = []; % remove unused channels
                    obj.my_pipeline.set_electrode_loc({'Pz','Cz','T6','T4','F8','P4','C4','F4','Fz','T5','T3','F7','P3','C3','F3'})
                else
                    error(['Error. only {"xdf","edf"} file types are supported for loading data!' newline ...
                        'pls choose a different file path than:' newline file_path])
                end
                %%%% data preprocessing %%%% 
                % create segments
                [obj.raw_data, segments, obj.labels, obj.supp_vec, obj.sample_time] = ...
                    data_segmentation(obj.raw_data, obj.markers, obj.my_pipeline); 
                % filter the segments and the raw data array
                segments = filter_segments(segments, obj.my_pipeline); 
                obj.raw_data_filt = filter_segments(obj.raw_data, obj.my_pipeline);
                % create sequences
                obj.segments = create_sequence(segments, obj.my_pipeline);
                % normalize the signal - if my_pipeline.quantiles is empty no normalization is applied
                obj.segments = norm_eeg(obj.segments, obj.my_pipeline.quantiles);
                % feature extraction
                if ~strcmp(obj.my_pipeline.feat_alg, 'none') 
                    % execute the desired feature extraction method
                    feat_method = dir('5.feature extraction methods');
                    feat_method_name = extractfield(feat_method, 'name');
                    if ismember([obj.my_pipeline.feat_alg '.m'], feat_method_name)
                        obj.features = eval([algo '(obj.segments, obj.my_pipeline);']); % this will call the feature extraction fnc
                    else 
                        error(['there is no file named "' obj.my_pipeline.feat_alg '" in the feature extraction method folder.' newline...
                            'please provide a valide file name (exclude the ".m"!) in the my pipeline object']);
                    end
                end
            end
        end
        
        %% overriding behavior methods
        % overriding the isempty function
        function bool = isempty(obj)
            if isempty(obj.raw_data)
                bool = true;
            else
                bool = false;
            end
        end

        %% preprocessing methods
        % oversampling segments
        function rsmpl_data(obj)
            % this function is used to oversample the segments, features,
            % and labels so we'll have an even labels distribution 
            obj.features = resample_data(obj.features, obj.labels);
            [obj.segments, obj.labels] = resample_data(obj.segments, obj.labels);

            function [data, labels, rsmpl_segments, rsmpl_labels] = resample_data(data, labels)
                    % this function resamples each class by the factors in rsmpl_size. each
                    % class resample factor is stored in rsmpl_size in the index which is
                    % equall to the class number.
                    % Inputs:
                    %   data: an array containing the data to resample, the kast dimention
                    %             should be the trails dimentions
                    %   labels: the true class of the data
                    %   print: bool, specify if you want to display the new data distribution
                    %
                    % Outputs:
                    %   data: an array containing the resampled data
                    %   labels: labels of the resampled data
                    %
                    
                    % return empty arrays if the input is empty
                    if isempty(data)
                        data = []; labels = [];
                        rsmpl_segments = []; rsmpl_labels = [];
                        return
                    end
                    
                    % find the label that apears the most
                    unique_labels = unique(labels);
                    count = 0;
                    for i = 1:length(unique_labels)
                        if sum(labels == unique_labels(i)) > count
                            most_freq_label = unique_labels(i);
                            count = sum(labels == unique_labels(i));
                        end
                    end
                    
                    % find each class indices and resample the data - only in the last dimention
                    S.subs = repmat({':'},1,ndims(data)); S.type = '()';
                    rsmpl_segments = []; rsmpl_labels = [];
                    for i = 1:length(unique_labels)
                        curr_label = unique_labels(i);
                        S.subs{ndims(data)} = find(~(labels == curr_label));
                        curr_seg = subsasgn(data, S, []); % reject all indices of other labels
                        ratio = round(sum(labels == most_freq_label)/sum(labels == curr_label)); % ratio to the largest label
                        rsmpl_segments = cat(ndims(data), rsmpl_segments, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
                        rsmpl_labels = cat(1, rsmpl_labels, ones(size(curr_seg, ndims(data))*(ratio - 1),1).*curr_label);
                    end
                    % concat original data\labels with resampled data\labels
                    data = cat(ndims(data), data, rsmpl_segments);
                    labels = cat(1, labels, rsmpl_labels);
                end
        end

        % remove oversampled segments
        function remove_rsmpl_data(obj)
            % this function removes the oversampled segments and features
            % from the object segments and features
            if ~isempty(obj)
                num_trials = length(obj.sample_time);
                obj.labels = obj.labels(1:num_trials);
                obj.segments = obj.segments(:,:,:,:,1:num_trials);
                if ~isempty(obj.features)
                    obj.features = obj.features(:,:,:,:,1:num_trials);
                end
                if ~isempty(obj.data_store)
                    obj.create_ds();
                end
            end
        end
            
        % create a data store (DS) from the obj segments and labels
        function create_ds(obj)
            % this function is used to create a data store from the object
            % segments\features according to the value of 'feat_or_data'
            % property in the object's my_pipeline object.
            if ~isempty(obj)
                if strcmp(obj.my_pipeline.feat_or_data, 'data') % use segments to create ds
                    obj.data_store = set2ds(obj.segments, obj.labels, obj.my_pipeline);
                else % use features to create ds
                    obj.data_store = set2ds(obj.features, obj.labels, obj.my_pipeline);
                end
            end

            function ds = set2ds(segments, labels, my_pipeline)
                    % this function creates a data store from a data set
                    %
                    % Inputs:
                    %   - segments: a 5D aarray containing the segmented eeg data
                    %   - labels: a 1D array containing the labels of the segmented eeg data
                    %   - constants: a constants object
                    %
                    % Outputs:
                    %   - ds: a data store containing 'segments' and 'labels'
                    
                    if isempty(segments)
                        ds = [];
                        return 
                    end
                    
                    % create cells of the labels - notice we need to feed the datastore with
                    % categorical instead of numeric labels
                    labels = addcats(categorical(labels), arrayfun(@num2str, my_pipeline.class_label, 'UniformOutput', false)); % add categories that might be missing
                    labels = squeeze(num2cell(reordercats(labels), 2));
                    % create cells of segments
                    segments = squeeze(num2cell(segments, [1,2,3,4]));
                    
                    % define the datastores and their read size - for best runtime performance 
                    % configure read size to be the same as the minibatch size of the network
                    read_size = my_pipeline.mini_batch_size;
                    ds = arrayDatastore([segments labels], 'ReadSize', read_size, 'IterationDimension', 1, 'OutputType', 'same');
                    end
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
                my_x_flip_p = obj.my_pipeline.x_flip_p;
                my_wgn_p = obj.my_pipeline.wgn_p;
                obj.data_store = transform(obj.data_store, @augment_data);
            end

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
                    labels = datastore(:,2); %#ok<PROP> 
                    
                    N = size(data,1); % extract number of samples
                    
                    % aplly x flip with P probability 
                    P = my_x_flip_p;
                    indices_flip = randperm(N, round(N*P));
                    data(indices_flip) = cellfun(@(X) flip(X,2), data(indices_flip), "UniformOutput", false);
                    
                    % aplly white gaussian noise with P probability
                    P = my_wgn_p;
                    indices_noise = randperm(N, round(N*P));
                    data(indices_noise) = cellfun(@(X) awgn_func(X, 20), data(indices_noise), "UniformOutput", false);
                    
                    aug_data = [data labels]; %#ok<PROP>

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
        function visualize(obj, predictions, options)
            % this function is used to visualize the model predictions
            % Inputs: title - a title for the plot ('train', 'val', 'test')
            arguments
                obj
                predictions
                options.title = '';
            end
            visualize_results(obj.supp_vec, obj.labels, predictions, obj.sample_time, options.title)
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
            % create Xline indices to seperate recordings
            legend_names = {'channel 1','channel 2','channel 3','channel 4','channel 5',...
                'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'};
            % raw data
            if args.raw
                figure("Name", 'raw data'); plot(obj.raw_data.');
                legend(legend_names); title('raw data');
            end
            % filtered raw data
            if args.filt
                figure("Name", 'filtered data'); plot(obj.raw_data_filt.');
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
    end
end
