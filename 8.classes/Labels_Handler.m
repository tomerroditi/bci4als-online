classdef Labels_Handler < handle
    properties %(Access = protected)
        marker_class_map
        classes
        labels
    end

    methods
        function obj = Labels_Handler(class_names, class_marker)
            obj.classes = unique(class_names);
            obj.marker_class_map = obj.create_marker_class_map(class_marker, class_names);
        end

        function label = get_label_from_marker(obj, marker)
            if isKey(obj.marker_class_map, marker)
                label = obj.marker_class_map(marker);
            else
                label = 'idle';
            end
            label = categorical({label}, obj.classes);
        end

        function reject_indices = reject_marked_labels(obj)
            reject_indices = isundefined(obj.labels);
            obj.labels(reject_indices) = [];
        end

        function set_labels(obj, labels_array)
            obj.labels = categorical(labels_array, obj.classes);
        end

        function labels = get_labels(obj)
            labels = obj.labels;
        end

        function cat_cell = get_cell_of_categorical_labels(obj)
            cat_cell = cell(size(obj.labels));
            for i = 1:length(obj.labels)
                cat_cell{i} = obj.labels(i);
            end
        end

        function reject_by_idx(obj, indices)
            obj.labels(indices) = [];
        end
        
        function append(obj, labels)
            if ~iscolumn(labels)
                labels = labels.';
            end
            obj.labels = cat(1, obj.labels, labels);
        end
    end

    methods (Static, Access = protected)
        function map = create_marker_class_map(markers, classes)
            map = containers.Map('KeyType','char','ValueType','char');
            for i = 1:length(classes)
                if isa(markers{i}, 'char')
                    map(markers{i}) = classes{i};
                else
                    for j = 1:length(markers{i})
                        map(markers{i}{j}) = classes{i};
                    end
                end
            end
        end
    end
end