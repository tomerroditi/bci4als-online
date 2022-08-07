function [data, segments, labels, sup_vec, seg_time_sampled] = segment_continouos(data, events, my_pipeline)
% this function creates a continouos segmentation of the raw data
% Input:
%   data: a 2D matrix containing the raw data from the EEG recording.
%   events: a structure containing the info about the events/markers of the
%           EEG recording.
%   my_pipeline: a my_pipeline object with the segmentation parameters
%
% Output:
%   data: a 2D matrix containing the raw data from the EEG recording
%         without the data before the start marker and after the end marker
%   segments: a 3D matrix of the segmented data, dimentions are -
%             [channels, time (sampled data), trials (batch)].
%   labels: labels vector for the segmented data
%   sup_vec: a vector of indications of the class presented in each
%            timestemp
%

start_buff       = my_pipeline.buffer_start;
end_buff         = my_pipeline.buffer_end;
class_label      = my_pipeline.class_label;
class_marker     = my_pipeline.class_marker;     
start_rec_mark   = my_pipeline.start_recordings;   % start recording marker
end_rec_mark     = my_pipeline.end_recording;      % end recording marker
segment_duration = my_pipeline.seg_dur;
sequence_len     = my_pipeline.sequence_len;
sequence_overlap = my_pipeline.sequence_overlap;
overlap_duration = my_pipeline.overlap;
class_thres      = my_pipeline.threshold;
 
% extract the times events and data from EEGstruc
events = squeeze(struct2cell(events)).';
marker_times = cell2mat(events(:,2));    % note that the time is the number of sampled values till the marker
marker_sign = events(:,1);

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

% reject data before\after expirement starts\ends
start_time = marker_times(start_rec_marker_idx);
end_time = marker_times(end_rec_marker_idx);
data = data(:, start_time:end_time); % remove data
marker_times = marker_times - start_time + 1; % adjust the marker times 

% define segmentation parameters
Fs = my_pipeline.sample_rate;          % sample rate
seq_step_size = floor(segment_duration*Fs - sequence_overlap*Fs);
segment_size = floor(segment_duration*Fs + start_buff + end_buff + seq_step_size*(sequence_len - 1));      % segments size
overlap_size = floor(overlap_duration*Fs +start_buff + end_buff + seq_step_size*(sequence_len - 1));      % overlap between every 2 segments
step_size = segment_size - overlap_size; % step size between 2 segments

% initialize empty segments matrix and labels vector
num_segments = floor((size(data,2) - segment_size - Fs*2)/step_size) + 1; 
num_channels = size(data,1);
segments = zeros(num_channels, segment_size, num_segments);
labels = zeros(num_segments, 1);

% create a support vector containing the movement class in each timestamp
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

% segment the data and create a new labels vector.
% filter the data to remove drifts and biases, so we could set a common
% threshold to all recordings for finding corapted segments. we add zeros
% to keep both signals align with each other (the segments are not filtered!)
filtered_data = cat(2,zeros(size(data,1), start_buff), filter_segments(data, my_pipeline));
times = (0:(size(data,2) - 1))./Fs;
seg_time_sampled = zeros(1,num_segments);
start_idx = 1;
for i = 1:num_segments
    % create the ith segment
    seg_idx = (start_idx : start_idx + segment_size - 1); % data indices to segment
    segments(:,:,i) = data(:,seg_idx); % enter the current segment into segments
    start_idx = start_idx + step_size; % add step size to the starting index

    % track time stamps of the end of segments
    seg_time_sampled(i) = times(seg_idx(end) - end_buff);

    % find noisy segments - high amplitude or abnormalities in frequency domain
    if max(max(abs(filtered_data(:,seg_idx(1) + start_buff - Fs*5: seg_idx(end) - end_buff + Fs*2)))) > 100
        labels(i) = -1;
        % some code to help validate the rejected segments - remove "%"
        % mark and place a pause on the 'continue' line
%         subplot(3,1,1)
%         plot(filtered_data(:,seg_idx(1) + start_buff: seg_idx(end) - end_buff).'); title('rejected segment');
%         subplot(3,1,2)
%         plot(filtered_data(:,seg_idx(1) + start_buff - Fs*5: seg_idx(end) - end_buff + Fs*2).'); title('zoom out from the segment, area for checking abnormalities');
%         xline([Fs*5, Fs*5 + length(seg_idx(1) + start_buff: seg_idx(end) - end_buff)]);
%         subplot(3,1,3)
%         plot(filtered_data.'); title('complete recording');
%         xline([seg_idx(1) + start_buff - Fs*5,seg_idx(end) - end_buff + Fs*2])
        continue
    else
        [max_values, max_indices] = max(abs(filtered_data(:,seg_idx(1) + start_buff - Fs*5: seg_idx(end) - end_buff + Fs*2)), [], 2);
        [~, max_idx] = max(max_values);
        idx = max_indices(max_idx) + seg_idx(1) + start_buff - Fs*5 - 1;
        if idx + 10 > size(filtered_data, 2)
            max_values = max(abs(filtered_data(:,idx - 10:end)), [], 2);
        elseif idx - 10 < 1
            max_values = max(abs(filtered_data(:,1:idx + 10)), [], 2);
        else
            max_values = max(abs(filtered_data(:,idx - 10:idx + 10)), [], 2);
        end
        max_values = sort(max_values, "descend");
        if any(max_values(1:end-1) - max_values(2:end) > 20)
            labels(i) = -1;
        % some code to help validate the rejected segments - remove "%"
        % mark and place a pause on the 'continue' line
%             subplot(3,1,1)
%             plot(filtered_data(:,seg_idx(1) + start_buff: seg_idx(end) - end_buff).'); title('rejected segment');
%             subplot(3,1,2)
%             plot(filtered_data(:,seg_idx(1) + start_buff - Fs*5: seg_idx(end) - end_buff + Fs*2).'); title('zoom out from the segment, area for checking abnormalities');
%             xline([Fs*5, Fs*5 + length(seg_idx(1) + start_buff: seg_idx(end) - end_buff)]);
%             subplot(3,1,3)
%             plot(filtered_data.'); title('complete recording')
%             xline([seg_idx(1) + start_buff - Fs*5,seg_idx(end) - end_buff + Fs*2])
            continue
        end
    end

    % find the ith label
    tags = sup_vec(seg_idx);
    tags = tags(start_buff + seq_step_size*(sequence_len - 1) + 1: end - end_buff); % consider only the time stamps of the last sequence
    for j = 1:length(class_label)
        curr_label = class_label(j);
        class_percent = sum(tags == curr_label);
        if class_percent >= length(tags)*class_thres 
            labels(i) = curr_label;
            break
        end
    end
    
    if labels(i) == 0 % no label has been given yet
        labels(i) = 1;
    end
end
sup_vec(seg_idx(end) - end_buff + 1:end) = []; % trim unused labels in the support vector
times(seg_idx(end) - end_buff + 1:end) = []; % trim unused times
times = [times, ((1:(step_size - 1)).*(1./Fs) + times(end))]; % add time points for future concatenating
sup_vec = [sup_vec, zeros(1,step_size - 1)]; % add zeros for future concatenating
sup_vec = [sup_vec; times];

% reject noisy segments - high amplitude
seg_time_sampled(labels == -1) = [];
segments(:,:,labels == -1) = [];
labels(labels == -1) = [];
end