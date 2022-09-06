function seq_data = create_sequence(segments, my_pipeline)
% this function creates a sequence of eeg data recordings
%
% Inputs:
%
%
% Outputs:
%
%
%

if isempty(segments)
    seq_data = [];
    return
end

% extract some paremeters from options structure
sequence_len = my_pipeline.sequence_len;          % number of "windows" in each sequence
seg_dur = my_pipeline.segment_duration_sec;                    % duration of a single "window"
seq_step_size = my_pipeline.sequence_step_size;
Fs = my_pipeline.sample_rate;           % the hardware sample rate
seg_time = floor(seg_dur*Fs);

% if sequence length is 1 then dont perform sequencing!
if sequence_len == 1
    seq_data = permute(segments,[1,2,3,5,4]); % just reorder the dimentions if sequence length is 1
    return
end

% create the sequences of the eeg recordings
num_of_seg = size(segments,4); % number of segments
seq_data = zeros(size(segments,1), seg_time, size(segments,3), sequence_len, num_of_seg); % initialize an empty cell to contain the sequences

for i = 1:num_of_seg
    temp_data = segments(:, 1:seg_time,:,i);
    for j = 1:sequence_len - 1
        temp_data = cat(4,temp_data, segments(:, (1 + j*seq_step_size):(seg_time + j*seq_step_size),:,i));
    end
    seq_data(:,:,:,:,i) = temp_data;
end
end
