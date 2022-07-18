classdef recording < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        path                    % the path of the data file (str array\cell)
        options                 % the options structure
        Name                    % the name of the recording (str array\cell)
        raw_data                % raw data from file
        raw_data_filt           % filtered raw data
        markers                 % markers structure (str array\cell)
        segments                % segmented data
        features                % extracted features
        labels                  % data labels
        supp_vec                % 2D raw array containing each time point and its label
        data_store              % a data store containing the segments and labels
        sample_time             % the time point that each segments ends in
        constants               % a Constant object
        predictions             % predictions for some model
        fc_act                  % the last fully connected activations of the givven model to the data store 
        mdl_output              % outputs of a givven model to the data store
        file_type               % data file type - 'edf','xdf'
        model                   % the bci_model object used to create the prediction array 
    end

    methods
        %% construct the object - load a file, segment and filter its data
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
                    error(['Error. only {"xdf","edf"} file types are supported for loading data!' newline ...
                        'pls choose a different file path than:' newline filepath])
                end
                % create segments
                [obj.raw_data, segments, obj.labels, obj.supp_vec, obj.sample_time] = ...
                    data_segmentation(obj.raw_data, obj.markers, options); 
                % filter the segments and the raw data array
                segments = filter_segments(segments, options.cont_or_disc, obj.constants); 
                obj.raw_data_filt = filter_segments(obj.raw_data, options.cont_or_disc, obj.constants);
                % create sequences
                obj.segments = create_sequence(segments, options); 
            end
        end

        %% normalizations - you can choose what data to normalize (segments/raw data/filtered raw data)
        function normalize(obj, seg_raw_filt_all)
            % this function normalizes each electrode according to the
            % percentiles in the constants of the object into the range
            % [-1:1]
            % input: 
            %   seg_raw_filt_all - a string to determine what data to normalize,
            %                      choose from {'segments', 'raw', 'filt', 'all'} 
            
            % do nothing if the object is empty
            if isempty(obj.raw_data) 
                return
            end
            % segments normalization
            if strcmp(seg_raw_filt_all, 'segments') || strcmp(seg_raw_filt_all, 'all')
                obj.segments = norm_eeg(obj.segments, obj.constants.quantiles);
            end
            % raw data normalization
            if strcmp(seg_raw_filt_all, 'raw') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data = norm_eeg(obj.raw_data, obj.constants.quantiles);
            end
            % filtered data normalization
            if strcmp(seg_raw_filt_all, 'filt') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data_filt = norm_eeg(obj.raw_data_filt, obj.constants.quantiles);
            end
        end

        %% feature extraction 
        function extract_feat(obj)
            % this function is used to extract features from the data, its
            % calling the feature extraction function according to the
            % 'feat_alg' field in the object options structure and holds
            % the calculated features in obj.features 

            % if object is empty then do nothing
            if isempty(obj.segments) 
                return
            end
            % execute the desired feature extraction method
            if strcmp(obj.options.feat_alg, 'wavelet')
                obj.features = wavelets(obj);
            elseif strcmp(obj.options.feat_alg, 'basic')
                obj.features = MI4_ExtractFeatures(obj.segments); % this is not supported yet
            elseif strcmp(obj.options.feat_alg, 'none') % no features to extract
                return
            else
                error('pls choose an available feature algorithm')
            end
        end
       
        %% resampling segments
        function new_obj = rsmpl_data(obj, args)
            % this function is used to resample the data so we'll have an 
            % even labels distribution 
            % inputs: args.print - bool, specify if you want to print the 
            %                      new labels distibution after resampling
            % Output: new_obj - a copy of the object with the resampled
            %                   segments, features and labels
            arguments
                obj
                args.print = true;
            end
            new_obj = copy(obj); % create a copy of the object
            % resample segments and features of the new_obj
            [new_obj.segments, new_obj.labels] = resample_data(new_obj.segments, new_obj.labels, args.print);
            new_obj.features = resample_data(new_obj.features, new_obj.labels, args.print);
        end
            
        %% create a data store (DS) from the obj segments and labels
        function create_ds(obj, args)
            % this function is used to create a data store from the object
            % segments\features according to the value of 'feat_or_data'
            % field in the object options structure.
            % Input: reject_class - a class name to exclude from the data store
            %
            % notes: consider the fact that you cant (yet) visualize 
            %        predictions if you reject classes
            arguments
                obj
                args.reject_class = {}
            end
            if isempty(obj.raw_data)
                return
            end
            feat_or_data = obj.options.feat_or_data;
            % verify that the class name exist and notify if its not
            class_names = obj.constants.class_name_model;
            if any(~ismember(args.reject_class, class_names))
                not_found = args.reject_class(~ismember(args.reject_class, class_names));
                disp(['notice that the class names: ' strjoin(not_found,',') ' are not found in the object classes,'...
                    "hence they can't be rejected!"]);   
            end
            if strcmp(feat_or_data, 'data') % use processed data to create ds
                obj.data_store = set2ds(obj.segments, obj.labels, obj.constants, args.reject_class);
            elseif strcmp(feat_or_data, 'feat') % use features to create ds
                obj.data_store = set2ds(obj.features, obj.labels, obj.constants, args.reject_class);
            end
        end
   
        %% data augmentation
        function new_obj = augment(obj)
            % this function is used to create a new object with an
            % augmented data store, you can control the augmentations from
            % the constant object
            % Outputs: new_obj - a copy of the object with an augmented
            %                    data store
            new_obj = copy(obj);
            if ~isempty(obj.data_store)
                new_obj.data_store = transform(obj.data_store, @augment_data);
            end
        end

        %% complete data preprocessing pipeline
        function rsmpld_obj = complete_pipeline(obj, args)
            % this function is used to apply the complete pipeline on the
            % object - normalization, feature extraction, data store
            % creation, resampling, augmentations.
            % Inputs:
            %   rsmpl - bool, create a resampled (augmented) object or not 
            %   reject_class - a cell containing class names to reject from
            %                  the data store
            %   print - bool, print new class distribution after resampling
            %
            % Outputs:
            %   rsmpld_obj - a resampled augmented object, returned as an
            %                empty object if 'rsmpl' is set to false (default)
            arguments
                obj
                args.rsmpl = false; 
                args.reject_class = {}; 
                args.print = false; 
            end
            obj.normalize('all');
            obj.extract_feat();
            obj.create_ds(reject_class = args.reject_class)
            if args.rsmpl
                rsmpld_obj = obj.rsmpl_data(print = args.print);
                rsmpld_obj.create_ds(reject_class = args.reject_class)
                rsmpld_obj = rsmpld_obj.augment();
            else
                rsmpld_obj = recording(); % return it as an empty recording
            end
        end
        
        %% set a bci_model object to the recording object
        function set_model(obj, bci_model)
            % this function is used to set a new bci_model object to the
            % recording object, it's also resets all model related fields
            % of the recording object
            % Inputs: bci_model - a bci_model object

            if ~isempty(obj.raw_data)
                % set the object model
                obj.model = bci_model;
                % reset all model related fields
                obj.fc_act = [];
                obj.mdl_output = [];
                obj.predictions = [];
            end
        end

        %% evaluation & classification 
        function [pred, thresh, CM] = evaluate(obj, options)
            % this function is used to evaluate a model on the object's data
            % Inputs:
            %   CM_title - a string with the confusion matrix title ('train', 'val', 'test')
            %   print - bool, print the CM and the model accuracy
            % Outputs:
            %   pred - an array containing the predicted class of each segments
            %   thresh - the threshold that was chosen for the model
            %   CM - a confusion matrix of the predictions
            arguments
                obj
                options.CM_title = '';
                options.print = false;
            end
            % return empty outputs if the obj is empty
            if isempty(obj.raw_data)
                pred = []; thresh = []; CM = [];
                return
            end

            bci_model = obj.model;         
            if bci_model.DL_flag % use the model threshold if its a DL model
                [pred, thresh, CM] = evaluation(bci_model, obj.data_store, obj.constants, CM_title = options.CM_title, ...
                    thres_C1 = bci_model.threshold, print = options.print);
                obj.predictions = pred;
            else % use default prediction function for classic ML models
                [pred, thresh, CM] = evaluation(bci_model.model, obj.data_store, obj.constants, CM_title = options.CM_title, ...
                    print = options.print);
                obj.predictions = pred;
            end
        end
        
        %% visualization of predictions
        function visualize(obj, options)
            % this function is used to visualize the model predictions
            % Inputs: title - a title for the plot ('train', 'val', 'test')
            arguments
                obj
                options.title = '';
            end
            visualize_results(obj.supp_vec, obj.labels, obj.predictions, obj.sample_time, options.title)
        end

        %% model activations operations
        function activation_output(obj)
            % this function is used to calculate a model 'activation'
            % layer outputs and hold it on obj.fc_act. you need to name a
            % layer as 'activations' when constructing the DL pipeline in 
            % order to use this function.
            
            if isempty(obj.raw_data)
                return
            end
            if obj.model.DL_flag
                % find the activation layer index
                flag = 0;
                for i = 1:length(obj.model.model.Layers)
                    if strcmp('activations', obj.model.model.Layers(i).Name)
                        flag = 1;
                        break
                    end
                end
                if flag
                    % extract activations from the fc layer
                    obj.fc_act = activations(obj.model.model, obj.data_store, 'activations');
                    dims = 1:length(size(obj.fc_act)); % create a dimention order vector
                    dims = [dims(end), dims(1:end - 1)]; % shift last dim (batch size) to be the first
                    obj.fc_act = squeeze(permute(obj.fc_act, dims));
                    obj.fc_act = reshape(obj.fc_act, [size(obj.fc_act,1), size(obj.fc_act,2)*size(obj.fc_act,3)]);
                else
                    disp(['No layer named "activations" found, pls check the model architecture and the layers names,' newline...
                        'and change the layer name you would like to visualize to "activations"'])
                end
            else
                disp('"fc_activation" function is not supported for classic ML models');
            end
        end

        %% model output
        function model_output(obj)
            % this function is used to calculate the model output - scores,
            % and holds it in obj.mdl_output
            if isempty(obj.raw_data)
                return
            end
            if obj.model.DL_flag
                if isa(obj.model.model, 'dlnetwork') % need to work with dlarrays in that case
                    data_set = readall(obj.data_store);
                    data_set(:,1) = cellfun(@(x) permute(x, [3,1,2]), data_set(:,1), 'UniformOutput',false);
                    dlarray_seg = dlarray(permute(cell2mat(data_set(:,1)),[2,3,4,1]), 'SSCB'); 
                    obj.mdl_output = predict(obj.model.model, dlarray_seg);
                    obj.mdl_output = gather(extractdata(obj.mdl_output)); % convert dlarray back to double
                else
                    obj.mdl_output = predict(obj.model.model, obj.data_store);
                end
            else
                disp('"model_output" function is not supported for classic ML models');
            end
        end

        %% visualize activations of a model
        function visualize_layer(obj, dim_red_algo, num_dim, act_out)
            % this function is used to visualize the activations layer
            % output or the output layer ussing dimentions reductions
            % algorithms (pca or tsne) in a 2D or 3D scatter plot
            % Inputs:
            %   dim_red_algo - a string from {'pca', 'tsne'} deciding what
            %                  dimentions reduction algorithm to use
            %   num_dim - the number of dimentions to plot - [2,3]
            %   act_out - the layer to visualize - {'act', 'out'}

            % check that the layer output has been calculated
            if strcmp(act_out, 'act') && isempty(obj.fc_act)
                disp(['You need to calculate the "fc" layer activations in order to visualize them' newline ...
                    'Use the "fc_activation" method to do so!']);
                return
            elseif strcmp(act_out, 'out') && isempty(obj.mdl_output)
                disp(['You need to calculate the outputs of the model in order to visualize them' newline ...
                    'Use the "model_output" method to do so!']);
                return
            end
            % keep asking for inputs untill a correct one is given
            while ~ismember(dim_red_algo, ["pca","tsne"])
                dim_red_algo = input(['Dimentional reduction algorithm name is wrong,' newline...
                    'pls select from {"pca","tsne"} and type it here: ']);
            end
            % get the chosen data - activations or outputs
            if  strcmp(act_out, 'act')
                data = obj.fc_act;
            elseif strcmp(act_out, 'out')
                data = obj.mdl_output;
            end
            % dimentions reduction
            if strcmp(dim_red_algo, 'tsne')
                points = tsne(data, 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', num_dim);
            elseif strcmp(dim_red_algo, 'pca')
                points = pca(obj.fc_act);
                points = points.';
                points = points(:,1:num_dim);
            end 
            % scatter plotting
            if num_dim == 2
                scatter_2D(points, obj);
            elseif num_dim == 3
                scatter_3D(points, obj);
            else
                disp('Unable to plot more than a 3D representation of the data!');
            end
        end

        %% gesture detection
        function gest_time = get_gestures(obj, K, cool_time, pred_GT)
            % this function is used to extract the executed gestures from
            % the object predictions\labels according to some parameters.
            % Inputs:
            %   K - the number of labels detected in a raw to execute a gesture
            %   cool_time - time window to not execute a gesture after executing a gesture
            %   pred_GT - extract the ground truth gestures or the predicted ones - {'pred', 'GT'}.

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
                class_label = obj.constants.class_label;
                class_names = obj.constants.class_names;
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

        function [accuracy, missed_gest, mean_delay, CM, gest_times_pred] = detect_gestures(obj, args)
            % this functions is used to calculate the model accuracy on
            % gesture execution. you can set new values for conf_level,
            % cool_time and max_delay field of the recording bci_model
            % object as well.
            % Inputs:
            %   print - bool, print CM and gesture visualization or not
            % Outputs:
            %   accuracy - the model gesture accuracy
            %   missed_gest - the model missed gestures percentage
            %   mean_delay - the mean time between true gesture execution
            %                time and gesture recognition
            %   CM - a confusion matrix of gesture recognition
            %   gest_times_pred - the time of each gesture recognition and
            %                     the gesture label

            arguments
                obj
                args.print = false;
            end
            if isempty(obj.predictions)
                accuracy = [];
                missed_gest = [];
                mean_delay = [];
                CM = [];
                gest_times_pred = [];
                return
            end

            K = obj.model.conf_level;
            cool_time = obj.model.cool_time;
            max_delay = obj.model.max_delay;
            
            % calculate true and predicted gesture execution times
            gest_times_pred = get_gestures(obj, K, cool_time, 'pred');
            gest_times_GT = get_gestures(obj, K, cool_time, 'GT');

            % some labels procedures
            class_label = obj.constants.class_label;
            class_name = obj.constants.class_names;
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
                if M < max_delay % allow up to max_delay second response delay from the start of the gesture execution
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
                if M > max_delay % allow up to max_delay second response delay from the start of the gesture execution
                    GT_pred = cat(2, GT_pred, [1 ; gest_times_pred(1,i)]);
                end
            end

            % calculate the accuracy misse rate and mean delay
            mean_delay = mean(delay);
            if ~isempty(GT_pred)
                CM = confusionmat(GT_pred(1,:), GT_pred(2,:)); % confusion matrix
            end
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
            if args.print                
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
