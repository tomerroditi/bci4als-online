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
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
% bad recordings from tomer - 2 (not sure why), 7,14 (one of the channels is completly corapted)

% train_folders_num = {[], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], []}; % recordings numbers for train data - make sure that they exist
% val_folders_num =  {[], [], [], [], [], [], [], [], [], [], [], [], [2:5]}; % recordings numbers for validation data- make sure that they exist
% test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_folders_num = {[3:6, 8:10, 12,13], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist
test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_data_paths = create_paths(recorders, train_folders_num);
val_data_paths = create_paths(recorders, val_folders_num);
test_data_paths = create_paths(recorders, test_folders_num);


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
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;            % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 0;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.9;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% preprocess the data into train, test and validation sets
train = paths2Mrec(train_data_paths, options);
val = paths2Mrec(val_data_paths, options);
test = paths2Mrec(test_data_paths, options);

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)
disp('testing data distribution'); tabulate(test.labels)


%% normalize data
train.normalize('all');
val.normalize('all');
test.normalize('all');

% resample train set - this is how we reballance our training distribution
% (mainly for continuous segmentation, when we have lots of idle class)
train_rsmpl = train.rsmpl_data();

%% extract features - determined by options.feat_alg
train.extract_feat();
val.extract_feat();
test.extract_feat();
train_rsmpl.extract_feat();

%% create a datastore for the data - this is usefull if we want to augment our data while training the NN
% you can choose either to create the data store from "feat" or from
% "data", the deafalut value is based on options.feat_or_data variable
train.create_ds();
train_rsmpl.create_ds();
val.create_ds();
test.create_ds();

% add augmentation functions to the train datastore (X flip & random
% gaussian noise) - helps preventing overfitting
train_rsmpl_aug = train_rsmpl.augment();

%% train a model - the 'algo' name will determine which model to train
model = train_my_model(options.model_algo, options.constants, ...
    "train_ds", train_rsmpl_aug.data_store, "val_ds", val.data_store);

%% set working points and evaluate the model on all data stores
[~, thresh] = train.evaluate(model, CM_title = 'train', print = true, criterion = 'accu', criterion_thresh = 1); 
val.evaluate(model, CM_title = 'val', print = true, thres_C1 = thresh); 
test.evaluate(model, CM_title = 'test', print = true, thres_C1 = thresh);

%% visualize the predictions
train.visualize("title", 'train'); 
val.visualize("title", 'val'); 
test.visualize("title", 'test');

%% visualize gesture execution
train.detect_gestures(3, 5, 7, true); 
val.detect_gestures(3, 5, 7, true); 
test.detect_gestures(3, 5, 7, true);

%% save the model its settings and the recordings names that were used to create it
mdl_struct.options = train.options; % save the corected options structure
mdl_struct.model = model;
mdl_struct.test_name = test.Name;
mdl_struct.val_name = val.Name;
mdl_struct.train_name = train.Name;
mdl_struct.thresh = thresh;
mdl_struct.cool_time = [];
mdl_struct.raw_pred_action = [];
uisave('mdl_struct', 'mdl_struct');
