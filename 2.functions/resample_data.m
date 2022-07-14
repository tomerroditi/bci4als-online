function [data, labels] = resample_data(data, labels, print)
% this function resamples each class by the factors in rsmpl_size. each
% class resample factor is stored in rsmpl_size in the index which is
% equall to the class number.
% Inputs:
%   data: an array containing the data to resample, the kast dimention
%             should be the trails dimentions
%   labels: the true class of the data
%   print: bool, specify if you want to display the new data distribution
%
% Outputs:
%   data: an array containing the resampled data
%   labels: labels of the resampled data
%

% return empty arrays if the input is empty
if isempty(data)
    data = [];
    labels = [];
    return
end

% find the label that apears the most
unique_labels = unique(labels);
most_freq_label = [];
count = 0;
for i = 1:length(unique_labels)
    if sum(labels == unique_labels(i)) > count
        most_freq_label = unique_labels(i);
        count = sum(labels == unique_labels(i));
    end
end

% find each class indices and resample the data - only in the last dimention
S.subs = repmat({':'},1,ndims(data)); S.type = '()';
rsmpl_segments = [];
rsmpl_labels = [];
for i = 1:length(unique_labels)
    curr_label = unique_labels(i);
    S.subs{ndims(data)} = find(~(labels == curr_label));
    curr_seg = subsasgn(data, S, []); % reject all indices of other labels
    ratio = round(sum(labels == most_freq_label)/sum(labels == curr_label)); % ratio to the largest label
    rsmpl_segments = cat(ndims(data), rsmpl_segments, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
    rsmpl_labels = cat(1, rsmpl_labels, ones(size(curr_seg, ndims(data))*(ratio - 1),1).*curr_label);
end


data = cat(ndims(data), data, rsmpl_segments);
labels = cat(1, labels, rsmpl_labels);

if print
    disp('new data distribution');
    tabulate(labels);
end
end