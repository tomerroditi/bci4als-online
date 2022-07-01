% this script is for statistical analysis of the raw data - this helped me
% make a good and correct normalizations across all recordings and also
% determined if a recording is good enought to use it or reject it.


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% define the wanted pipeline and data split options
options.model_algo       = 'EEGNet';    % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,0,0];      % resample size for each class [class1, class2, class3]
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
% bad recordings from tomer - 1 (not sure why),2 (effective sample rate is ~90 instead of 125), 8(noise around 31.25 HZ)
% 7,14 (one of the channels is completly corapted), 15 (one channel has low
% amp in low freq)

recorders = {'tomer', 'omri', 'nitay', 'itay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% folders_num = {[], [], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5]}; % recordings numbers - make sure that they exist
folders_num = {[1:15], [], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);

all_rec = paths2Mrec(data_paths, options); % create a class member from all paths

%% plots - visualization
indices = all_rec.rec_idx;
% create Xline indices to seperate recordings
for i = 1:all_rec.num_rec
    indices_raw(i) = indices{i,3}(end);
    indices_filt(i) = indices{i,4}(end);
end
legend_names = {'channel 1','channel 2','channel 3','channel 4','channel 5',...
    'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'};

% raw data
figure(1); plot(all_rec.raw_data.'); xline(indices_raw);
legend(legend_names); title('raw data');

% filtered raw data
figure(2); plot(all_rec.raw_data_filt.'); xline(indices_filt);
legend(legend_names); title('filtered raw data');

fourier = []; fourier_filt = [];
for i = 1:all_rec.num_rec
    fourier = cat(2, fourier, abs(fft(all_rec.raw_data(:,indices{i,3}) - mean(all_rec.raw_data(:,indices{i,3}),2), [], 2)));
    fourier_filt = cat(2, fourier_filt, abs(fft(all_rec.raw_data_filt(:,indices{i,4}) - mean(all_rec.raw_data_filt(:,indices{i,4}),2), [], 2)));
end

figure(3); plot(fourier.'); xline(indices_raw);
legend(legend_names); title('fft - raw data');

figure(4); plot(fourier_filt.'); xline(indices_filt);
legend(legend_names); title('fft - filtered raw data');



% normalize the data
all_rec.normalize('all');

% normalized raw data
figure(5); plot(all_rec.raw_data.'); xline(indices_raw);
legend(legend_names); title('normalized raw data');

% normalized filtered raw data
figure(6); plot(all_rec.raw_data_filt.'); xline(indices_filt);
legend(legend_names); title('normalized filtered raw data');

fourier = []; fourier_filt = [];
for i = 1:all_rec.num_rec
    fourier = cat(2, fourier, abs(fft(all_rec.raw_data(:,indices{i,3}) - mean(all_rec.raw_data(:,indices{i,3}),2), [], 2)));
    fourier_filt = cat(2, fourier_filt, abs(fft(all_rec.raw_data_filt(:,indices{i,4}) - mean(all_rec.raw_data_filt(:,indices{i,4}),2), [], 2)));
end

%% fft - normalized raw data
figure('Name', 'fft - normalized raw data'); 
idx = [1 indices_raw];
for i = 2:length(idx)
    subplot(7,3,i-1);
    plot(linspace(0,125,idx(i) -  idx(i-1) + 1),fourier(:,idx(i-1):idx(i)).');
    xlim([0, 125]);
end
legend(legend_names);

%% fft - normalized filtered raw data
figure('Name', 'fft - normalized filtered raw data'); 
idx = [1 indices_filt];
for i = 2:length(idx)
    subplot(5,3,i-1);
    dist = floor((idx(i) -  idx(i-1))/2);
    plot(linspace(0,62.5, dist + 1), fourier_filt(:,idx(i-1):idx(i-1) + dist).');
    xlim([0, 62.5]);
end
legend(legend_names);



