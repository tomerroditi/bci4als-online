classdef gesture_CM < handle
    properties
        CM
        order
        true_gestures
        true_gestures_indices
        pred_gestures
        pred_gestures_indices
    end

    methods
        function obj = gesture_CM(true_gestures, true_gestures_indices, pred_gestures, pred_gestures_indices) 
            obj.true_gestures = true_gestures;
            obj.true_gestures_indices = true_gestures_indices;
            obj.pred_gestures = pred_gestures;
            obj.pred_gestures_indices = pred_gestures_indices;
            [obj.CM, obj.order] = obj.calculate_gesture_CM();
        end

        function [accuracy, miss_rate] = get_stats(obj)
            % CM should not have any values in the idle-idle slot
            idle_idx = obj.order == 'idle';
            accuracy = sum(diag(obj.CM))/ sum(sum(obj.CM(:,~idle_idx)));
            miss_rate = sum(obj.CM(idle_idx,:))/sum(sum(obj.CM(~idle_idx,:)));
        end

        function [gestures, indices] = get_true_gestures(obj)
            gestures = obj.true_gestures;
            indices = obj.true_gestures_indices;
        end

        function [gestures, indices] = get_predicted_gestures(obj)
            gestures = obj.pred_gestures;
            indices = obj.pred_gestures_indices;
        end
    
        function plot_CM(obj)
            confusionchart(obj.true_gestures, obj.pred_gestures)
        end
    end

    methods (Access = protected)
        function [CM, order] = calculate_gesture_CM(obj) 

            max_idx = 3*125; % needs to be sample_rate*sec
            fixed_gesture_pred = [];
            fixed_gesture_pred_indices = [];

            for i = 1:length(obj.true_gestures)
                curr_gest_pred_idx = abs(obj.true_gestures_indices(i) - obj.pred_gestures_indices) <= max_idx;
                positive_indices = find(curr_gest_pred_idx);
                if length(positive_indices) > 1
                    curr_gest_pred_idx(positive_indices(2:end)) = 0;
                end
                if any(curr_gest_pred_idx)
                    fixed_gesture_pred = cat(1, fixed_gesture_pred, obj.pred_gestures(curr_gest_pred_idx));
                    fixed_gesture_pred_indices = cat(1, fixed_gesture_pred_indices, obj.pred_gestures_indices(curr_gest_pred_idx));
                    
                    obj.pred_gestures = obj.pred_gestures(~curr_gest_pred_idx);
                    obj.pred_gestures_indices = obj.pred_gestures_indices(~curr_gest_pred_idx);
                else
                    fixed_gesture_pred = cat(1, fixed_gesture_pred, categorical({'idle'}));
                    fixed_gesture_pred_indices = cat(1, fixed_gesture_pred_indices, obj.true_gestures_indices(i));
                end
            end

            fixed_gesture_pred = cat(1, fixed_gesture_pred, obj.pred_gestures);
            fixed_gesture_pred_indices = cat(1, fixed_gesture_pred_indices, obj.pred_gestures_indices);

            obj.true_gestures = cat(1, obj.true_gestures, categorical(repmat({'idle'}, length(obj.pred_gestures), 1)));
            obj.true_gestures_indices = cat(1, obj.true_gestures_indices, obj.pred_gestures_indices);

            obj.pred_gestures = fixed_gesture_pred;
            obj.pred_gestures_indices = fixed_gesture_pred_indices;

            [CM, order] = confusionmat(obj.true_gestures, obj.pred_gestures);
        end
    end
end