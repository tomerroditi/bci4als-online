classdef bci_model < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        model              % the ML model (probabilistics models only!)
        threshold          % threshold for idle class classification
        selected_feat_idx  % used features indices (for feature dependent models)
        DL_flag            % flag to mark if its a DL model or not
        pipeline        % the options structure that was used to create the model
        conf_level = 4;    % confidence level
        cool_time  = 4;    % time to wait before executing another gesture
        max_delay  = 7;    % maximum time delay between real gesture execution and gesture recognition
        train              % recordings\names that used to train the model
        val                % recordings\names that used to validate the model
    end

    methods
        %% constructor
        function obj = bci_model(train, val)
            % train/val/test - a recording object
            obj.train = train;
            obj.val = val;
            obj.pipeline = train.get_pipeline();

            obj.train.create_ds(oversample = true); 
            obj.val.create_ds();
            obj.train.augment();
            obj.train_my_model();
            obj.train.create_ds(); % remove oversampled data from the ds

            % calculate model threshold for idle classification
            obj.set_threshold('accu', 1)
            obj.set_optimal_ct_cl_values(); % set cool time and confidence level
        end

        function train_my_model(obj)            
            % check what DL pipelines are available in the folder "4.DL pipelines"
            DL_pipe = dir('4.DL pipelines');
            DL_pipe_names = extractfield(DL_pipe, 'name');

            train_ds = obj.train.get_ds(); %#ok<NASGU> 
            val_ds = obj.val.get_ds(); %#ok<NASGU> 
            
            % train the desired model 
            algo = obj.pipeline.model_algo;
            if ismember([algo '.m'], DL_pipe_names) % DL models
                obj.model = eval([algo '(train_ds, val_ds, obj.pipeline);']); % this will call the DL pipeline
                obj.selected_feat_idx = []; % we currently use none feature NN
                obj.DL_flag = true;
            else % classic ml models
                obj.DL_flag = false;
                error('classic ml is not supported yet, pls use a valid DL pipeline name')
            end
        end

        
        %% model values related methods
        % setting cool time and confidence level values
        function set_values(obj, cool_time, confidence_level)
        % this function is used to set new values for the cool time,
        % confidence level and max delay
        % Inputs:
        %   cool_time - float, new value for cool_time property
        %   confidence_level - int, new value for conf_level property
        %   max_delay - float - new value for max_delay property
            obj.cool_time = cool_time;
            obj.conf_level = confidence_level;
        end
        
        % optimize cool time and confidence level
        function set_optimal_ct_cl_values(obj)
        % this function is used to find the optimal cool time and
        % confidence level of the model, and sets their properties
        % accordingly
            cooling = 2:0.5:8;
            confidence = 1:8;

            best_metric = 0;
            best_param = [1, 1]; % initialize the best params array
            pred = obj.classify(obj.train);

            for i = 1:length(cooling)
                for j = 1:length(confidence)
                    obj.set_values(cooling(i), confidence(j));
                    [accuracy, missed_gest] = obj.classify_gestures(obj.train, predictions = pred);
                    curr_metric = accuracy*(1-missed_gest); % insert here a function to find the best parameters 
                    if curr_metric > best_metric
                        best_metric = curr_metric;
                        best_param = [cooling(i), confidence(j)];
                    end
                end
            end
            obj.set_values(best_param(1), best_param(2)); % set the best parameters
        end

        function  set_threshold(obj, crit, crit_thresh)
            % this function is used to set a new threshold to the model.
            % Inputs:
            %   crit_thresh - double, for a single input its the new threshold value,
            %                 for two inputs its the criterion threshold in the range [0 1]
            %   crit - str, the criterion to calculate by, refer to matlab
            %          perfcurv criterions.
            % Outputs:
            %   new_thresh - the new threshold of the model
            classes = obj.train.get_labels_categories();
            idle_idx = strcmp(classes, 'idle');

            data_store = obj.train.get_ds();
            scores = predict(obj.model, data_store);
            true_labels = obj.train.get_labels_of_ds();
            [crit_values, ~, thresholds] = perfcurve(true_labels, scores(:,idle_idx), 'idle', 'XCrit', crit);

            % set a working point for class Idle
            [~,I] = min(abs(crit_values - crit_thresh));
            obj.threshold = thresholds(I); % the working point
        end

        %% classifications of recording objects
        % classify segments
        function [predictions, CM] = classify(obj, recording, args)
        % this function predicts on recording object
            arguments
                obj
                recording
                args.plot = false;
                args.plot_title = '';
            end
            % perform evaluation on each data store
            if ~isa(recording, 'recording')
                error('bci model objects can only classify recording objects')
            elseif isempty(recording.data_store)
                recording.create_ds();
            end

            classes = obj.train.get_labels_categories();
            idle_idx = strcmp(classes, 'idle');
            classes(idle_idx) = [];

            data_store = recording.get_ds();
            scores = predict(obj.model, data_store);

            [~, indices] = max(scores(:,~idle_idx), [], 2);
            predictions = classes(indices);
            predictions(scores(:,idle_idx) >= obj.threshold) = {'idle'};
            predictions = categorical(predictions);

            true_labels = recording.get_labels_of_ds();
            CM = confusionmat(true_labels, predictions);

            if args.plot
                recording.visualize(predictions, title = args.plot_title)
            end
        end

        % classify gestures
        function [accuracy, missed_gest, mean_delay, gest_CM, predictions] = classify_gestures(obj, recording, args)
            arguments
                obj
                recording
                args.predictions
                args.plot = false;
                args.plot_title = '';
            end
            if ~isa(recording, 'recording')
                error('bci model objects can only classify recording objects')
            elseif isempty(recording)
                accuracy = []; missed_gest = []; mean_delay = []; gest_CM = []; predictions = [];
                return
            end
            if ~isfield(args, 'predictions')
                predictions = obj.classify(recording, plot = args.plot, plot_title = args.plot_title);
            else
                predictions = args.predictions;
            end
            [accuracy, missed_gest, mean_delay, gest_CM] ...
                = detect_gestures(obj, recording, predictions, args.plot, args.plot_title);
        end


        %% model visualizations
        % activation layer outputs
        function activation_layer_output(obj, recording)
        % this function is used to calculate and visualize the model 'activation'
        % layer outputs and hold it on obj.fc_act. you need to name a
        % layer as 'activations' when constructing the DL pipeline in 
        % order to use this function.
            if obj.DL_flag
                % find the activation layer index
                flag = 0;
                for i = 1:length(obj.model.Layers)
                    if strcmp('activations', obj.model.Layers(i).Name)
                        flag = 1;
                        break
                    end
                end
                if flag
                    % extract activations from the fc layer
                    act_output = activations(obj.model, recording.data_store, 'activations');
                    dims = 1:length(size(act_output)); % create a dimention order vector
                    dims = [dims(end), dims(1:end - 1)]; % shift last dim (batch size) to be the first
                    act_output = squeeze(permute(act_output, dims));
                    act_output = reshape(act_output, [size(act_output,1), size(act_output,2)*size(act_output,3)]);
                else
                    disp(['No layer named "activations" found, pls check the model architecture and the layers names,' newline...
                        'and change the layer name you would like to visualize to "activations"'])
                end
                points = tsne(act_output, 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', 3);
                scatter_3D(points, recording);
            else
                disp('"fc_activation" function is not supported for classic ML models');
            end
        end

        % model output 
        function model_output(obj, recording)
        % this function is used to calculate and visualize the model output - scores,
        % and holds it in obj.mdl_output
            mdl_output = predict(obj.model, recording.data_store);
            if size(mdl_output,2) > 3
                mdl_output = tsne(mdl_output, 'Algorithm', 'exact', 'Distance', 'euclidean', 'NumDimensions', 3);
            end
            scatter_3D(mdl_output, recording);
        end

        %% model explainability
        function EEGNet_explain(obj)
            if strcmp(obj.pipeline.model_algo(1:6), 'EEGNet') 
                plot_weights(obj.model, obj.pipeline.electrode_loc)
            end
        end

        %% transfer learning and fine tuning
        function new_model = transfer_learning(obj, train, val)

            pipeline = obj.pipeline;
            train.rsmpl_data();
            train.create_ds(); val.create_ds();
            train.augment();
            % set some training and optimization parameters
            training_options = trainingOptions('adam', 'Plots','training-progress', ...
                'Verbose', true, 'VerboseFrequency',pipeline.verbose_freq, ...
                'MaxEpochs', 30, 'MiniBatchSize', pipeline.mini_batch_size, ...  
                'Shuffle','every-epoch', 'ValidationData', val.data_store, ...
                'ValidationFrequency', pipeline.validation_freq, ...
                'InitialLearnRate', 0.0001, 'OutputNetwork', 'last-iteration');
            new_model = copy(obj);
            new_model.train = train; new_model.val = val;
            new_model.model = trainNetwork(train.data_store, obj.model.Layers, training_options);
            train.remove_rsmpl_data(); % retain the original data and data store
            % set new threshold
            [~, new_model.threshold] = evaluation(new_model, train.data_store, train.labels, ...
                criterion = 'accu', criterion_thresh = 1);
            % find the best values for cool time and confidence level
            new_model.find_optimal_values();

        end

        function new_thresh = fine_tune_model(obj, path)           
            train_fine = recording(path, obj.pipeline);
            train_fine.rsmpl_data()
            train_fine.create_ds();
            train_fine.augment()
            
            % check data distribution
            disp('fine tuning training data distribution'); tabulate(train_fine.labels)
            
            % train the model on the new data
            training_options = trainingOptions('adam', ...
                'Verbose', true, ...
                'VerboseFrequency', 10, ...
                'MaxEpochs', 50, ...
                'MiniBatchSize', obj.pipeline.mini_batch_size, ...  
                'Shuffle','every-epoch', ...
                'InitialLearnRate', 0.0001, ...
                'OutputNetwork', 'last-iteration');
            
            obj.model = trainNetwork(train_fine.data_store, obj.model.Layers, training_options);
            
            % update the bci_model object model
            [~, new_thresh] = evaluation(obj, train_fine.data_store, train_fine.labels, ...
                            criterion = 'accu', criterion_thresh = 1, print = true);
            obj.set_threshold(new_thresh)
            end

        %% save and load models
        function  save(obj, path, args)
        % this function saves the model without the recordings data,
        % instead we save each recordings names to save memory
        % Inputs:
        %   path - a folder path to save the model into
            arguments
                obj
                path
                args.file_name = 'bci_model';
            end
            if path == 0
                return
            end
            % we save only the names so the saved obj will take less memory
            obj.train = obj.train.Name;
            obj.val = obj.val.Name;
            % save the object under the name 'model'
            if ~isempty(path)
                S.('model') = obj;
                save(fullfile(path, args.file_name), "-struct", 'S');
            end
        end

        function load_data(obj)
        % this function reconstruct a loaded model recordings data
            [recorders_t, num_t] = names2rec_num(obj.train);
            [recorders_v, num_v] = names2rec_num(obj.val);
            obj.train = multi_recording(recorders_t, num_t, obj.pipeline);
            obj.val = multi_recording(recorders_v, num_v, obj.pipeline);
            obj.train.create_ds(); obj.val.create_ds();
        end

    end

    methods (Access = ?bci_model_cv)
        % setting a recording to a certain field
        function set_train(obj, rec)
            obj.train = rec;
        end
        function set_val(obj, rec)
            obj.val = rec;
        end
    end
end