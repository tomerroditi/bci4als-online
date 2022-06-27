function [class_label, class_name] = fix_class(class_label, class_name)
% this function...
%
% Inputs:
%
%
% Outputs:
%
%

new_labels = unique(class_label);
new_name = cell(length(new_labels), 1); % initialize new cell to store new class names
for i = 1:length(new_labels)
    new_name{i} = strjoin(class_name(new_labels(i) == class_label), ' + '); % concat joint class names
end

[class_label, idx] = sort(new_labels); % replace old labels with new sorted labels
class_name = new_name(idx);            % replace old names with new names

end