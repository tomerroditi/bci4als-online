classdef Gesture_CM < handle
    properties
        CM
        order
        true_gestures
        true_gestures_time
        pred_gestures
        pred_gestures_time
    end

    methods
        function obj = Gesture_CM(true_gestures, true_gestures_time, pred_gestures, pred_gestures_time) 
            [obj.true_gestures, obj.true_gestures_time, obj.pred_gestures, obj.pred_gestures_time] =...
                Gestures_Utils.sync_gestures(true_gestures, true_gestures_time, pred_gestures, pred_gestures_time);

            [obj.CM, obj.order] = confusionmat(obj.true_gestures, obj.pred_gestures);
        end

        function [accuracy, miss_rate] = get_stats(obj)
            % CM should not have any values in the idle-idle slot
            idle_idx = obj.order == 'idle';
            accuracy = sum(diag(obj.CM))/ sum(sum(obj.CM(:,~idle_idx)));
            miss_rate = sum(obj.CM(:, idle_idx))/sum(sum(obj.CM(~idle_idx,~idle_idx)));
        end

        function [gestures, times] = get_true_gestures(obj) % change function name to get_fixed...
            gestures = obj.true_gestures;
            times = obj.true_gestures_time;
        end

        function [gestures, times] = get_predicted_gestures(obj) % change function name to get_fixed...
            gestures = obj.pred_gestures;
            times = obj.pred_gestures_time;
        end
    
        function plot_CM(obj, args)
            arguments
                obj
                args.group = ''
            end
            figure()
            [accuracy, miss_rate] = obj.get_stats();
            title = sprintf(['gestures CM - %s' newline 'accuracy - %.3f, miss rate - %.3f'] ...
                            ,args.group, accuracy, miss_rate);
            confusionchart(obj.true_gestures, obj.pred_gestures, 'Title', title)
        end
    end

end