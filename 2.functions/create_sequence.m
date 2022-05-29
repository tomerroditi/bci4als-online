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

% extract some paremeters from options structure
sequence_len = options.sequence_len;          % number of "windows" in each sequence
seg_dur = options.seg_dur;                    % duration of a single "window"
sequence_overlap = options.sequence_overlap;  % overlapping between "windows"
Fs = options.constants.SAMPLE_RATE;           % the hardware sample rate

seq_step_size = floor(seg_dur*Fs - sequence_overlap*Fs);

% if sequence length is 1 then dont perform sequencing!
if sequence_len == 1
    seq_data = squeeze(mat2cell(data, size(data,1), size(data,2), size(data,3), ones(size(data,4),1)));
    return
end

% create the sequences of the eeg recordings
num_of_seg = size(data,4); % number of segments
seq_data = cell(num_of_seg, 1); % initialize an empty cell to contain the sequences

for i = 1:num_of_seg
    temp_data = data(:, 1:seg_dur*Fs ,:,i);
    for j = 1:sequence_len - 1
        temp_data = cat(4,temp_data, data(:, j*seq_step_size:seg_dur*Fs + j*seq_step_size ,:,i));
    end
    seq_data{i} = temp_data;
end
end
