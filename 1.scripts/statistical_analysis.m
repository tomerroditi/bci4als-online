% this script is for statistical analysis of the raw data - this helped me
% make a good and correct normalizations across all recordings and also
% determined if a recording is good enought to use it or reject it.


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.cross_rec        = false;        % true - test and train share recordings, false - tests are a different recordings then train
options.feat_or_data     = 'data';       % specify if you desire to extract data or features
options.model_algo       = 'EEGNet';% ML model to train, choose from {'EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.feat_alg         = 'none';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,0,0];      % resample size for each class [class1, class2, class3]
options.constants        = constants();  % a class member with constants that are used in the pipeline
% discrete only
options.pre_start        = 0.5;          % duration in seconds to include in segments before the start marker
options.post_start       = 3;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;          % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 1;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay', 'itay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% folders_num = {[], [], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5]}; % recordings numbers - make sure that they exist
folders_num = {[], [6, 9, 10], [], [1:2], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
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

% fft - normalized raw data
figure(7); plot(fourier.'); xline(indices_raw);
legend(legend_names); title('fft - normalized raw data');

% fft - normalized filtered raw data
figure(8); plot(fourier_filt.'); xline(indices_filt);
legend(legend_names); title('fft - normalized filtered raw data');






