function norm_seg = norm_eeg(segments)
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

% normalize the data - DO NOT use normalization to [0 1] range!
for j = 1:size(segments{1}, 1)
    % extract quantiles for each channel in the segment
    Q = cellfun(@(X) quantile(X(j,:), [0.1 0.9], "all"), segments, 'UniformOutput', false); 
    % create a cell for each normed channel
    norm_seg{j} = cellfun(@(X,Y) (X(j,:) - Y(1))./(Y(2) - Y(1)), segments, Q, 'UniformOutput', false);
end

% concatenate the normed channels
for j = 2:size(segments{1}, 1)
    norm_seg{1} = cellfun(@(X,Y) cat(1,X,Y), norm_seg{1}, norm_seg{j}, 'UniformOutput', false);
end

norm_seg = norm_seg{1};
end
