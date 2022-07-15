function features = get_features(recording, feat_alg)
% this function extract features from a givven recording object.
%
% Inputs:
%   - recording - a recording object
%   - feat_alg - the feature algorithm to use for feature extraction.
%   choose on from the following: {'basic', 'wavelet'}
%
% Output:
%   - features - a feature matrix extracted from the raw data

if isempty(recording.segments)
    features = [];
    return
end

% choose the desired feature extraction method based on feat_alg
if strcmp(feat_alg, 'wavelet')
    features = wavelets(recording);
elseif strcmp(feat_alg, 'basic')
    features = MI4_ExtractFeatures(segments);
end

end
