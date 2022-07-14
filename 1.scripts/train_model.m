% this script performs data aggregation, data preprocessing and training a
% model to predict right left or idle, follow the instructions bellow to
% manage the script:
% 
% - change the folders paths in the first section to the relevant 
%   recordings you intend to use to train the model.
% - change the options settings according to the desired pipeline you wish
%   to create.
% - for more changes check the 'constants' class function in 'classes'
%   folder.
% - choose a folder to save your trained model to when the save gui is
%   opened


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup();

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% bad recordings from tomer - 2 (not sure why), 7,14 (one of the channels is completly corapted)

% train_folders_num = {[], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], []}; % recordings numbers for train data - make sure that they exist
% val_folders_num =  {[], [], [], [], [], [], [], [], [], [], [], [], [2:5]}; % recordings numbers for validation data- make sure that they exist
% test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_folders_num = {[3:10, 12:15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist
test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_data_paths = create_paths(recorders, train_folders_num);
val_data_paths = create_paths(recorders, val_folders_num);
test_data_paths = create_paths(recorders, test_folders_num);


%% define the wanted pipeline and data split options
options.model_algo       = 'EEGNet_lstm';    % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.constants        = constants();  % a class member with constants that are used in the pipeline
% features or segments
options.feat_or_data     = 'data';       % specify if you desire to extract data or features, choose from {'data', 'feat'}
options.feat_alg         = 'none';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
% discrete only
options.pre_start        = 0.75;          % duration in seconds to include in segments before the start marker
options.post_start       = 2;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;            % duration in seconds of following segments overlapping
options.sequence_len     = 4;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 3;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.8;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% preprocess the data into train, test and validation sets
train = paths2Mrec(train_data_paths, options);
val = paths2Mrec(val_data_paths, options);
test = paths2Mrec(test_data_paths, options);

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)
disp('testing data distribution'); tabulate(test.labels)

%% train a model - the 'algo' name will determine which model to train
model = bci_model(train, val, test);

%% evaluate the model on all data stores
model.evaluate(print = true); 

%% visualize the predictions
model.visualize(); 

%% visualize gesture execution
model.set_values(5,5,7)
model.detect_gestures(print = true); 

%% save the model its settings and the recordings names that were used to create it
path = uigetdir();
model.save([paths '\model']);
