function ds = set2ds(segments, labels, constants)
% this function creates a data store from a data set
%
% Inputs:
%   - data: a 5D aarray containing the segmented eeg data
%   - labels: a 1D array containing the labels of the segmented eeg data
%
% Outputs:
%   - ds: a data store containing 'data' and 'labels'

if isempty(segments)
    ds = [];
    return 
end

% create cells of the labels - notice we need to feed the datastore with
% categorical instead of numeric labels
if size(labels,1) == 1
    labels = labels.'; % adjust labels dimentions if needed
end
labels = mat2cell(categorical(labels), ones(1,length(labels))); % create a cell array of labels

seg_size = size(segments);
if seg_size(4) == 1 
    segments = permute(segments, [1 2 3 5 4]); % remove dimention 4 if there is no sequence!
    segments = squeeze(mat2cell(segments, seg_size(1), seg_size(2), seg_size(3), ones(seg_size(5),1)));
else
    segments = squeeze(mat2cell(segments, seg_size(1), seg_size(2), seg_size(3), seg_size(4), ones(seg_size(5),1)));
end


% define the datastores and their read size - for best runtime performance 
% configure read size to be the same as the minibatch size of the network
read_size = constants.MiniBatchSize;
ds = arrayDatastore([segments labels], 'ReadSize', read_size, 'IterationDimension', 1, 'OutputType', 'same');
end