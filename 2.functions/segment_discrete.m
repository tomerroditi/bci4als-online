function [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(data, events, post_start, pre_start, constants)

% extract the times events and data from EEGstruc
events = squeeze(struct2cell(events)).';
marker_times = cell2mat(events(:,2));  % note that the time is the number samples
marker_sign = events(:,1);

% define labeling variables
classes_all      = constants.class_names;
classes_use      = constants.class_name_model;
class_label      = constants.class_label;
classes_markers  = num2str(constants.class_marker, '%#.16g');     
start_rec_mark   = num2str(constants.start_recordings, '%#.16g');   % start recording marker
end_rec_mark     = num2str(constants.end_recording, '%#.16g');      % end recording marker
end_trial_mark     = num2str(constants.end_trial, '%#.16g');      % end recording marker

% make some verifications on the markers
start_rec_marker_idx = strcmp(events(:,1), start_rec_mark);
end_rec_marker_idx = strcmp(events(:,1), end_rec_mark);
if sum(start_rec_marker_idx) > 1 || find(start_rec_marker_idx) ~= 1 || sum(end_rec_marker_idx) > 1 || find(end_rec_marker_idx) ~= size(events,1)
    error(['there is a problem in the events structure due to one of the reasons:' newline...
        '1. Start recording marker has been marked more than once.' newline...
        '2. There is more than 1 marker for starting recording' newline...
        '3. End recording marker has been marked more than once.' newline...
        '4. There is more than 1 marker for ending recording' newline...
        'Pls review the events structure to find the problem and fix it'])
end

% define segmentation parameters
buff_start = constants.buffer_start;  % buffer befor the segment
buff_end = constants.buffer_end;      % buffer after the segment
Fs = constants.sample_rate;           % sample rate
seg_post_start = floor(post_start*Fs);% number of time points afetr start marker
seg_pre_start = floor(pre_start*Fs);       % number of time points before start marker

% create a support vector containing the movement class in each timestamp
% and an array of the time every segment ends
sup_vec = zeros(1,size(data,2));
for j = 1:size(data,2)
    last_markers = find(marker_times <= j);
    if isempty(last_markers) % idle before something happens
        sup_vec(j) = 1;
    else % classify according to last marker
        for i = 1:length(classes_use)
            marker_idx = ismember(classes_all, classes_use(i));
            if strcmp(marker_sign{last_markers(end)}, classes_markers(marker_idx,:))
                sup_vec(j) = class_label(i);
            end
        end
    end
    if sup_vec(j) == 0 % if last marker is trail\rec end
        sup_vec(j) = 1;
    end
end

% calculate the time each trial ends in
seg_time_sampled_indices = marker_times(strcmp(marker_sign, end_trial_mark));
times = (0:(size(data,2) - 1))./Fs;
seg_time_sampled = times(seg_time_sampled_indices);

% concat times and supp_vec to connect time pints and their labels
times = [times, ((1:124).*(1./Fs) + times(end))]; % add time points for future concatenating
sup_vec = [sup_vec, zeros(1,124)]; % add zeros for future concatenating
sup_vec = [sup_vec; times];

% get the markers that indicate the trial class and create labels vector
% accordingly
mark = str2double(marker_sign(ismember(marker_sign, mat2cell(classes_markers, ones(size(classes_markers,1),1)))));
labels = zeros(length(mark),1); % labels that remain as 0 will be rejected at the end!
for i = 1:length(mark)
    curr_class = classes_all(classes_markers == mark(i)); % check if we want to take that class
    if ~isempty(curr_class)
        labels(i) = class_label(strcmp(classes_use, curr_class)); % if we do want it label the trial
    end
end

% segment the data 
% filter the data to remove drifts and biases, so we could set a common
% threshold to all recordings for finding corapted segments. we add zeros
% to keep both signals align with each other (the segments are not filtered!)
filtered_data = cat(2,zeros(size(data,1), buff_start), MI3_Preprocess(data, 'discrete', constants));
start_times_indices = marker_times(strcmp(marker_sign, '1111.000000000000'));
segments = [];
for i = 1:length(start_times_indices)
    % reject trials that we cant take due to the buffers (negative or out of range indices)
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

% reject unwanted classes trials
segments(:,:, labels == 0) = [];
seg_time_sampled(labels == 0) = [];
labels(labels == 0) = [];
end

