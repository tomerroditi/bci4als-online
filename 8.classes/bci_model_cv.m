classdef bci_model_cv < handle 
    properties (SetAccess = protected)
        k_folds     % number of folds in the CV partition
        accu        % models accuracies
        gest_accu   % models gestures accuracies
        gest_miss   % models gestures miss rate
        delay       % models average delays
        models      % the ML model (probabilistics models only!)
        threshold   % models threshold for idle class classification
        feat_idx    % models used features indices (for feature dependent models)
        my_pipeline % the my_pipeline object that was used to create the models
        conf_level  % models confidence level
        cool_time   % models time to wait before executing another gesture
        train       % multi-recording\names that used to train the model
    end

    methods
        % constructor
        function obj = bci_model_cv(multi_rec, K)
            if nargin == 0
                return
            elseif nargin == 1
                K = multi_rec.num_rec;
            end
            obj.k_folds = K;
            obj.train = multi_rec;
            obj.my_pipeline = multi_rec.my_pipeline;
            obj.models = cell(1,K);
            % create a CV partition object
            C = cvpartition(multi_rec.num_rec, 'KFold', K); % we will use the regresion partition since recordings dont have a class
            for i = 1:K
                % create a data store for each recording in the multi recording
                train = multi_rec.pop_rec(training(C, i));
                val = multi_rec.pop_rec(test(C, i));
                disp('current validation recordings:')
                disp(val.Name)
                % train a model
                model = bci_model(train, val);
                % save each model field values
                obj.threshold(i) = model.threshold;
                obj.feat_idx{i} = model.feat_idx;
                obj.cool_time(i) = model.cool_time;
                obj.conf_level(i) = model.conf_level;
                % compute model accuracies
                [predictions_t, CM_train] = model.classify(train);
                [predictions_v, CM_val] = model.classify(val);
                obj.accu(:,i) = [sum(diag(CM_train))/sum(sum(CM_train)); sum(diag(CM_val))/sum(sum(CM_val))];
                % compute gestures accuracy, miss rate, and delay
                model.find_optimal_values()
                [gest_accu_t, gest_miss_t, delay_t] = model.classify_gestures(train, predictions = predictions_t);
                [gest_accu_v, gest_miss_v, delay_v] = model.classify_gestures(val, predictions = predictions_v);
                obj.gest_accu(:,i) = [gest_accu_t; gest_accu_v];
                obj.gest_miss(:,i) = [gest_miss_t; gest_miss_v];
                obj.delay(:,i) = [delay_t; delay_v];
                obj.models{i} = model.save([]);
            end
        end
        
        %% get a certain model and its recordings
        function model_out = get_model(obj, model_idx)
            % this function is used to get a certain model out of the object
            model = obj.models{model_idx};
            [curr_train, curr_val] = get_model_rec(obj, model_idx);
            model_out = copy(model); % take a copy so the models will remain in their compact form
            model_out.set_train(curr_train);
            model_out.set_val(curr_val);
        end

        function [train, val] = get_model_rec(obj, model_idx)
            % this function extract a specific model's train and val 
            % recordings from the object train multi recording
            % Input:
            %   model_num - the model index in the object model field
            if ~isa(obj.train, 'recording')
                obj.load_data()
            end
            all_names = obj.train.Name;
            train_names = obj.models{model_idx}.train;
            val_names = obj.models{model_idx}.val;
            train_num = ismember(all_names, train_names);
            val_num = ismember(all_names, val_names);
            train = obj.train.pop_rec(train_num);
            val = obj.train.pop_rec(val_num);
        end

        %% visualization
        function plot_means(obj)
            % this function plot the mean accuracies, miss rate and delay
            % of the CV models

            % compute the model mean accuracy and its std
            mean_accu = mean(obj.accu,2); std_accu = std(obj.accu,[],2);
            mean_gest_accu = mean(obj.gest_accu,2); std_gest_accu = std(obj.gest_accu,[],2);
            mean_gest_miss = mean(obj.gest_miss,2); std_gest_miss = std(obj.gest_miss,[],2);
            mean_delay = mean(obj.delay,2); std_delay = std(obj.delay,[],2);
            % plot the results
            figure('Name', 'model performance');
            subplot(2,2,1)
            bar(categorical({'train', 'test'}), [mean_accu(1), mean_accu(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_accu(1), mean_accu(2)], [std_accu(1), std_accu(2)], LineStyle = 'none', Color = 'black');
            title('segment accuracy');
            subplot(2,2,2)
            bar(categorical({'train', 'test'}), [mean_gest_accu(1), mean_gest_accu(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_gest_accu(1), mean_gest_accu(2)], [std_gest_accu(1), std_gest_accu(2)], LineStyle = 'none', Color = 'black');
            title('gestures accuracy');
            subplot(2,2,3)
            bar(categorical({'train', 'test'}), [mean_gest_miss(1), mean_gest_miss(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_gest_miss(1), mean_gest_miss(2)], [std_gest_miss(1), std_gest_miss(2)], LineStyle = 'none', Color = 'black');
            title('gestures miss rate');
            subplot(2,2,4)
            bar(categorical({'train', 'test'}), [mean_delay(1), mean_delay(2)]); hold on;
            errorbar(categorical({'train', 'test'}), [mean_delay(1), mean_delay(2)], [std_delay(1), std_delay(2)], LineStyle = 'none', Color = 'black');
            title('gesture delay');
            hold off;
        end
    end
end