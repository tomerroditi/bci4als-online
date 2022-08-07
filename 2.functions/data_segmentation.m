function [EEG_data, segments, labels, sup_vec, seg_time_sampled] = data_segmentation(EEG_data, EEG_event, my_pipeline)
% Segment data using markers
% This function segments the continuous data into trials or epochs creating
% a 3D matrix where dimentions are - [trial, channels, time (data samples)]
%
% Input: 
%   - EEG_data: a 2D matrix of the raw EEG data recording, first dim is for
%   channels and second one is for time.
%   - EEG_event: a structure containing the events\markers info of the
%   recording.
%   - my_pipeline: a my_pipeline object with the segmentation parameters
%
% Output: 
%   - EEG_data: a 2D matrix containing the raw data from the EEG recording
%         without the data before the start marker and after the end marker
%   - segments: a 4D matrix containing segments of the raw data,
%   dimentions are [electrodes, time, channels, trials]
%   - labels: a label vector coresponding to the trials in segments
%   - sup_vec: a vector containing the class labels of each time point and
%   its time starting from 0
%

if strcmp(my_pipeline.cont_or_disc, 'discrete')
    [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(EEG_data, EEG_event, my_pipeline);
elseif strcmp(my_pipeline.cont_or_disc, 'continuous')
    [EEG_data, segments, labels, sup_vec, seg_time_sampled] = segment_continouos(EEG_data, EEG_event, my_pipeline);
else
    error('unsuported values for "cont_or_disc" property in the "my_pipeline" object');
end
segments = permute(segments, [1,2,4,3]); % we add the 4th dimention to be aligned with matlab DL input layer of images
end