% this script is for statistical analysis of the raw data


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.cross_rec        = false;        % true - test and train share recordings, false - tests are a different recordings then train
options.feat_or_data     = 'data';       % specify if you desire to extract data or features
options.model_algo       = 'EEGNet_lstm';% ML model to train, choose from {'EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.feat_alg         = 'wavelet';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
options.cont_or_disc     = 'discrete'; % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,4,4];      % resample size for each class [class1, class2, class3]
options.constants        = constants();  % a class member with constants that are used in the pipeline
% discrete only
options.pre_start        = 0.5;          % duration in seconds to include in segments before the start marker
options.post_start       = 3;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;            % duration in seconds of following segments overlapping
options.sequence_len     = 3;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 2;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% folders_num = {[], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5]}; % recordings numbers - make sure that they exist
folders_num = {[1:17], [1:5], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);

all_rec = paths2Mrec(data_paths, options); % create a class member from all paths
all_rec.normalize_raw();

%% plots - visualization
figure(1); plot(all_rec.raw_data(1:11,:).'); 
legend({'channel 1','channel 2','channel 3','channel 4','channel 5',...
    'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'})
figure(2); plot(all_rec.normed_raw_data(1:11,:).');
legend({'channel 1','channel 2','channel 3','channel 4','channel 5',...
    'channel 6','channel 7','channel 8','channel 9','channel 10','channel 11'})
