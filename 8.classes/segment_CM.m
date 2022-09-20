classdef segment_CM < handle
    properties
        CM
        order
        true_labels
        pred_labels
        seg_end_idx
    end

    methods
        function obj = segment_CM(true_labels, pred_labels) 
            obj.true_labels = true_labels;
            obj.pred_labels = pred_labels;
            [obj.CM, obj.order] = confusionmat(true_labels, pred_labels);
        end

        function accuracy = get_accuracy(obj)
            accuracy = sum(diag(obj.CM))/sum(obj.CM(:));
        end

        function labels = get_true_labels(obj) % remove idle gestures
            labels = obj.true_labels;
        end

        function labels = get_predicted_labels(obj) % remove idle gestures
            labels = obj.pred_labels;
        end
    
        function plot_CM(obj)
            figure()
            confusionchart(obj.true_labels, obj.pred_labels)
        end
    end
end