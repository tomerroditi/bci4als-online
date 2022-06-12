function [features] = wavelets(recording)
% This function computes the CWT for each segment in recording
% #### need to add function description ####


segments = recording.segments;
constants = recording.constants;

if strcmp(recording.file_type, 'xdf')
    chan_loc = constants.electrode_loc;
    VoicesPerOctave = 30;
else
    chan_loc = constants.electrode_loc_edf;
    VoicesPerOctave = 20;
end

% continuous wavelet transform - feature extraction
features = [];
for i = 1:size(segments,5)
    temp_seq = [];
    for k = 1:size(segments,4) 
        temp_features_1 = []; temp_features_2 = []; temp_features_3 = [];
        for j = 1:size(segments,1)
            wt = abs(cwt(squeeze(segments(j,:,:,k,i)), FrequencyLimits = [7/125 35/125], VoicesPerOctave = VoicesPerOctave));
            if strcmp(recording.file_type, 'xdf') % xdf files - 11 electrodes
                if ismember(chan_loc(j), {'C3','C4','Cz'})
                    temp_features_1 = cat(1,temp_features_1, wt);
                elseif ismember(chan_loc(j),{'FC1','FC2','FC5','FC6'})
                    temp_features_2 = cat(1,temp_features_2, wt);
                elseif ismember(chan_loc(j),{'CP1','CP2','CP5','CP6'})
                    temp_features_3 = cat(1,temp_features_3, wt);
                end
            else % edf files - 15 electrodes
                if ismember(chan_loc(j), {'C3','C4','Cz','T4','T3'})
                    temp_features_1 = cat(1,temp_features_1,wt);
                elseif ismember(chan_loc(j),{'F7','F8','F3','F4','Fz'})
                    temp_features_2 = cat(1,temp_features_2,wt);
                elseif ismember(chan_loc(j),{'T5','T6','P3','P4','Pz'})
                    temp_features_3 = cat(1,temp_features_3,wt);
                end
            end
        end
        % resize to alexnet input size
        temp_features_1 = imresize(temp_features_1,[227 227]);
        temp_features_2 = imresize(temp_features_2,[227 227]);
        temp_features_3 = imresize(temp_features_3,[227 227]);

        % rescale the values to match alexnet inputs
        temp_features_1 = rescale(temp_features_1, 0, 255);
        temp_features_2 = rescale(temp_features_2, 0, 255);
        temp_features_3 = rescale(temp_features_3, 0, 255);

        % concatenate sequence features
        temp_feat = cat(3, temp_features_1, temp_features_2, temp_features_3); % single trial concat
        temp_seq = cat(4,temp_seq,temp_feat); % sequence concat
    end
    % concatenate trials features
    features = cat(5, features, temp_seq); % trials (batch) concat
end
end
