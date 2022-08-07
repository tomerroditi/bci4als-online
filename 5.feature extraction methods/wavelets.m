function [features] = wavelets(segments, my_pipeline)
% This function computes the CWT for each segment in recording
% #### need to add function description ####

% extract relevant variables from recording
Fs = my_pipeline.sample_rate;
low_freq = my_pipeline.low_freq;
high_freq = my_pipeline.high_freq;

% the input size of alexnet
resize_size = [227,227];

% we will use different number of voices per octave according to the number
% of channels available - less channels more voices and vice versa
chan_loc = my_pipeline.electrode_loc;
if length(my_pipeline.electrode_num) == 11
    VoicesPerOctave = 30;
else
    VoicesPerOctave = 20;
end

% continuous wavelet transform - feature extraction
% notice how we are constructing the feature matrix of each segment, we
% concatenate the cwt by the electrodes location,"fc" sites are placed in 
% the front of the head, "c" cites are placed in the middle and "cp" sites
% are in the back. hence we suggest this kind of concatenation.
features = zeros(resize_size(1), resize_size(2), 3,  size(segments,4), size(segments,5));
f = waitbar(0, 'extracting "cwt" features, pls wait'); % initialize a wait bar
for i = 1:size(segments,5)
    waitbar(i/size(segments,5), f, ['extracting "cwt" features, segment ' num2str(i) ' out of ' num2str(size(segments,5))]); % update the wait bar
    temp_seq = [];
    for k = 1:size(segments,4) 
        temp_features_1 = []; temp_features_2 = []; temp_features_3 = [];
        for j = 1:size(segments,1)
            wt = abs(cwt(squeeze(segments(j,:,:,k,i)), FrequencyLimits = [low_freq/Fs high_freq/Fs], VoicesPerOctave = VoicesPerOctave));
            if length(my_pipeline.electrode_num) == 11 % xdf files - 11 electrodes
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
        temp_features_1 = imresize(temp_features_1, resize_size);
        temp_features_2 = imresize(temp_features_2, resize_size);
        temp_features_3 = imresize(temp_features_3, resize_size);

        % rescale the values to match alexnet inputs
        for v = 1:size(temp_features_1, 1)
            temp_features_1(v,:) = rescale(temp_features_1(v,:), 0, 255);
            temp_features_2(v,:) = rescale(temp_features_2(v,:), 0, 255);
            temp_features_3(v,:) = rescale(temp_features_3(v,:), 0, 255);
        end

        % concatenate sequence features
        temp_feat = cat(3, temp_features_1, temp_features_2, temp_features_3); % single trial concat
        temp_seq = cat(4,temp_seq,temp_feat); % sequence concat
    end
    % place current seg feature into features
    features(:,:,:,:,i) = temp_seq; 
end
delete(f) % close the wait bar
end
