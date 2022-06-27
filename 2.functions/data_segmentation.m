function [segments, labels, sup_vec, seg_time_sampled] = data_segmentation(EEG_data, EEG_event, options)
% Segment data using markers
% This function segments the continuous data into trials or epochs creating
% a 3D matrix where dimentions are - [trial, channels, time (data samples)]
%
% Input: 
%   - EEG_data: a 2D matrix of the raw EEG data recording, first dim is for
%   channels and second one is for time.
%   - EEG_event: a structure containing the events\markers info of the
%   recording.
%   - labels: a vector containing the labels of the EEG data (we use this for
%   validation only).
%   - options: a structure containing the options for the segmentation
%   process (e.g segment duration, labeling threshold etc.)
%
% Output: 
%   - segments: a 4D matrix containing segments of the raw data,
%   dimentions are [electrodes, time, channels, trials]
%   - labels: a label vector coresponding to the trials in segments
%   - sup_vec: a vector containing the class labels of each time point and
%   its time starting from 0
%

% extract variables from options structure
cont_or_disc = options.cont_or_disc;
post_start = options.post_start;
pre_start = options.pre_start;
overlap = options.overlap;
thresh = options.threshold;
sequence_len = options.sequence_len;
seg_dur = options.seg_dur;
sequence_overlap = options.sequence_overlap;
constants = options.constants;

% segmentation process
segments = []; sup_vec = []; seg_time_sampled = []; % initialize empty arrays
if strcmp(cont_or_disc, 'discrete')
    [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(EEG_data, EEG_event, post_start, pre_start, constants);
elseif strcmp(cont_or_disc, 'continuous')
    [segments, labels, sup_vec, seg_time_sampled] = segment_continouos(EEG_data, EEG_event, seg_dur, sequence_len, sequence_overlap, overlap, thresh, constants);
end
segments = permute(segments, [1,2,4,3]); % we add the 4th dimention to be aligned with matlab DL input layer of images
end
