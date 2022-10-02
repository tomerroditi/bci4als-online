classdef BCI_Model_CV < handle 
    properties (SetAccess = protected)
        num_folds     % number of folds in the CV partition
        seg_accu = [];        % models accuracies
        gest_accu = [];   % models gestures accuracies
        gest_miss = [];   % models gestures miss rate
        models      % the ML model (probabilistics models only!)
        data_pipeline % the my_pipeline object that was used to create the models
        model_pipeline
        data_base       % multi-recording\names that used to train the model
    end

    methods
        % constructor
        function obj = BCI_Model_CV(data_base, model_pipeline, num_folds)
            if nargin == 2
                num_folds = data_base.num_files();
            end
            obj.num_folds = num_folds;
            obj.data_base = data_base;
            obj.data_pipeline = data_base.get_pipeline();
            obj.model_pipeline = model_pipeline;
            obj.models = cell(num_folds, 1);
            % create a CV partition object
            C = cvpartition(data_base.num_files(), 'KFold', num_folds); % we will use the regresion partition since recordings dont have a class
            for i = 1:num_folds
                % create train and validation data bases
                train = obj.data_base.get_sub_data_base(training(C, i));
                val = obj.data_base.get_sub_data_base(test(C, i));
                % train a model
                model = BCI_Model(train, obj.model_pipeline, val_DB = val);
                
                obj.store_model_performances(model);
                obj.models{i} = model;
            end
        end
        
        %% get a certain model and its recordings
        function model_out = get_model(obj, model_idx)
            % this function is used to get a certain model out of the object
            model_out = obj.models{model_idx};
        end

        %% visualization
        function plot_CV_stats(obj)
            % this function plot the mean accuracies and miss rate
            % of the CV models

            % compute the models mean accuracy (on val DB) and its std 
            mean_accu = mean(obj.seg_accu,2); std_accu = std(obj.seg_accu,[],2);
            mean_gest_accu = mean(obj.gest_accu,2); std_gest_accu = std(obj.gest_accu,[],2);
            mean_gest_miss = mean(obj.gest_miss,2); std_gest_miss = std(obj.gest_miss,[],2);
            % plot the results
            figure('Name', 'model performance');
            subplot(1,3,1)
            bar(categorical({'train', 'test'}), [mean_accu(1), mean_accu(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_accu(1), mean_accu(2)], [std_accu(1), std_accu(2)], LineStyle = 'none', Color = 'black');
            title('segment accuracy');
            subplot(1,3,2)
            bar(categorical({'train', 'test'}), [mean_gest_accu(1), mean_gest_accu(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_gest_accu(1), mean_gest_accu(2)], [std_gest_accu(1), std_gest_accu(2)], LineStyle = 'none', Color = 'black');
            title('gestures accuracy');
            subplot(1,3,3)
            bar(categorical({'train', 'test'}), [mean_gest_miss(1), mean_gest_miss(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_gest_miss(1), mean_gest_miss(2)], [std_gest_miss(1), std_gest_miss(2)], LineStyle = 'none', Color = 'black');
            title('gestures miss rate');
            hold off;
        end
    end

    methods (Access = protected)
        function store_model_performances(obj, model)
            [train, val] = model.get_model_DBs();
            % store model performances
            [train_segment_CM, train_gesture_CM] = model.classify_data_base(train);
            [val_segment_CM, val_gesture_CM] = model.classify_data_base(val);

            train_seg_accuracy = train_segment_CM.get_accuracy();
            val_seg_accuracy = val_segment_CM.get_accuracy();
            [train_gest_accuracy, train_miss_rate] = train_gesture_CM.get_stats();
            [val_gest_accuracy, val_miss_rate] = val_gesture_CM.get_stats();

            obj.seg_accu(:,end + 1) = [train_seg_accuracy; val_seg_accuracy];
            obj.gest_accu(:,end + 1) = [train_gest_accuracy; val_gest_accuracy];
            obj.gest_miss(:,end + 1) = [train_miss_rate; val_miss_rate];
        end
    end
end