function [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(data, events, post_start, pre_start, constants)

% extract the times events and data from EEGstruc
events = squeeze(struct2cell(events)).';
marker_times = cell2mat(events(:,2));
marker_sign = events(:,1);

% define segmentation parameters
buff_start = constants.buffer_start;  % buffer befor the segment
buff_end = constants.buffer_end;      % buffer after the segment
Fs = constants.sample_rate;           % sample rate
seg_post_start = floor(post_start*Fs);% number of time points afetr start marker
seg_pre_start = floor(pre_start*Fs);       % number of time points before start marker

% create a support vector containing the movement class in each timestamp
% and an array of the time every segment ends
seg_time_sampled_indices = marker_times(strcmp(marker_sign, '9.000000000000000'));
times = (0:(size(data,2) - 1))./Fs;
seg_time_sampled = times(seg_time_sampled_indices);
sup_vec = zeros(1,length(times));
for j = 1:length(times)
    last_markers = find(marker_times <= j);
    if isempty(last_markers)
        sup_vec(j) = 1;
    elseif strcmp(marker_sign{last_markers(end)}, '2.000000000000000')
        sup_vec(j) = 2;
    elseif strcmp(marker_sign{last_markers(end)}, '3.000000000000000')
        sup_vec(j) = 3;
    else
        sup_vec(j) = 1;
    end
end
times = [times, ((1:124).*(1./Fs) + times(end))]; % add time points for future concatenating
sup_vec = [sup_vec, zeros(1,124)]; % add zeros for future concatenating
sup_vec = [sup_vec; times];

% get the labels
labels = str2double(marker_sign(strcmp(marker_sign, '3.000000000000000') | ...
    strcmp(marker_sign, '2.000000000000000') | strcmp(marker_sign, '1.000000000000000'))); 

% segment the data 
% filter the data to remove drifts and biases, so we could set a common
% threshold to all recordings for finding corapted segments. we add zeros
% to keep both signals align with each other (the segments are not filtered!)
filtered_data = cat(2,zeros(size(data,1), buff_start), MI3_Preprocess(data, 'discrete', constants));
start_times_indices = marker_times(strcmp(marker_sign, '1111.000000000000'));
segments = [];
for i = 1:length(start_times_indices)
    if start_times_indices(i) - seg_pre_start - buff_start < 1
        labels(i) = -1;
    elseif start_times_indices(i) + seg_post_start + buff_end > size(data, 2)
        labels(i) = -1;
    % reject noisy trials (high amplitude)
    elseif max(max(abs(filtered_data(:,start_times_indices(i) - seg_pre_start  : start_times_indices(i) + seg_post_start)))) > 100
        labels(i) = -1;
    else
        seg = data(:,start_times_indices(i) - seg_pre_start - buff_start : start_times_indices(i) + seg_post_start + buff_end - 2);
        segments = cat(3,segments,seg);
    end
end
seg_time_sampled(labels == -1) = []; % delete unused trials sampling times
labels(labels == -1) = []; % delete unused trials labels
end

