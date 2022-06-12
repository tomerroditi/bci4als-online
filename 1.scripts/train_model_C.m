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
% folders_num = {[1:17], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
folders_num = {[], [], [], [2:5], [2:5], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);

%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.cross_rec        = false;        % true - test and train share recordings, false - tests are a different recordings then train
options.feat_or_data     = 'feat';       % specify if you desire to extract data or features
options.model_algo       = 'alexnet';     % ML model to train, choose from {'EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.feat_alg         = 'wavelet';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
options.cont_or_disc     = 'discrete';   % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,0,0];      % resample size for each class [class1, class2, class3]
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


%% preprocess the data into train, test and validation sets
all_rec = paths2Mrec(data_paths, options); % create a class member from all paths
[train, test, val] = all_rec.train_test_split(); % create class member for each set
% display the names of test and val set
disp('test recordings are:')
disp(test.Name);
disp('val recordings are:')
disp(val.Name);

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)
disp('testing data distribution'); tabulate(test.labels)

% resample train set - this is how we reballance our training distribution
train_rsmpl = train.rsmpl_data();


%% create a datastore for the data - this is usefull if we want to augment our data while training the NN
% normalize all data sets
% train.normalize_seg();
% train_rsmpl.normalize_seg();
% val.normalize_seg();
% test.normalize_seg();

% create the data store
train.create_ds('features');
train_rsmpl.create_ds('features');
val.create_ds('features');
test.create_ds('features');

% add augmentation functions to the train datastore (X flip & random
% gaussian noise) - helps preventing overfitting
% train_rsmpl_aug = train_rsmpl.augment();

%% train a model - the 'algo' name will determine which model to train
model = train_my_model(options.model_algo, options.constants, ...
    "train_ds", train_rsmpl.data_store, "val_ds", val.data_store);

%% set working points and evaluate the model on all data stores
test.evaluate(model, CM_title = 'test', print = true);
val.evaluate(model, CM_title = 'val', print = true);
train.evaluate(model, CM_title = 'train', print = true);

%% visualize the predictions - mainly for continuous segmentation
train.visualize("title", 'train'); 
val.visualize("title", 'val'); 
test.visualize("title", 'test');

%% save the model and its settings and the recordings names that were used to create it
mdl_struct.options = options;
mdl_struct.model = model;
mdl_struct.test_name = test.Name;
mdl_struct.val_name = val.Name;
mdl_struct.train_name = train.Name;
uisave('mdl_struct', 'mdl_struct');




