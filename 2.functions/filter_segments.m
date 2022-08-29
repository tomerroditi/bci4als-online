function filt_data = filter_segments(segments, my_pipeline)
% this function is aplying the preprocess filtering phase in the pipeline. 
% It filters the data using BP and notch filters.
%
% Inputs:
%   - segments: a 4D matrix containing the segmented raw data, its
%   dimentions are [electrodes, time, channels, trials].
%   - my_pipeline: a my_pipeline object containing the parameters for preprocessing.
%
% Output:
%   - filt_data: a 4D matrix of the segments after being
%   preproccesed, the dimentions order are the same as in 'segments'

% define some usefull variables
num_trials   = size(segments,4);
num_channels = size(segments,1);

% import some constants for the filters design and filtering 
buff_start   = my_pipeline.buffer_start;
buff_end     = my_pipeline.buffer_end;
Fs           = my_pipeline.sample_rate;
high_freq    = my_pipeline.high_freq;
low_freq     = my_pipeline.low_freq;
high_width   = my_pipeline.high_width;
low_width    = my_pipeline.low_width;
notch_freq   = my_pipeline.notch;
notch_width  = my_pipeline.notch_width;

% implement a bandpass filter and a notch filter.
% we will use IIR filters to get less delay in the online sessions.
persistent BP_filter notch_filter; 

if isempty(BP_filter)
    % design an IIR bandpass filter
    h_bp = fdesign.bandpass('fst1,fp1,fp2,fst2,ast1,ap,ast2', low_freq - low_width, low_freq, ...
    high_freq, high_freq + high_width, 60, 1, 60, Fs);
    
    BP_filter = design(h_bp, 'cheby1', ...
        'MatchExactly', 'passband', ...
        'SOSScaleNorm', 'Linf');
    
    % design an IIR notch filters 
    N  = 6;            % Order
    F0 = notch_freq;   % Center frequencies
    BW = notch_width;  % Bandwidth
    
    notch_filter = cell(length(F0),1);
    for freq = 1:length(F0)
        h = fdesign.notch('N,F0,BW', N, F0(freq), BW, Fs);
        notch_filter{freq} = design(h, 'butter', 'SOSScaleNorm', 'Linf');
    end
end

trial_length = size(segments,2);
filt_data = zeros(num_channels,trial_length - buff_start - buff_end, 1, num_trials);

% filter the data and remove eog artifacts
% NOTICE that there is not difference between cont and disc for now we
% might change it later if needed!
bss_opt.bss_alg = 'iWASOBI';

if strcmp(my_pipeline.cont_or_disc, 'discrete')
    for i = 1:num_trials
        % BP filtering
        temp = filter(BP_filter, squeeze(segments(:,:,:,i)).');
        temp = temp.';
        % notch filtering
        for j = 1:length(notch_filter)
            temp = filter(notch_filter{j}, temp, 2);
        end

        if my_pipeline.eog_artifact
            % eog & emg artifact removal
            [~, temp] = evalc('autobss(temp(:,buff_start + 1:end - buff_end), bss_opt)');
            % allocate the cleared data into the new matrix
            filt_data(:,:,:,i) = temp;
        else
            filt_data(:,:,:,i) = temp(:,buff_start + 1:end - buff_end); % allocate the filtered data into the new matrix
        end
    end
    % re reference
    if my_pipeline.avg_reference
        filt_data = filt_data - mean(filt_data);
    end
elseif strcmp(my_pipeline.cont_or_disc, 'continuous')
    for i = 1:num_trials
        % BP filtering
        temp = filter(BP_filter, squeeze(segments(:,:,:,i)).');
        temp = temp.';
        % notch filtering
        for j = 1:length(notch_filter)
            temp = filter(notch_filter{j}, temp, 2);
        end

        if my_pipeline.eog_artifact
            % eog artifact removal
            [~, temp] = evalc('autobss(temp(:,buff_start + 1:end - buff_end), bss_opt)');
            filt_data(:,:,:,i) = temp; % allocate the cleared data into the new matrix
        else
            filt_data(:,:,:,i) = temp(:,buff_start + 1:end - buff_end); % allocate the filtered data into the new matrix
        end
    end
    % re reference
    if my_pipeline.avg_reference
        filt_data = filt_data - mean(filt_data);
    end
end
end
           