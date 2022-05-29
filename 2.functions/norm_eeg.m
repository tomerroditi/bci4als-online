function norm_data =  norm_eeg(datastore)
% this function normalize the data inside a datastore, use it inside the
% 'transform' function!
%
% Inputs: 
%   datastore: a cell array containing the data in the first column and the
%              labels in the second column.
%
% Outputs:
%   norm_data: a cell array containing the normalized data in the first
%   column and the labels in the second column.
%
%


% seperate data and labels
data = datastore(:,1);
labels = datastore(:,2);

% extract quantiles for each segment
Q = cellfun(@(X) quantile(X, [0.25 0.75], "all"), data, 'UniformOutput', false);

% normalize the data - DO NOT use normalization to [0 1] range!
for i = 1:length(data)
    data{i} = (data{i} - Q{i}(1))./(Q{i}(2) - Q{i}(1));
end

norm_data = [data labels];
end
