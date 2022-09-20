classdef bci_model < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        model              % the DL model
        threshold          % threshold for idle class classification
        pipeline           % the my pipeline object that was used to create the training data
        confidence = 4;    % confidence level (number of non idle predictions in a row to invoke a gesture)
        cool_time  = 4;    % seconds to wait before allowing another gesture execution
        train_rec          % recordings that used to train the model
        val_rec            % recordings that used to validate the model
    end

    methods (Access = public)
        %% constructor
        function obj = bci_model(training_recording, validation_recording)
            % train/val/test - a recording object
            obj.train_rec = training_recording;
            obj.val_rec = validation_recording;
            obj.pipeline = training_recording.get_pipeline();
        end

        function train_model(obj, args)
            arguments
                obj
                args.oversample logical = false;
                args.augment  logical = false;
            end
            [train_ds, val_ds] = obj.get_data_stores(args.oversample, args.augment); %#ok<ASGLU> 

            model_algo = obj.pipeline.model_algo;
            try 
                obj.model = eval([model_algo '(train_ds, val_ds, obj.pipeline);']); % this will call the DL pipeline
            catch ME
                switch ME.identifier
                    case 'MATLAB:UndefinedFunction'
                        error(['the model algorithm "' model_algo '" does not exist, pls use a valid DL pipeline name']);
                    otherwise
                        rethrow(ME);
                end
            end
        end

        
        %% model values related methods
        % setting cool time and confidence level values
        function set_ct_conf(obj, cool_time, confidence_level)
        % this function is used to set new values for the cool time,
        % confidence level and max delay
        % Inputs:
        %   cool_time - float, new value for cool_time property
        %   confidence_level - int, new value for conf_level property
            obj.cool_time = cool_time;
            obj.confidence = confidence_level;
        end
        
        function set_optimal_ct_conf(obj, cool_time_range, confidence_range)
        % this function is used to find the optimal cool time and
        % confidence level of the model, and sets their properties
        % accordingly
            best_metric = 0;
            best_param = [cool_time_range(1), confidence_range(1)]; % initialize the best params array

            seg_CM = obj.classify_segments(obj.train_rec);
            segment_pred = seg_CM.get_predicted_labels();

            [gesture_true, gesture_true_indices] = obj.train_rec.get_gestures();
            
            for i = 1:length(cool_time_range)
                for j = 1:length(confidence_range)
                    [gesture_pred, gesture_pred_indices] = obj.train_rec.get_predicted_gestures(segment_pred, confidence_range(j), cool_time_range(i));
                    gest_CM = gesture_CM(gesture_true, gesture_true_indices, gesture_pred, gesture_pred_indices);
                    [accuracy, miss_rate] = gest_CM.get_stats();

                    curr_metric = accuracy*(1 - miss_rate); % insert here a function to find the best parameters 
                    if curr_metric > best_metric
                        best_metric = curr_metric;
                        best_param = [cool_time_range(i), confidence_range(j)];
                    end
                end
            end
            obj.set_ct_conf(best_param(1), best_param(2)); % set the best parameters
        end

        function set_threshold(obj, crit, crit_thresh)
            % this function is used to set a new threshold to the model.
            % Inputs:
            %   crit_thresh - double, for a single input its the new threshold value,
            %                 for two inputs its the criterion threshold in the range [0 1]
            %   crit - str, the criterion to calculate by, refer to matlab
            %          perfcurv criterions.

            classes = obj.train_rec.get_classes();
            idle_idx = strcmp(classes, 'idle');

            data_store = obj.train_rec.get_data_store();
            scores = predict(obj.model, data_store);
            true_labels = recording.get_labels_from_data_store(data_store);
            [crit_values, ~, thresholds] = perfcurve(true_labels, scores(:,idle_idx), 'idle', 'XCrit', crit);

            % set a working point for class Idle
            [~,I] = min(abs(crit_values - crit_thresh));
            obj.threshold = thresholds(I); % the working point
        end

        %% classifications of recording objects
        function [segment_CM, gesture_CM] = classify_recording(obj, recording, args)
            arguments
                obj
                recording
                args.only_segments = false;
                args.plot = false;
                args.group = 'new';
            end

            segment_CM = []; gesture_CM = [];

            if ~isa(recording, 'recording')
                error('bci model objects can only classify recording objects')
            elseif isempty(recording)
                return
            end

            if args.only_segments
                segment_CM = obj.classify_segments(recording, plot = args.plot, group = args.group);
            else
                [gesture_CM, segment_CM] = obj.classify_gestures(recording, plot = args.plot, group = args.group);
            end
        end

        %% model visualizations
        % activation layer outputs
        function activation_layer_output(obj, recording)
        % this function is used to calculate and visualize the model 'activation'
        % layer outputs and hold it on obj.fc_act. you need to name a
        % layer as 'activations' when constructing the DL pipeline in 
        % order to use this function.
            if isa(obj.model, 'DAGNetwork') || isa(obj.model, 'SeriesNetwork')
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

        % model explainability
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
        function save(obj, path, args)
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
            obj.train_rec = obj.train_rec.get_files_handler();
            obj.val_rec = obj.val_rec.get_files_handler();
            % save the object under the name 'model'
            if ~isempty(path)
                S.('bci_model') = obj;
                save(fullfile(path, args.file_name), "-struct", 'S');
            end
        end

        function load_recordings_data(obj)
        % this function reconstruct a loaded model recordings data
            obj.train_rec = recording(obj.train_rec, obj.pipeline);
            obj.val_rec = recording(obj.val_rec, obj.pipeline);
        end

    end

    methods (Access = protected)
        function [train_ds, val_ds] = get_data_stores(obj, oversample, augment)
            train_ds = obj.train_rec.get_data_store(oversample = oversample, augment = augment);
            val_ds = obj.val_rec.get_data_store();
            if ~hasdata(val_ds)
                val_ds = []; 
            end
        end

        % classify segments
        function seg_CM = classify_segments(obj, rec, args)
        % this function predicts on recording object
            arguments
                obj
                rec
                args.plot = false;
                args.group = 'new';
            end

            classes = rec.get_classes();
            idle_idx = strcmp(classes, 'idle');
            classes(idle_idx) = [];

            data_store = rec.get_data_store();
            scores = [];
            % predict ds one by one to maintain the labels order -
            % important for gesture recognition and visuallization
            for i = 1:length(data_store.UnderlyingDatastores)
                curr_ds = data_store.UnderlyingDatastores{i};
                curr_scores = predict(obj.model, curr_ds);
                scores = cat(1, scores, curr_scores);
            end

            [~, indices] = max(scores(:,~idle_idx), [], 2);
            predictions = classes(indices);
            predictions(scores(:,idle_idx) >= obj.threshold) = {'idle'};
            predictions = categorical(predictions);

            true_labels = rec.get_labels();
            seg_CM = segment_CM(true_labels, predictions);

            if args.plot
                rec.plot_segments_predictions(predictions, group = args.group);
            end
        end

        % classify gestures
        function [gest_CM, seg_CM] = classify_gestures(obj, rec, args)
            arguments
                obj
                rec
                args.plot = false;
                args.group = 'new';
            end

            seg_CM = obj.classify_segments(rec, plot = args.plot, group = args.group);
            segment_pred = seg_CM.get_predicted_labels();

            [gesture_true, gesture_true_indices] = rec.get_gestures();
            [gesture_pred, gesture_pred_indices] = rec.get_predicted_gestures(segment_pred, obj.confidence, obj.cool_time);

            gest_CM = gesture_CM(gesture_true, gesture_true_indices, gesture_pred, gesture_pred_indices);

            if args.plot
                rec.plot_gesture_predictions(gesture_pred, gesture_pred_indices, group = args.group);
            end
        end
    end
end