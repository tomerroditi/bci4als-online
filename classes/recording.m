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
                options = validate_options(options);
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
                elseif ~isempty(dir([file_path '\*.edf'])) 
                    obj.file_type = 'edf';
                    [obj.raw_data, obj.markers] = edf2data(file_path); % extract data from edf files
                    obj.raw_data(obj.constants.edf_removed_chan,:) = []; % remove unused channels
                else
                    error('Error. only {"xdf","edf"} file types are supported for loading data')
                end
                [obj.raw_data, segments, obj.labels, obj.supp_vec, obj.sample_time] = data_segmentation(obj.raw_data, obj.markers, options); % create segments
                segments = filter_segments(segments, options.cont_or_disc, obj.constants); % filter the segments
                obj.raw_data_filt = filter_segments(obj.raw_data, options.cont_or_disc, obj.constants); % filter raw data               
                obj.segments = create_sequence(segments, options); % create sequences
            end
        end

        %% normalizations - you can choose what data to normalize (segments/raw data/filtered raw data)
        function normalize(obj, seg_raw_filt_all)
            if isempty(obj.raw_data) % do nothing if the object doesnt contains data (empty object)
                return
            end
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
       
        %% resampling segments
        function new_obj = rsmpl_data(obj, args)
            arguments
                obj
                args.print = true;
            end
            new_obj = copy(obj);
            [new_obj.segments, new_obj.labels] = resample_data(new_obj.segments, new_obj.labels, args.print);
        end
            
        %% create a data store (DS) from the obj segments and labels
        function create_ds(obj, args)
            arguments
                obj
                args.reject_class = {}
            end
            if isempty(obj.raw_data)
                return
            end
            
            feat_data = obj.options.feat_or_data;
            if strcmp(feat_data, 'data') % use processed data to create ds
                obj.data_store = set2ds(obj.segments, obj.labels, obj.constants, args.reject_class);
            elseif strcmp(feat_data, 'feat') % use features to create ds
                obj.data_store = set2ds(obj.features, obj.labels, obj.constants, args.reject_class);
            end
        end
   
        %% data augmentation
        function new_obj = augment(obj)
            new_obj = copy(obj);
            if ~isempty(obj.data_store)
                new_obj.data_store = transform(obj.data_store, @augment_data);
            end
        end

        %% complete data preprocessing pipeline
        function rsmpld_obj = complete_pipeline(obj, args)
            arguments
                obj
                args.rsmpl = false; % boolian values to resample or not
                args.reject_class = {};  % class to reject from data store
                args.print = false; % print new class distribution after resampling
            end
            rsmpld_obj = [];
            obj.normalize('all');
            obj.extract_feat()
            if args.rsmpl
                rsmpld_obj = obj.rsmpl_data(print = args.print);
                rsmpld_obj.create_ds(reject_class = args.reject_class)
                rsmpld_obj = rsmpld_obj.augment();
            end
            obj.create_ds(reject_class = args.reject_class)
        end

        %% evaluation & classification 
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
                [pred, thresh, CM] = evaluation(model, obj.data_store, obj.constants, CM_title = options.CM_title, ...
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
            % find the activation layer index
            flag = 0;
            for i = 1:length(model.Layers)
                if strcmp('activations', model.Layers(i).Name)
                    flag = 1;
                    break
                end
            end
            if flag
                % extract activations from the fc layer
                obj.fc_act = activations(model, obj.data_store, 'activations');
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
                points = tsne(obj.mdl_output, 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', num_dim);
            elseif strcmp(dim_red_algo, 'pca')
                points = pca(obj.mdl_output);
                points = points.';
                points = points(:,1:num_dim);
            end

            if num_dim == 2
                scatter_2D(points, obj);
            elseif num_dim == 3
                scatter_3D(points, obj);
            end
        end

        %% gesture detection
        function gest_time = get_predicted_gestures(obj, K, cool_time, pred_GT)
            % K - the number of labels detected in a raw to execute a gesture
            % cool_time - time window to not execute a gesture after executing a gesture
            % pred_GT - choose from predicted gestures, 'pred', and ground truth gestures, 'GT'.
            if strcmp(pred_GT, 'pred')
                vec = obj.predictions;
            elseif strcmp(pred_GT, 'GT')
                vec = obj.labels;
            end

            gest_time = [0;0]; % initialize a vector for gesture class and time of execution
            for i = K:length(obj.labels)
                if obj.sample_time(i) - gest_time(2,end) < cool_time
                    continue
                end
                [class_label, class_names] = fix_class(obj.constants.class_label, obj.constants.class_names);
                idle_idx = strcmp(class_names, 'Idle');
                class_label_no_idle = class_label(~idle_idx);
                for j = 1:length(class_label_no_idle)
                    if vec(i - K + 1:i) == class_label_no_idle(j)
                        gest_time(:,i) = [class_label_no_idle(j) ; obj.sample_time(i)];
                        break
                    end
                end 
            end
            gest_time(:,gest_time(1,:) == 0) = []; % remove zeros
        end

        function [accuracy, missed_gest, mean_delay, CM, gest_times_pred] = detect_gestures(obj, K, cool_time, M_max, print)
        % K - the number of gesture detected in a raw to execute a gesture
        % cool_time - time window to not execute a gesture after executing a gesture
        % M_max - maximum delay (in seconds) between gesture start time and gesture recognition
        if isempty(obj.predictions)
            accuracy = [];
            missed_gest = [];
            mean_delay = [];
            CM = [];
            gest_times_pred = [];
            return
        end
            gest_times_pred = get_predicted_gestures(obj, K, cool_time, 'pred');
            gest_times_GT = get_predicted_gestures(obj, K, cool_time, 'GT');
            [class_label, class_name] = fix_class(obj.constants.class_label, obj.constants.class_names);
            idle_idx = strcmp(class_name, 'Idle');
            idle_label = class_label(idle_idx); % find the label of Idle class

            % compare true gestures and predicted ones
            delay = []; % initialize an empty array to calculate the mean delay of gesture detection
            seg_dur = obj.options.seg_dur;   % segments duration
            overlap = obj.options.overlap;   % segments overlap
            threshold = obj.options.threshold; % segment threshold for labeling
            step_size = seg_dur - overlap;     % step size between following segments
            gest_times_GT(2,:) = gest_times_GT(2,:) - K*step_size - seg_dur*threshold; % place the true gesture times at roughtly the beggining of the gesture
            GT_pred = []; % initialize an array to store the true and predicted gestures
            for i = 1:size(gest_times_GT, 2)
                curr_time = gest_times_GT(2,i);
                time_diff = gest_times_pred(2,:) - curr_time;
                M = min(time_diff(time_diff >= 0));
                if M < M_max % allow up to 7 second response delay from the start of the gesture execution
                    delay = cat(1, delay, M); % save delay of gesture execution
                    GT_pred = cat(2, GT_pred, [gest_times_GT(1,i) ; gest_times_pred(1, time_diff == M)]);
                else
                    GT_pred = cat(2, GT_pred, [gest_times_GT(1,i); idle_label]); % missed gesture
                end
            end

            % find predicted gestures when nothing realy happened - false positive
            for i = 1:size(gest_times_pred, 2)
                curr_time = gest_times_pred(2,i);
                time_diff = curr_time - gest_times_GT(2,:);
                M = min(time_diff(time_diff >= 0));
                if M > M_max % allow up to 7 second response delay from the start of the gesture execution
                    GT_pred = cat(2, GT_pred, [1 ; gest_times_pred(1,i)]);
                end
            end

            % calculate the accuracy misse rate and mean delay
            mean_delay = mean(delay);
            CM = confusionmat(GT_pred(1,:), GT_pred(2,:)); % confusion matrix
            % differ between cases where we have or dont have class idle 
            if ismember(idle_label, GT_pred)
                accuracy =  sum(diag(CM(~idle_idx, ~idle_idx)))/sum(sum(CM(:,~idle_idx))); 
                missed_gest = sum(CM(:,idle_idx))/sum(sum(CM(~idle_idx,:)));
            elseif length(unique(GT_pred)) >= 2
                accuracy =  sum(diag(CM))/sum(sum(CM)); 
                missed_gest = 0;
            else % this is not supposed to happen unless you segmented and labeled the data in a very poorly way
                accuracy = 0;
                missed_gest = 1;
            end
            

            % plot the gestures 
            if print                
                figure('Name', 'gesture execution moments')
                plot(obj.supp_vec(2,:), obj.supp_vec(1,:), 'r*', 'MarkerSize', 1); hold on;
                plot(gest_times_pred(2,:), gest_times_pred(1,:), 'bs', 'MarkerSize', 5);
                xlabel('time [s]'); ylabel('class'); 
                title(['model accuracy is: ' num2str(accuracy) ' with a miss rate of: ' num2str(missed_gest) ', and a mean delay of:' num2str(mean_delay)]);
                legend({'true gestures', 'predicted executed gesture'})
                figure('Name', 'geasture detection CM')
                if ismember(idle_label, GT_pred)
                    confusionchart(CM, class_name);
                elseif length(unique(GT_pred)) >= 2
                    confusionchart(CM, class_name(~idle_idx));
                else
                    disp('there is only 1 class in both true labels and predictions, try a better preprocessing pipeline!');
                end
            end
        end
    end
end
