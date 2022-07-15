classdef bci_model < handle
    properties (GetAccess = public, SetAccess = private)
        model              % the ML model
        threshold          % threshold for idle class classification
        feat_idx           % used features indices (for classic ML only)
        DL_flag            % flag to mark if its a DL model or not
        options            % the options structure that was used to create the model
        conf_level = 4     % confidence level
        cool_time  = 4     % time to wait before executing another gesture
        max_delay  = 7;    % maximum time delay between real gesture execution and gesture recognition
        train              % recordings that used to train the model
        val                % recordings that used to validate the model
        test               % recordings that used to test the model
    end

    methods
        %% constructor
        function obj = bci_model(train, val, test, args)
            arguments
                train
                val
                test
                args.pipeline = false; % whether to apply the data pipeline on the data sets or not
            end
            %train/val/test - a recording object
            obj.train = train;
            obj.val = val;
            obj.test = test;
            obj.options = train.options;

            if args.pipeline
                % data pipeline - normalization, feature extraction, data store construction
                train_rsmpl_aug = obj.train.complete_pipeline(rsmpl = true);
                obj.val.complete_pipeline();
                obj.test.complete_pipeline();
            else
                train_rsmpl = obj.train.rsmpl_data();
                train_rsmpl.create_ds();
                train_rsmpl_aug = train_rsmpl.augment();
            end
            
            % train a model according to the model_algo name in the options structure
            [obj.model, obj.feat_idx, obj.DL_flag] = train_my_model(obj.options.model_algo,...
                obj.options.constants, train_rsmpl_aug.data_store, obj.val.data_store);

            % calculate model threshold for idle classification - you may
            % change the threshold selection process as you wish
            [~, obj.threshold] = evaluation(obj, obj.train.data_store, obj.train.constants, ...
                criterion = 'accu', criterion_thresh = 1); 
        end
        
        %% setting cool time and confidence level values
        function set_values(obj, cool_time, confidence_level, max_delay)
            obj.cool_time = cool_time;
            obj.conf_level = confidence_level;
            obj.max_delay = max_delay;
            % set the new model to the recordings objects
            obj.train.set_model(obj);
            obj.val.set_model(obj);
            obj.test.set_model(obj);
        end
        
        %% optimize cool time and confidence level
        function find_optimal_values(obj)
            cool_time = 0:0.5:8;
            confidence = 1:6;
            for i = 1:length(cool_time)
                for j = 1:length(confidence)
                    % insert here a function to find the best parameters - work in progress...
                end
            end
            obj.cool_time = best(1);
            obj.conf_level = best(2);
        end

        %% evaluate the model on the data
        function [train_CM, val_CM, test_CM] = evaluate(obj, args)
            arguments
                obj
                args.print = false
            end
            % perform evaluation on each data store
            [~,~,train_CM] = obj.train.evaluate(obj, CM_title = 'train', print = args.print);
            [~,~,val_CM] = obj.val.evaluate(obj, CM_title = 'val', print = args.print);
            [~,~,test_CM] = obj.test.evaluate(obj, CM_title = 'test', print = args.print);
        end

        %% visualize predictions
        function visualize(obj)
            visualize_results(obj.train.supp_vec, obj.train.labels, obj.train.predictions, obj.train.sample_time, 'train');
            visualize_results(obj.val.supp_vec, obj.val.labels, obj.val.predictions, obj.val.sample_time, 'val');
            visualize_results(obj.test.supp_vec, obj.test.labels, obj.test.predictions, obj.test.sample_time, 'test');
        end
            
        %% detect gestures - use the updated model parameters
        function [accuracy, missed_gest, mean_delay, CM, gest_times_pred] = detect_gestures(obj, args)
            arguments
                obj
                args.print = false;
            end
            [accuracy{1}, missed_gest{1}, mean_delay{1}, CM{1}, gest_times_pred{1}] = ...
                obj.train.detect_gestures(print = args.print);
            [accuracy{2}, missed_gest{2}, mean_delay{2}, CM{2}, gest_times_pred{2}] = ...
                obj.val.detect_gestures(print = args.print);
            [accuracy{3}, missed_gest{3}, mean_delay{3}, CM{3}, gest_times_pred{3}] = ...
                obj.test.detect_gestures(print = args.print);
        end

        %% save a model
        function obj = save(obj, path)
            % we save only the names so the saved obj will take less memory
            obj.train = obj.train.Name;
            obj.val = obj.val.Name;
            obj.test = obj.test.Name;
            % save the object under the name 'model'
            S.('model') = obj;
            save(path, "-struct", 'S'); 
        end

        %% retrieving data to loaded objects
        % load data from files - use this if you loaded a saved bci_model to reconstruct its data
        function load_data(obj)
            obj.train = names2paths(obj.train); obj.train = paths2Mrec(obj.train);
            obj.val = names2paths(obj.val); obj.val = paths2Mrec(obj.val);
            obj.test = names2paths(obj.test); obj.test = paths2Mrec(obj.test);
        end

        % get data from givven recordings - use this if you already have
        % the recordings objects (good for CV scripts)
        function get_my_data(obj, recordings)
            train_rec = {}; val_rec = {}; test_rec = {};
            for i = 1:length(recordings)
                if ismember(recordings{i}.Name, obj.train)
                    train_rec{i} = recordings{i};
                elseif ismember(recordings{i}.Name, obj.val)
                    val_rec{i} = recordings{i};
                elseif ismember(recordings{i}.Name, obj.test)
                    test_rec = recordings{i};
                end
            end
            % remove empty indices
            train_rec(cellfun(@isempty,train_rec)) = [];
            val_rec(cellfun(@isempty,val_rec)) = [];
            test_rec(cellfun(@isempty,test_rec)) = [];
            % create multi recording objects
            obj.train = multi_recording(train_rec);
            obj.val = multi_recording(val_rec);
            obj.test = multi_recording(test_rec);
        end 
    end
end