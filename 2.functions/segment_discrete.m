function [segments, labels, sup_vec, seg_time_sampled] = segment_discrete(data, events, my_pipeline)

% extract the times events and data from EEGstruc
events = squeeze(struct2cell(events)).';
marker_times = cell2mat(events(:,2));  % note that the time is the number samples
marker_sign = events(:,1);

% define labeling variables
classes          = my_pipeline.class_names;
class_label      = my_pipeline.class_label;
class_marker  = my_pipeline.class_marker;     
start_rec_mark   = my_pipeline.start_recordings;   % start recording marker
end_rec_mark     = my_pipeline.end_recording;      % end recording marker
end_trial_mark   = my_pipeline.end_trail;      % end recording marker

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
buff_start = my_pipeline.buffer_start;  % buffer befor the segment
buff_end = my_pipeline.buffer_end;      % buffer after the segment
Fs = my_pipeline.sample_rate;           % sample rate
seg_post_start = floor(my_pipeline.post_start*Fs);% number of time points afetr start marker
seg_pre_start = floor(my_pipeline.pre_start*Fs);       % number of time points before start marker

% create a support vector containing the movement class in each timestamp
% and an array of the time every segment ends
sup_vec = zeros(1,size(data,2));
for j = 1:size(data,2)
    last_markers = find(marker_times <= j);
    sup_vec(j) = 1; % assume its idle, if not it will be replaced
    if ~isempty(last_markers) % idle before something happens
        for k = 1:length(class_marker)
            if ismember(marker_sign{last_markers(end)}, class_marker{k}) % classify according to last marker 
                sup_vec(j) = class_label(k);
                break
            end
        end
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

% segment the data and label it
segments = [];
seg_time_sampled = [];
filtered_data = cat(2,zeros(size(data,1), buff_start), filter_segments(data, my_pipeline));
labels = zeros(length(marker_sign),1); % labels that remain as 0 will be rejected at the end!
for i = 1:size(marker_sign, 1)
    for j = 1:length(class_marker)
        if ismember(marker_sign{i}, class_marker{j})
            labels(i) = class_label(j);
            time = marker_times(i);
            % reject trials that we cant take due to the buffers (negative or out of range indices)
            if time - seg_pre_start - buff_start < 1
                labels(i) = -1;
            elseif time + seg_post_start + buff_end > size(data, 2)
                labels(i) = -1;
            % reject noisy trials (high amplitude)
            elseif max(max(abs(filtered_data(:,time - seg_pre_start  : time + seg_post_start)))) > 100
                labels(i) = -1;
            else
                seg = data(:,time - seg_pre_start - buff_start : time + seg_post_start + buff_end - 2);
                seg_time_sampled(end+1) = time;
                segments = cat(3,segments,seg);
            end
            break
        end
    end
end
% reject unused labels
labels(labels == 0 | labels == -1) = [];
end

