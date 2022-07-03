function flag = check_streamed_signal(inlet, options, constants)


persistent data  
if isempty(data)
    data = [];
end
% collect data from inlet stream
while size(data,2) < constants.sample_rate*5 + constants.buffer_start + constants.buffer_end
    pause(5)
    chunk = inlet.pull_chunk();
    chunk(constants.xdf_removed_chan,:) = [];
    data = cat(2, data, chunk);
end

% take a 5 second piece of data (include buffers for filtering)
segments = data(:,end - constants.sample_rate*5 + constants.buffer_start + constants.buffer_end :end);

% filter the data
segments = filter_segments(segments, options.cont_or_disc, constants);

% create the sequence 
segments = create_sequence(segments, options);

% normalize the data
segments = norm_eeg(segments, constants.quantiles);

% check the data fft
fourier = abs(fft(segments(:,:,1,1,1), [], 2));
freq = linspace(0, constants.sample_rate/2, floor(length(fourier)/2) + 1);
fourier = fourier(:,1:floor(length(fourier)/2) + 1);

% insert here conditions on the FT of the signal
fourier_0_10 = fourier(:,freq <= 10);
fourier_25 = fourier(:, freq >= 24 && freq <= 26);
fourier_32 = fourier(:, freq >= 31.25 && freq <= 33.25);
fourier_50 = fourier(:, freq >= 49 && freq <= 51);

if any(fourier_25 >= 0.08)
    disp('you got too much noise at 25 HZ');
    flag = true;
    return
elseif any(fourier_32 >= 0.08)
    disp('you got too much noise at 32.25 HZ');
    flag = true;
    return
elseif any(fourier_50 >= 0.02)
    disp('you got too much noise at 50 HZ');
    flag = true;
    return
end

% for the 0-10 HZ i want to calculate the statistics of good recordings
% (mean, std, quantiles etc) and use those values to estimate if we are
% recieving a good signal!

% another idea is to measure the distance of the model activation layer
% from the data that the model was trined on, if the distance is larger
% than some value its a good indication for corrupted signal 

flag = false;
end




