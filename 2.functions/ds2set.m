function [data, labels] = ds2set(ds)
% this function turns a data store back into a data set
%
% Inputs:
%   ds: a data store containing the data in the first column and labels in
%       the sceond one
%
% Outputs:
%   data: an array containing the data (features)
%   labels: an array containing the labels of the data
%


% extract the features and labels from the data stores
data_labels = readall(ds); 
data = data_labels(:,1); 
labels = data_labels(:,2);

% convert features and labels from cell arrays into numerical arrays 
data = cell2mat(data); 
labels = cellfun(@(X) double(X), labels, 'UniformOutput', true);

end
