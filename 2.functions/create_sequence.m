function seq_data = create_sequence(data, options)
% this function creates a sequence of eeg data recordings
%
% Inputs:
%
%
% Outputs:
%
%
%

if isempty(data)
    seq_data = [];
    return
end

% extract some paremeters from options structure
sequence_len = options.sequence_len;          % number of "windows" in each sequence
seg_dur = options.seg_dur;                    % duration of a single "window"
sequence_overlap = options.sequence_overlap;  % overlapping between "windows"
Fs = options.constants.SAMPLE_RATE;           % the hardware sample rate
seg_time = floor(seg_dur*Fs);

seq_step_size = floor(seg_dur*Fs - sequence_overlap*Fs);

% if sequence length is 1 then dont perform sequencing!
if sequence_len == 1
    seq_data = permute(data,[1,2,3,5,4]); % just reorder the dimentions if sequence length is 1
    return
end

% create the sequences of the eeg recordings
num_of_seg = size(data,4); % number of segments
seq_data = zeros(size(data,1), seg_time, size(data,3), sequence_len, num_of_seg); % initialize an empty cell to contain the sequences

for i = 1:num_of_seg
    temp_data = data(:, 1:seg_time,:,i);
    for j = 1:sequence_len - 1
        temp_data = cat(4,temp_data, data(:, (1 + j*seq_step_size):(seg_time + j*seq_step_size),:,i));
    end
    seq_data(:,:,:,:,i) = temp_data;
end
end
