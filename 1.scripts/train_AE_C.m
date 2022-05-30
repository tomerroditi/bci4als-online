% this script performs data aggregation, data preprocessing and training an
% autoencoder model to validate good recordings, follow the instructions bellow to
% manage the script:
% 
% - change the folders numbers in 'folders_num'
%   to the relevant recordings you intend to use in the pipeline.
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
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
folders_num = {[1 3:12], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);
% apperantly we have one bad recording from tomer, try finding it and delete it
% bad recordings tomer = [2]

%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.cross_rec        = false;        % true - test and train share recordings, false - tests are a different recordings then train
options.feat_or_data     = 'data';       % specify if you desire to extract data or features
options.model_algo       = 'EEGNet';     % ML model to train, choose from {'EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.feat_alg         = 'wavelet';    % feature extraction algorithm, choose from {'basic', 'wavelet'}
options.cont_or_disc     = 'discrete';   % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,0,0];      % resample size for each class [class1, class2, class3]
options.constants        = constants();  % a class member with constants that are used in the pipeline
% discrete only
options.pre_start        = 0.5;          % duration in seconds to include in segments before the start marker
options.post_start       = 3;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 4;            % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 2;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% preprocess the data into train, test and validation sets
recordings = cell(1,length(data_paths));
for i = 1:length(data_paths)
    recordings{i} = recording(data_paths{i}, options); % crete a class member for each path
end
all_rec = multi_recording(recordings); % create a class member from all paths
[train, test, val] = all_rec.train_test_split();

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)
disp('testing data distribution'); tabulate(test.labels)
% resample train set
train_rsmpl = train.rsmpl_data();

%% create a datastore from the data - this is usefull if we want to augment our data while training the NN
% notice that this function uses the normalized segments
train.create_ds();
train_rsmpl.create_ds();
val.create_ds();
test.create_ds();

% add augmentation functions to the train datastore (X flip & random
% gaussian noise) - helps preventing overfitting
train_rsmpl_aug = train_rsmpl.augment();

%% train a model - the 'algo' name will determine which model to train
[AE] = train_my_model(options.model_algo, options.constants, ...
    "train_ds", train_rsmpl_aug.data_store, 'val_ds', val.data_store);
netE = AE(1);
netD = AE(2);

%% visualize the results - lets see the clusters!
all_data = multi_recording({train, val, test});
all_data.create_ds();
all_data.normalize_ds()

% predict the 'features' of each sample
all_data.model_output(netE);

% make clusters
all_data.visualize_output('tsne', 3);


%% save the model and its settings 
EEG_AE.options = options;
EEG_AE.encoder = netE;
EEG_AE.decoder = netD;
uisave('EEG_AE', 'EEG_AE');
