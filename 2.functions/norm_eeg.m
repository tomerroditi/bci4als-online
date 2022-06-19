function norm_seg = norm_eeg(segments, quantiles)
% this function normalize each channel in each segment of the eeg data 
% seperatly according to percentiles of the data
%
% Inputs: 
%   segments: a 5D array containing the data.in the following order of
%             dimentions (channel, time, 1, sequence, examples)
%   quantiles: a vector containing the lower and upper percentiles to
%              normalize the data by (e.g [0.25 0.75])
%
% Outputs:
%   norm_data: a 5D array containing the normalized data in the same
%              dimention order as in 'segments'
%
%

% return empty array if theres no data
if isempty(segments)
    norm_seg = [];
    return
end

% normalize the data - DO NOT use normalization to [0 1] range!
norm_seg = zeros(size(segments)); % preallocate memory
for j = 1:size(segments, 5) % 5th dimention is for trials 
    for i = 1:size(segments, 4) % 4th dimention is for sequence
        for k = 1:size(segments, 3) % 3rd dimention is for "image channels" - supposed to be constant 1
            curr_array = segments(:,:,k,i,j);
            % extract quantiles for each channel in the segment
            Q = quantile(curr_array.', quantiles); 
            Q = Q.';
            % save the normed data
            norm_seg(:,:,k,i,j) = (curr_array - Q(:,1))./(Q(:,2) - Q(:,1));
        end
    end
end
end
