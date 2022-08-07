function ds = set2ds(segments, labels, my_pipeline)
% this function creates a data store from a data set
%
% Inputs:
%   - segments: a 5D aarray containing the segmented eeg data
%   - labels: a 1D array containing the labels of the segmented eeg data
%   - constants: a constants object
%
% Outputs:
%   - ds: a data store containing 'segments' and 'labels'

if isempty(segments)
    ds = [];
    return 
end

% create cells of the labels - notice we need to feed the datastore with
% categorical instead of numeric labels
labels = addcats(categorical(labels), arrayfun(@num2str, my_pipeline.class_label, 'UniformOutput', false)); % add categories that might be missing
labels = squeeze(num2cell(reordercats(labels), 2));
% create cells of segments
segments = squeeze(num2cell(segments, [1,2,3,4]));

% define the datastores and their read size - for best runtime performance 
% configure read size to be the same as the minibatch size of the network
read_size = my_pipeline.mini_batch_size;
ds = arrayDatastore([segments labels], 'ReadSize', read_size, 'IterationDimension', 1, 'OutputType', 'same');
end