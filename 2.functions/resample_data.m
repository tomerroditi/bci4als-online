function [segments, labels] = resample_data(segments, labels, print)
% this function resamples each class by the factors in rsmpl_size. each
% class resample factor is stored in rsmpl_size in the index which is
% equall to the class number.
% Inputs:
%   segments: a 5D array containing the segmented eeg data
%   labels: the true class of the data
%   rsmpl_size: an array with the resample factors for each class. each
%               class resample factor is stored in the index coresponding to that class
%               number.
%   display: bool, specify if you want to display the new data distribution
%
% Outputs:
%   segments: a 5D array containing the resampled eeg data 
%   labels: labels of the resampled segments
%

% return empty arrays if the input is empty
if isempty(segments)
    segments = [];
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

% find each class indices and resample the data - only in the 5th dimention
rsmpl_segments = [];
rsmpl_labels = [];
for i = 1:length(unique_labels)
    curr_label = unique_labels(i);
    curr_seg = segments(:,:,:,:,labels == curr_label);
    ratio = round(sum(labels == most_freq_label)/sum(labels == curr_label)); % ratio to the largest label
    rsmpl_segments = cat(5, rsmpl_segments, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
    rsmpl_labels = cat(1, rsmpl_labels, ones(size(curr_seg,5)*(ratio - 1),1).*curr_label);
end


segments = cat(5, segments, rsmpl_segments);
labels = cat(1, labels, rsmpl_labels);

if print
    disp('new data distribution');
    tabulate(labels);
end
end