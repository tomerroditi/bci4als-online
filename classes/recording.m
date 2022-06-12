classdef recording < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        path                    % the path of the data file
        options                 % the options structure
        Name                    % the name of the recording
        raw_data                % raw data from file
        raw_data_filt           % filtered raw data
        markers                 % markers structure
        segments                % segmented data
        features                % extracted features
        labels                  % data labels
        supp_vec                %
        data_store              % a data store containing the segments and labels
        sample_time             % the time point that each segments ends in
        constants               % a Constant object
        predictions             % predictions for some model
        fc_act                  % the last fully connected activations of the givven model to the data store 
        mdl_output              % outputs of a givven model to the data store
        file_type               % data file type - 'edf','xdf'
    end

    methods
        %% construct the object
        function obj = recording(file_path, options)
            if nargin > 0 % support empty objects
                obj.path = file_path;
                obj.constants = options.constants;
                if strcmp(options.cont_or_disc, 'discrete') % sequence length must be 1 for discrete segmentation
                    options.sequence_len = 1;
                end
                obj.options = options;
                % set a name for the obj according to its file path
                strs = split(file_path, '\');
                obj.Name = [strs{end - 1}(5:end) ' - ' strs{end}];
                % load the raw data and markers
                if ~isempty(dir([file_path '\*.xdf']))
                    obj.file_type = 'xdf';
                    % load the raw data and events from the xdf file - using evalc function to suppress any printing from eeglab functions
                    [~, EEG] = evalc("pop_loadxdf([file_path '\EEG.xdf'], 'streamtype', 'EEG')");
                    obj.raw_data = EEG.data;
                    obj.markers = EEG.event;
                    obj.raw_data(obj.constants.xdf_removed_chan,:) = []; % remove unused channels
                    labels = load(strcat(file_path, '\labels.mat'), 'labels'); % load the labels vector
                    labels = labels.labels;
                elseif ~isempty(dir([file_path '\*.edf'])) 
                    obj.file_type = 'edf';
                    [obj.raw_data, obj.markers, labels] = edf2data(file_path);
                    obj.raw_data(obj.constants.edf_removed_chan,:) = []; % remove unused channels
                else
                    error('Error. only {"xdf","edf"} file types are supported for loading data')
                end
                [segments, obj.labels, obj.supp_vec, obj.sample_time] = ...
                    MI2_SegmentData(obj.raw_data, obj.markers, labels, options); % create segments
                segments = MI3_Preprocess(segments, options.cont_or_disc, obj.constants); % filter the segments
                obj.raw_data_filt = MI3_Preprocess(obj.raw_data, options.cont_or_disc, obj.constants);                
                obj.segments = create_sequence(segments, options);
            end
        end

        %% normalizations - you can choose what data to normalize (segments/raw data/filtered raw data)
        function normalize(obj, seg_raw_filt_all)
            if strcmp(seg_raw_filt_all, 'segments') || strcmp(seg_raw_filt_all, 'all')
                obj.segments = norm_eeg(obj.segments, obj.constants.quantiles);
            end
            if strcmp(seg_raw_filt_all, 'raw') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data = norm_eeg(obj.raw_data, obj.constants.quantiles);
            end
            if strcmp(seg_raw_filt_all, 'filt') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data_filt = norm_eeg(obj.raw_data_filt, obj.constants.quantiles);
            end
        end

        %% feature extraction 
        function extract_feat(obj)
            % if object is empty then do nothing
            if isempty(obj.segments) 
                return
            end
            % choose the desired feature extraction method based on feat_alg
            if strcmp(obj.options.feat_alg, 'wavelet')
                obj.features = wavelets(obj);
            elseif strcmp(obj.options.feat_alg, 'basic')
                obj.features = MI4_ExtractFeatures(obj.segments); % this is not supported yet
            elseif strcmp(obj.options.feat_alg, 'none')
                return
            else
                error('pls choose an available feature algorithm')
            end
        end
       
        %% create a new obj with resampled segments
        function new_obj = rsmpl_data(obj, args)
            arguments
                obj
                args.resample = obj.options.resample
            end
            new_obj = copy(obj);
            [new_obj.segments, new_obj.labels] = resample_data(new_obj.segments, new_obj.labels, args.resample, true);
        end
            
        %% create a data store (DS) from the obj segments (normalized!) and labels
        function create_ds(obj, feat_seg) 
            if strcmp(feat_seg, 'segments') % use processed data to create ds
                obj.data_store = set2ds(obj.segments, obj.labels, obj.constants);
            elseif strcmp(feat_seg, 'features') % use features to create ds
                obj.data_store = set2ds(obj.features, obj.labels, obj.constants);
            end
        end
   
        %% data augmentation
        function new_obj = augment(obj)
            new_obj = copy(obj);
            if ~isempty(obj.data_store)
                new_obj.data_store = transform(obj.data_store, @augment_data);
            end
        end

        %% classification and evaluation
        function [pred, thresh, CM] = evaluate(obj, model, options)
            arguments
                obj
                model
                options.thres_C1 = [];
                options.CM_title = '';
                options.criterion = [];
                options.criterion_thresh = [];
                options.print = false;
            end
            if ~isempty(obj.data_store) % check if the obj is not empty
                [pred, thresh, CM] = evaluation(model, obj.data_store, CM_title = options.CM_title, ...
                    criterion = options.criterion, criterion_thresh = options.criterion_thresh, ...
                    thres_C1 = options.thres_C1, print = options.print);
                obj.predictions = pred;
            else
                pred = []; thresh = []; CM = [];
            end
        end
        
        %% visualization of predictions
        function visualize(obj, options)
            arguments
                obj
                options.title = '';
            end
            if ~isempty(obj.supp_vec) && ~isempty(obj.predictions) && ~isempty(obj.sample_time) && ~isempty(obj.Name)
                visualize_results(obj.supp_vec, obj.predictions, obj.sample_time, options.title)
            end
        end

        %% model activations operations
        function fc_activation(obj, model)
            % find the FC layer index
            fc = 0;
            for i = 1:length(model.Layers)
                if strcmp('activations', model.Layers(i).Name)
                    fc = 1;
                    break
                end
            end
            if fc
                % extract activations from the fc layer
                obj.fc_act = activations(model, obj.data_store, layer_name);
                dims = 1:length(size(obj.fc_act)); % create a dimention order vector
                dims = [dims(end), dims(1:end - 1)]; % shift last dim (batch size) to be the first
                obj.fc_act = squeeze(permute(obj.fc_act, dims));
                obj.fc_act = reshape(obj.fc_act, [size(obj.fc_act,1), size(obj.fc_act,2)*size(obj.fc_act,3)]);
            else
                disp(['No layer named "activations" found, pls check the model architecture and the layers names,' newline...
                    'and change the fully connected layer name you would like to visualize to "activations"'])
            end
        end

        %% model output
        function model_output(obj, model)
            if isa(model, 'dlnetwork') % need to work with dlarrays in that case
                data_set = readall(obj.data_store);
                data_set(:,1) = cellfun(@(x) permute(x, [3,1,2]), data_set(:,1), 'UniformOutput',false);
                dlarray_seg = dlarray(permute(cell2mat(data_set(:,1)),[2,3,4,1]), 'SSCB'); 
                obj.mdl_output = predict(model, dlarray_seg);
                obj.mdl_output = gather(extractdata(obj.mdl_output)); % convert dlarray back to double
            else
                obj.mdl_output = predict(model, obj.data_store);
            end
        end

        %% visualize fc activations of a model
        function visualize_act(obj, dim_red_algo, num_dim)
            if isempty(obj.fc_act)
                disp(['You need to calculate the "fc" layer activations in order to visualize them' newline ...
                    'Use the "fc_activation" method to do so!']);
                return
            end
            % keep asking for inputs untill a correct one is given
            while ~ismember(dim_red_algo, ["pca","tsne"])
                dim_red_algo = input(['Dimentional reduction algorithm name is wrong,' newline...
                    'pls select from {"pca","tsne"} and type it here: ']);
            end
            if strcmp(dim_red_algo, 'tsne')
                points = tsne(obj.fc_act, 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', num_dim);
            elseif strcmp(dim_red_algo, 'pca')
                points = pca(obj.fc_act);
                points = points.';
                points = points(:,1:num_dim);
            end 

            if num_dim == 2
                scatter_2D(points, obj);
            elseif num_dim == 3
                scatter_3D(points, obj);
            else
                disp('Unable to plot more than a 3D representation of the data!');
            end
        end

        %% visualize output of a model
        function visualize_output(obj, dim_red_algo, num_dim)
            if isempty(obj.mdl_output)
                disp(['You need to calculate the outputs of the model in order to visualize them' newline ...
                    'Use the "model_output" method to do so!']);
                return
            end
            % keep asking for inputs untill a correct one is given
            while ~ismember(dim_red_algo, ["pca","tsne"])
                dim_red_algo = input(['Dimentional reduction algorithm name is wrong,' newline...
                    'pls select from {"pca","tsne"} and type it here: ']);
            end
            if strcmp(dim_red_algo, 'tsne')
                points = tsne(obj.mdl_output.', 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', num_dim);
            elseif strcmp(dim_red_algo, 'pca')
                points = pca(obj.mdl_output.');
                points = points.';
                points = points(:,1:num_dim);
            end

            if num_dim == 2
                scatter_2D(points, obj);
            elseif num_dim == 3
                scatter_3D(points, obj);
            end
        end
    end
end
