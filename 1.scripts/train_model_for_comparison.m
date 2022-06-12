% this script performs data aggregation, data preprocessing and training a
% model to predict right left or idle, follow the instructions bellow to
% manage the script:
% 
% - change the folders paths in 'data_paths'
%   to the relevant recordings you intend to use to train the model.
% - change the options settings according to the desired pipeline you wish
%   to create.
% - for more changes check the 'Configuration' class function in 'Common'
%   folder.
%
% Notes:
%   notice the path of eeglab package in the begining of the script,
%   change it as you wish to match the path it is stored in your PC. 
%

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings

% train_folders_num = {[], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], []}; % recordings numbers for train data - make sure that they exist
% val_folders_num =  {[], [], [], [], [], [], [], [], [], [], [], [], [2:5]}; % recordings numbers for validation data- make sure that they exist
% test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_folders_num = {[1:6, 9:10, 12, 13, 15:17], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist
test_folders_num = {[], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for test data - make sure that they exist

train_data_paths = create_paths(recorders, train_folders_num);
val_data_paths = create_paths(recorders, val_folders_num);
test_data_paths = create_paths(recorders, test_folders_num);


%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.cross_rec        = false;        % true - test and train share recordings, false - tests are a different recordings then train
options.feat_or_data     = 'data';       % specify if you desire to extract data or features, choose from {'data', 'feat'}
options.model_algo       = 'EEG_stft';   % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.feat_alg         = 'none';       % feature extraction algorithm, choose from {'basic', 'wavelet'}
options.cont_or_disc     = 'discrete';   % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,0,0];      % resample size for each class [class1, class2, class3]
options.constants        = constants();  % a class member with constants that are used in the pipeline
% discrete only
options.pre_start        = 1;          % duration in seconds to include in segments before the start marker
options.post_start       = 2;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;            % duration in seconds of following segments overlapping
options.sequence_len     = 3;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 2;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

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
% choose either to create the data store from "segments" or from "features"
train.create_ds('segments');
train_rsmpl.create_ds('segments');
val.create_ds('segments');
test.create_ds('segments');

% add augmentation functions to the train datastore (X flip & random
% gaussian noise) - helps preventing overfitting
train_rsmpl_aug = train_rsmpl.augment();

%% train a model - the 'algo' name will determine which model to train
model = train_my_model(options.model_algo, options.constants, ...
    "train_ds", train_rsmpl_aug.data_store, "val_ds", val.data_store);

%% set working points and evaluate the model on all data stores
[~, thresh] = test.evaluate(model, CM_title = 'test', print = true);
val.evaluate(model, CM_title = 'val', print = true);
train.evaluate(model, CM_title = 'train', print = true);

%% visualize the predictions
train.visualize("title", 'train'); 
val.visualize("title", 'val'); 
test.visualize("title", 'test');

%% save the model its settings and the recordings names that were used to create it
mdl_struct.options = options;
mdl_struct.model = model;
mdl_struct.test_names = test.Name;
mdl_struct.val_name = val.Name;
mdl_struct.train_name = train.Name;
uisave('mdl_struct', 'mdl_struct');
