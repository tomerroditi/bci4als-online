classdef Segment_CM < handle
    properties
        CM
        order
        true_labels
        pred_labels
        seg_end_idx
    end

    methods
        function obj = Segment_CM(true_labels, pred_labels) 
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
    
        function plot_CM(obj, args)
            arguments
                obj
                args.group = ''
            end
            figure()
            accuracy = obj.get_accuracy();
            title = sprintf(['segments CM - %s' newline 'accuray - %.3f'], args.group, accuracy);
            confusionchart(obj.true_labels, obj.pred_labels, 'Title', title)
        end
    end
end