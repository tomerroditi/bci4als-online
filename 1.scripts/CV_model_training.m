% this script is used to train a model in a cross validation manner. we
% devide our recordings into a k-fold and compute the mean accuracy and std
% to better conclude how our model performs.
% the process includes data aggregation, data preprocessing and training a
% model to predict right left or idle for each fold.
% follow the instructions bellow to manage the script:
% 
% - change the folder num as you wish (be sure that they exist)
%   to the relevant recordings you intend to use to train the model.
% - change the options settings according to the desired pipeline you wish
%   to create.
% - for more changes check the 'constants' class function in 'classes'
%   folder.
%
% 
%


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to create cv partition from
% bad recordings from tomer - 2 (not sure why),7,14 (one of the channels is completly corapted)
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folder_num = {[1, 3:6, 8:13, 15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist

%% define the wanted pipeline and data split options
options.test_split_ratio = 0.05;         % percent of the data which will go to the test set
options.val_split_ratio  = 0.05;         % percent of the data which will go to the validation set
options.model_algo       = 'EEGNet';    % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.resample         = [0,3,3];      % resample size for each class [class1, class2, class3]
options.constants        = constants();  % a class member with constants that are used in the pipeline
% features or segments
options.feat_or_data     = 'data';       % specify if you desire to extract data or features, choose from {'data', 'feat'}
options.feat_alg         = 'none';    % feature extraction algorithm, choose from {'basic', 'wavelet', 'none'}
% discrete only
options.pre_start        = 0.75;          % duration in seconds to include in segments before the start marker
options.post_start       = 2;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 3;            % duration in seconds of each segment
options.overlap          = 2.5;            % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 0;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% create cv partition from the recordings and train a model for each fold
K = 12; % choose number of k-fold (pay attention to not set K > num recordings)
[train_paths, test_paths] = create_cv_paths(recorders, folder_num, K);
test_accuracy = zeros(K,1);
train_accuracy = zeros(K,1);

for i = 1:K
    %% preprocess the data into train and test sets
    train = paths2Mrec(train_paths{i}, options);
    test = paths2Mrec(test_paths{i}, options);

    %% display current recordings in each set
    disp(['the ' num2str(i) ' fold sets are:']);
    disp('train recordings are:'); disp(sort(train.Name));
    disp('test recordings are:'); disp(sort(test.Name));

    %% check data distribution in each data set
    disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
    disp('testing data distribution'); tabulate(test.labels)

    %% normalize data
    train.normalize('all');
    test.normalize('all');

    % resample train set - this is how we reballance our training distribution
    % (mainly for continuous segmentation, when we have lots of idle class)
    train_rsmpl = train.rsmpl_data();

    %% extract features - determined by options.feat_alg
    train.extract_feat();
    test.extract_feat();
    train_rsmpl.extract_feat();

    %% create a datastore for the data - this is usefull if we want to augment our data while training the NN
    % you can choose either to create the data store from "feat" or from
    % "data", the deafalut value is based on options.feat_or_data variable
    train.create_ds();
    train_rsmpl.create_ds();
    test.create_ds();

    % add augmentation functions to the train datastore (X flip & random
    % gaussian noise) - helps preventing overfitting
    train_rsmpl_aug = train_rsmpl.augment();

    %% train a model - the 'algo' name will determine which model to train
    model = train_my_model(options.model_algo, options.constants, ...
        "train_ds", train_rsmpl_aug.data_store, "val_ds", test.data_store);

    %% set working points (maximize train accuracy - its not the best measurement here) and evaluate the model on all data stores
    [~, thresh, CM_train] = train.evaluate(model, CM_title = 'train', print = true, criterion='accu', criterion_thresh=1); 
    [~,~, CM_test] = test.evaluate(model, CM_title = 'test', print = true, thres_C1 = thresh);

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    test_accuracy(i) = sum(diag(CM_test))/sum(sum(CM_test));

    %% save the model its settings and the recordings names that were used to create it
    mdl_struct.options = train.options; % save the corected options structure
    mdl_struct.model = model;
    mdl_struct.test_name = test.Name;
    mdl_struct.train_name = train.Name;
    mdl_struct.val_name = []; % just to keep the saving structure uniform across all scripts
    mdl_struct.thresh = thresh;
    save([options.constants.root_path '\6.figures and models\EEGNet CV\mdl_struct_'  num2str(i)], 'mdl_struct');
end

%% compute the model mean accuracy and its std
mean_train_accu = mean(train_accuracy);
mean_test_accu = mean(test_accuracy);

std_train_accu = std(train_accuracy);
std_test_accu = std(test_accuracy);

% plot the results
figure('Name', 'model performance');
bar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu], [std_train_accu, std_test_accu], LineStyle = 'none', Color = 'black');

