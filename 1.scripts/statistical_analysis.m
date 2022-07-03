% this script is for statistical analysis of the raw data - this helped me
% make a good and correct normalizations across all recordings and also
% determined if a recording is good enought to use it or reject it.


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% define the wanted pipeline and data split options
options.model_algo       = 'EEGNet';    % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.constants        = constants();  % a class member with constants that are used in the pipeline
% features or segments
options.feat_or_data     = 'data';       % specify if you desire to extract data or features, choose from {'data', 'feat'}
options.feat_alg         = 'none';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
% discrete only
options.pre_start        = 0.75;          % duration in seconds to include in segments before the start marker
options.post_start       = 2;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 2.5;            % duration in seconds of each segment
options.overlap          = 2;            % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 0;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.65;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay', 'itay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% folders_num = {[], [], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5]}; % recordings numbers - make sure that they exist
folders_num = {[11], [], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);

all_rec = paths2Mrec(data_paths, options); % create a class member from all paths

%% plotting flags
raw = 0;
filt_raw = 0;
fft_raw = 0;
fft_filt = 0;

norm_raw = 0;
norm_filt = 0;
norm_fft_raw = 0;
norm_fft_filt = 1;

%% plots - visualization
indices = all_rec.rec_idx;
% create Xline indices to seperate recordings
indices_raw = cellfun(@(X) X(end), indices(:,3), 'UniformOutput', true);
indices_filt = cellfun(@(X) X(end), indices(:,4), 'UniformOutput', true);

legend_names = {'channel 1','channel 2','channel 3','channel 4','channel 5',...
    'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'};

% raw data
if raw
    figure(1); plot(all_rec.raw_data.'); xline(indices_raw);
    legend(legend_names); title('raw data');
end

% filtered raw data
if filt_raw
    figure(2); plot(all_rec.raw_data_filt.'); xline(indices_filt);
    legend(legend_names); title('filtered raw data');
end

fourier = []; fourier_filt = [];
for i = 1:all_rec.num_rec
    fourier = cat(2, fourier, abs(fft(all_rec.raw_data(:,indices{i,3}) - mean(all_rec.raw_data(:,indices{i,3}),2), [], 2)));
    fourier_filt = cat(2, fourier_filt, abs(fft(all_rec.raw_data_filt(:,indices{i,4}) - mean(all_rec.raw_data_filt(:,indices{i,4}),2), [], 2)));
end

if fft_raw
    figure(3); plot(fourier.'); xline(indices_raw);
    legend(legend_names); title('fft - raw data');
end

if fft_filt
    figure(4); plot(fourier_filt.'); xline(indices_filt);
    legend(legend_names); title('fft - filtered raw data');
end


% normalize the data
all_rec.normalize('all');

% normalized raw data
if norm_raw
    figure(5); plot(all_rec.raw_data.'); xline(indices_raw);
    legend(legend_names); title('normalized raw data');
end

% normalized filtered raw data
if norm_filt
    figure(6); plot(all_rec.raw_data_filt.'); xline(indices_filt);
    legend(legend_names); title('normalized filtered raw data');
end

fourier = []; fourier_filt = [];
for i = 1:all_rec.num_rec
    fourier = cat(2, fourier, abs(fft(all_rec.raw_data(:,indices{i,3}), [], 2))./length(all_rec.raw_data(:,indices{i,3})));
    fourier_filt = cat(2, fourier_filt, abs(fft(all_rec.raw_data_filt(:,indices{i,4}), [], 2))./length(all_rec.raw_data_filt(:,indices{i,4})));
end

%% fft - normalized raw data
if norm_fft_raw
    figure('Name', 'fft - normalized raw data'); 
    idx = [1 indices_raw.'];
    for i = 2:length(idx)
        subplot(7,3,i-1);
        plot(linspace(0,125,idx(i) -  idx(i-1) + 1),fourier(:,idx(i-1):idx(i)).');
        xlim([0, 125]);
    end
    legend(legend_names);
end

%% fft - normalized filtered raw data
if norm_fft_filt
    figure('Name', 'fft - normalized filtered raw data'); 
    idx = [1 indices_filt.'];
    for i = 2:length(idx)
        subplot(5,3,i-1);
        dist = floor((idx(i) -  idx(i-1))/2);
        plot(linspace(0,62.5, dist + 1), fourier_filt(:,idx(i-1):idx(i-1) + dist).');
        xlim([0, 62.5]);
    end
    legend(legend_names);
end

%%
s = all_rec.segments(:,:,1,1,10);
freq = linspace(0,62.5, floor(length(s)/2 + 1));
f = fft(s, [], 2);
figure(99)
plot(freq, abs(f(:,1:length(s)/2 + 1).')./size(s,2))

%%
s = all_rec.raw_data(:,2500:3000);
freq = linspace(0,62.5, floor(length(s)/2 + 1));
f = fft(s - mean(s,2), [], 2);
figure(100)
plot(freq, abs(f(:,1:floor(length(s)/2 + 1)).')./size(s,2))

