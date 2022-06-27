function [segments, labels] = resample_data(segments, labels, rsmpl_size, display)
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
elseif rsmpl_size == [0 0 0]
    return
end

% find each class indices
class_1 = segments(:,:,:,:,labels == 1);
class_2 = segments(:,:,:,:,labels == 2);
class_3 = segments(:,:,:,:,labels == 3);

% resample the data - only in the 5th dimention
class_1_resampled = repmat(class_1, 1, 1, 1, 1, rsmpl_size(1));
class_2_resampled = repmat(class_2, 1, 1, 1, 1, rsmpl_size(2));
class_3_resampled = repmat(class_3, 1, 1, 1, 1, rsmpl_size(3));

% create the labels for each resampled class
labels_1 = ones(size(class_1_resampled,5),1);
labels_2 = ones(size(class_2_resampled,5),1).*2;
labels_3 = ones(size(class_3_resampled,5),1).*3;

segments = cat(5,segments, class_1_resampled, class_2_resampled, class_3_resampled);
labels = [labels; labels_1; labels_2; labels_3];

if display
    disp('new data distribution');
    tabulate(labels);
end
end