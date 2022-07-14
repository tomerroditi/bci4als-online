function flag = check_streamed_signal(inlet, options, constants)


persistent data  
if isempty(data)
    data = [];
    % collect data from inlet stream
    while size(data,2) < constants.sample_rate*5 + constants.buffer_start + constants.buffer_end
        pause(5)
        chunk = inlet.pull_chunk();
        chunk(constants.xdf_removed_chan,:) = [];
        data = cat(2, data, chunk);
    end
else
    chunk = inlet.pull_chunk();
    chunk(constants.xdf_removed_chan,:) = [];
    data = cat(2, data, chunk);
end

% take a 5 second piece of data (include buffers for filtering)
segments = data(:,end - constants.sample_rate*5 - constants.buffer_start - constants.buffer_end + 1:end);

% filter the data
segments = filter_segments(segments, options.cont_or_disc, constants);

% create the sequence 
segments = create_sequence(segments, options);

% normalize the data
segments = norm_eeg(segments, constants.quantiles);

% check the data fft
fourier = abs(fft(segments(:,:,1,1,1), [], 2))./size(segments, 2);
freq = linspace(0, constants.sample_rate/2, floor(size(fourier, 2)/2) + 1);
fourier = fourier(:,1:floor(size(fourier,2)/2) + 1);

% insert here conditions on the FT of the signal
fourier_0_10 = fourier(:,freq <= 10);
fourier_25 = fourier(:, freq >= 24 & freq <= 26);
fourier_32 = fourier(:, freq >= 31.25 & freq <= 33.25);
fourier_50 = fourier(:, freq >= 49 & freq <= 51);

if any(any(fourier_25 >= 0.1))
    disp('you got too much noise at 25 HZ');
    flag = true;
    figure('Name', 'fft of streamed data');
    plot(freq, fourier); xlabel('frequency [HZ]'); ylabel('amplitude');
    return
elseif any(any(fourier_32 >= 0.1))
    disp('you got too much noise at 32.25 HZ');
    flag = true;
    figure('Name', 'fft of streamed data');
    plot(freq, fourier); xlabel('frequency [HZ]'); ylabel('amplitude');
    return
elseif any(any(fourier_50 >= 0.01))
    disp('you got too much noise at 50 HZ');
    flag = true;
    figure('Name', 'fft of streamed data');
    plot(freq, fourier); xlabel('frequency [HZ]'); ylabel('amplitude');
    return
end

% for the 0-10 HZ i want to calculate the statistics of good recordings
% (mean, std, quantiles etc) and use those values to estimate if we are
% recieving a good signal!

% another idea is to measure the distance of the model activation layer
% from the data that the model was trined on, if the distance is larger
% than some value its a good indication for corrupted signal 
data = data(:,end - constants.sample_rate*5 - constants.buffer_start - constants.buffer_end + 1, end);
flag = false;
end




