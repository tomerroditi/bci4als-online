function Selected_Idx = feature_selection(feat, labels)
% this is the feature selection process in the pipeline
%
% Input:
%
% Output:
%
%


% ###### need to change and improve the feature selection process #######


class = fscnca(feat, labels); % feature selection

% sorting the weights in desending order and keeping the indexs
[~, selected] = sort(class.FeatureWeights,'descend');
Selected_Idx = selected(1:Configuration.FE_N);

end


