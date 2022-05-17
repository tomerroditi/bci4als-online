function [segments, labels, sup_vec, seg_time_sampled] = MI2_SegmentData(EEG_data, EEG_event, labels, cont_or_disc, seg_dur, overlap, thresh, my_constants)
% Segment data using markers
% This function segments the continuous data into trials or epochs creating
% a 3D matrix where dimentions are - [trial, channels, time (data samples)]
%
% Input: 
%   - recordingFolder: a path of the folder containing the EEG.xdf file
%   - cont_or_disc: segmentation type, 'discrete' or 'continuous'
%   - seg_dur: segmentation duration in seconds
%   - overlap: overlap between following segmentations,only relevant if
%   cont_or_disc = 'continuous'
%   - thresh: a threshold to determine the segment class, if the percentage
%   of time point that belong to a single class from the segment is above the
%   threshold percentage then it will obtain that class label
%
% Output: 
%   - segments: a 3D matrix containing segments of the raw data,
%   dimentions are [trial, channels, time (sampled data)]
%   - labels: a label vector coresponding to the trials in segments
%   - sup_vec: a vector containing the class labels of each time point
%   - EEG_chans: a string array containing the names of channels
%


% remove unwanted channels
EEG_data(my_constants.PREPROCESS_BAD_ELECTRODES,:) = [];

% check for inconsistencies in the events data and the labels vector
num_labels = length(labels);   % derive number of trials from training label vector
for i = 1:length(EEG_event)
    if strcmp('1111.000000000000',EEG_event(i).type)  % find trial start marker
        markerIndex(i) = 1;                           % index markers
    else
        markerIndex(i) = 0;
    end
end
markerIndex = find(markerIndex);  % index of each trial start
num_trials = length(markerIndex); % derive number of trials from start markers

if num_trials ~= num_labels       % Check for consistancy across events & trials
    error(['Some form of mis-match between number of recorded and planned trials!' newline...
        'pls check the labels vector and the event data'])
end

% segmentation process
segments = []; sup_vec = []; seg_time_sampled = []; % initialize empty arrays
if strcmp(cont_or_disc, 'discrete')
    [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(EEG_data, EEG_event, seg_dur, my_constants);
elseif strcmp(cont_or_disc, 'continuous')
    [segments, labels, sup_vec, seg_time_sampled] = segment_continouos(EEG_data, EEG_event, seg_dur, overlap, thresh, my_constants);
end
segments = permute(segments, [1,2,4,3]);
end
