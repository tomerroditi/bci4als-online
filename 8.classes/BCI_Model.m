classdef BCI_Model < handle
    properties (SetAccess = protected)
        model              % DL/ML model
        threshold = nan;   % threshold for class classification
        data_pipeline      % data pipeline obj that was used to create the data bases
        model_pipeline     % model pipeline obj used to train the model
        confidence = 4;    % confidence level (number of non idle predictions in a row to invoke a gesture)
        cool_time  = 4;    % seconds to wait before allowing another gesture invoking
        train              % data base obj used for training
        validation         % data base obj used for validation
    end

    methods (Access = public)
        %% constructor
        function obj = BCI_Model(train_DB, model_pipeline, args)
            arguments
                train_DB 
                model_pipeline 
                args.val_DB = Data_Base(); % empty DB
            end

            obj.train = train_DB;
            obj.validation = args.val_DB;
            obj.model_pipeline = model_pipeline;
            obj.data_pipeline = train_DB.get_pipeline();

            obj.train_model(oversample = model_pipeline.oversample_train_data,...
                            augment = model_pipeline.augment_train_data);

            obj.set_threshold(model_pipeline.criterion,...
                              model_pipeline.criterion_thres,...
                              model_pipeline.criterion_class);

            obj.set_optimal_ct_conf(model_pipeline.cool_time_range,...
                                    model_pipeline.confidence_range);
        end

        %% getters
        function [train, val] = get_model_DBs(obj)
            train = obj.train;
            val = obj.validation;
        end
        
        %% setters
        function set_ct_conf(obj, cool_time, confidence)
        % this function is used to set new values for the cool time,
        % confidence level and max delay
        % Inputs:
        %   cool_time - float, new value for cool_time property
        %   confidence_level - int, new value for conf_level property
            obj.cool_time = cool_time;
            obj.confidence = confidence;
        end
        
        function set_optimal_ct_conf(obj, cool_time_range, confidence_range)
        % this function is used to find the optimal cool time and
        % confidence level of the model, and sets their properties
        % accordingly
            best_metric = 0;
            best_param = [cool_time_range(1), confidence_range(1)]; % initialize the best params array

            [seg_end_time, true_labels] = obj.train.get_data_info();
            [gesture_true, gesture_true_indices] = Gestures_Utils.get_true_gestures_from(seg_end_time, true_labels);

            seg_CM = obj.classify_data_base(obj.train, "only_segments", true);
            segment_pred = seg_CM.get_predicted_labels();
            
            for i = 1:length(cool_time_range)
                for j = 1:length(confidence_range)
                    [gesture_pred, gesture_pred_indices] = Gestures_Utils.get_predicted_gestures_from(seg_end_time, segment_pred, confidence_range(j), cool_time_range(i));
                    gest_CM = Gesture_CM(gesture_true, gesture_true_indices, gesture_pred, gesture_pred_indices);
                    [accuracy, miss_rate] = gest_CM.get_stats();

                    curr_metric = accuracy*(1 - miss_rate/2); % insert here a function to find the best parameters 
                    if curr_metric > best_metric
                        best_metric = curr_metric;
                        best_param = [cool_time_range(i), confidence_range(j)];
                    end
                end
            end
            obj.set_ct_conf(best_param(1), best_param(2)); % set the best parameters
        end

        function set_threshold(obj, crit, crit_thresh, crit_class)
            % this function is used to set a new threshold to the model.
            % Inputs:
            %   crit_thresh - double, for a single input its the new threshold value,
            %                 for two inputs its the criterion threshold in the range [0 1]
            %   crit - str, the criterion to calculate by, refer to matlab
            %          perfcurv criterions.
            if strcmpi(crit_class, 'none')
                obj.threshold = nan;
                return
            end

            classes = obj.train.get_classes();
            class_idx = strcmp(classes, crit_class);

            data_store = obj.train.get_data_store();
            scores = predict(obj.model, data_store);
            true_labels = Data_Base.get_labels_from_data_store(data_store);
            [crit_values, ~, thresholds] = perfcurve(true_labels, scores(:,class_idx), crit_class, 'XCrit', crit);

            % set a working point for class Idle
            [~,I] = min(abs(crit_values - crit_thresh));
            obj.threshold = thresholds(I); % the working point
        end

        %% classifications of data bases
        function [segment_CM, gesture_CM] = classify_data_base(obj, DB, args)
            arguments
                obj
                DB
                args.only_segments = false;
                args.plot = false;
                args.group = 'new';
            end

            segment_CM = []; gesture_CM = [];

            if ~isa(DB, 'Data_Base')
                error('bci model objects can only classify recording objects')
            elseif isempty(DB)
                disp('data base is empty, no data to classify');
                return
            end

            % predictions
            if args.only_segments
                segment_CM = obj.classify_segments(DB);
            else
                [gesture_CM, segment_CM] = obj.classify_gestures(DB);
            end

            % ploting
            if args.plot
                segment_CM.plot_CM(group = args.group);
                seg_pred = segment_CM.get_predicted_labels();
                DB.plot_segments_predictions(seg_pred, group = args.group);
                if ~args.only_segments
                    gesture_CM.plot_CM(group = args.group);
                    [gesture_pred, gesture_pred_time] = gesture_CM.get_predicted_gestures();
                    DB.plot_gesture_predictions(gesture_pred, gesture_pred_time, group = args.group);
                end
            end
        end

        %% transfer learning
        function transfer_learning(obj, train_DB, training_options)
            obj.train = train_DB;
            train_ds = train_DB.get_data_store();
            obj.model = trainNetwork(train_ds, obj.model.Layers, training_options);
            obj.threshold = nan;
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
            if path == 0 % matlab save gui return 0 if it get closed without choosing a path
                return
            end

            % save the object under the name 'model'
            if ~isempty(path)
                S.('bci_model') = obj;
                save(fullfile(path, args.file_name), "-struct", 'S');
            end
        end

        function compact_model(obj)
            % turn the obj data bases into files paths handlers so it will
            % use less memory and we can still reconstruct them.
            obj.train = obj.train.get_files_handler();
            obj.validation = obj.validation.get_files_handler();
        end

        function load_recordings_data(obj)
        % this function reconstruct a loaded model recordings data
            obj.train = Data_Base(obj.train, obj.data_pipeline);
            obj.validation = Data_Base(obj.validation, obj.data_pipeline);
        end

    end

    methods (Access = protected)
        function train_model(obj, args)
            arguments
                obj
                args.oversample logical = false;
                args.augment  logical = false;
            end
            [train_ds, val_ds] = obj.get_data_stores(args.oversample, args.augment); %#ok<ASGLU> 

            model_algo = obj.model_pipeline.model_algo;
            try 
                obj.model = eval([model_algo '(train_ds, val_ds, obj.model_pipeline);']); % this will call the DL pipeline
            catch ME
                switch ME.identifier
                    case 'MATLAB:UndefinedFunction'
                        error(['the model algorithm "' model_algo '" does not exist, pls use a valid DL pipeline name']);
                    otherwise
                        rethrow(ME);
                end
            end
        end

        function [train_ds, val_ds] = get_data_stores(obj, oversample, augment)
            train_ds = obj.train.get_data_store(oversample = oversample, augment = augment);
            val_ds = obj.validation.get_data_store();
            if ~hasdata(val_ds)
                val_ds = []; 
            end
        end

        function seg_CM = classify_segments(obj, data_base)
        % this function predicts on data store created by a data base
        % object
            data_store = data_base.get_data_store();
            if ~hasdata(data_store)
                disp('data base is empty (might need a reset), returning an empty segment CM')
                seg_CM = [];
                return
            end

            predictions = [];
            % classify each data store individually to maintain the segments order
            underlying_data_stores = data_store.UnderlyingDatastores; 
            for i = 1:numel(underlying_data_stores)
                if isnan(obj.threshold)
                    curr_pred = classify(underlying_data_stores{i});
                else
                    curr_pred = obj.custom_prediction_function(underlying_data_stores{i});
                end
                predictions = cat(1, predictions, curr_pred);
            end

            true_labels = data_base.get_labels();
            seg_CM = Segment_CM(true_labels, predictions);
        end

        function predictions = custom_prediction_function(obj, data_store)
            exmpl_data = read(data_store);
            reset(data_store); % need to reset before predicting since we read from the ds

            all_classes = categories(exmpl_data{1,2}); % consider getting classes from the model classification layer instead
            class_idx = strcmp(all_classes, obj.model_pipeline.criterion_class);
            no_crit_classes = all_classes(~class_idx);

            scores = predict(obj.model, data_store);

            [~, indices] = max(scores(:,~class_idx), [], 2);
            predictions = no_crit_classes(indices);
            predictions(scores(:,class_idx) >= obj.threshold) = {obj.model_pipeline.criterion_class};
            predictions = categorical(predictions, all_classes);
        end

        function [gest_CM, seg_CM] = classify_gestures(obj, data_base)
            seg_CM = obj.classify_segments(data_base);
            if isempty(seg_CM)
                disp('returning empty gesture CM as well')
                gest_CM = [];
                return
            end

            segment_pred = seg_CM.get_predicted_labels();

            [segments_ends_time, labels] = data_base.get_data_info();

            [gesture_true, gesture_true_time] = Gestures_Utils.get_true_gestures_from(segments_ends_time, labels);
            [gesture_pred, gesture_pred_time] = Gestures_Utils.get_predicted_gestures_from(segments_ends_time, segment_pred, obj.confidence, obj.cool_time);

            gest_CM = Gesture_CM(gesture_true, gesture_true_time, gesture_pred, gesture_pred_time);
        end
    end
end