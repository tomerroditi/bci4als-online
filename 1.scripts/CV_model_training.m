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
folder_num = {[3:6, 8:12], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist

reject_class = {};
%% define the wanted pipeline and data split options
options.model_algo       = 'EEGNet';     % ML model to train, choose from {'alexnet','EEG_stft','EEGNet','EEGNet_stft','EEGNet_lstm','EEGNet_bilstm','EEGNet_gru','EEGNet_lstm_stft','EEGNet_bilstm_stft','EEGNet_gru_stft','SVM', 'ADABOOST', 'LDA'}
options.cont_or_disc     = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
options.constants        = constants();  % a class member with constants that are used in the pipeline
% features or segments
options.feat_or_data     = 'data';       % specify if you desire to extract data or features, choose from {'data', 'feat'}
options.feat_alg         = 'none';       % feature extraction algorithm, choose from {'basic', 'wavelet', 'none'}
% discrete only
options.pre_start        = 0.75;         % duration in seconds to include in segments before the start marker
options.post_start       = 2;            % duration in seconds to include in segments after the start marker
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;          % duration in seconds of following segments overlapping
options.sequence_len     = 1;            % number of segments in a sequence (for sequential DL models)
options.sequence_overlap = 0;            % duration in seconds of overlap between following segments in a sequence
options.threshold        = 0.65;         % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% create cv partition from the recordings and train a model for each fold
data_paths = create_paths(recorders, folder_num); % create paths from recorders and folder num
recordings = cell(length(data_paths),1); % initialize an empty cell for the recordings objects
recordings_rsmpl = cell(length(data_paths),1); % initialize an empty cell for the recordings objects
f = waitbar(0, 'creating recordings'); % create a waitbar
for i = 1:length(data_paths)
    waitbar(i/length(data_paths),f,['recording ' num2str(i) ' out of ' num2str(length(data_paths))]); % update waitbar
    rec = recording(data_paths{i}, options); % create the recording object
    rec_rsmpl = rec.complete_pipeline("reject_class", reject_class, "rsmpl", true);
    recordings{i} = rec;
    recordings_rsmpl{i} = rec_rsmpl; 
end
delete(f)

% create a CV partition object, we will use leave one out method
num_fold = length(recordings_rsmpl);
C = cvpartition(num_fold,'KFold', num_fold); % we will use the regresion partition since recordings dont have a class

% initialize some empty matrices
test_accuracy = zeros(num_fold,1); train_accuracy = zeros(num_fold,1);
test_gest_accuracy = zeros(num_fold,1); train_gest_accuracy = zeros(num_fold,1);
test_gest_missed = zeros(num_fold,1); train_gest_missed = zeros(num_fold,1);
test_mean_delay = zeros(num_fold,1); train_mean_delay = zeros(num_fold,1);

for i = 1:num_fold
    %% preprocess the data into train and test sets
    train_rsmpl = multi_recording(recordings_rsmpl(training(C, i)));
    train = multi_recording(recordings(training(C, i)));
    testing = multi_recording(recordings(test(C, i)));

    %% display current recordings in each set
    disp(['the ' num2str(i) ' fold sets are:']);
    disp('train recordings are:'); disp(sort(train_rsmpl.Name));
    disp('test recordings are:'); disp(sort(testing.Name));

    %% check data distribution in each data set
    disp('training data distribution'); tabulate(train_rsmpl.labels)
    disp('testing data distribution'); tabulate(testing.labels)

    %% create a datastore for the data - this is usefull if we want to augment our data while training the NN
    train_rsmpl.create_ds("reject_class", reject_class);
    train.create_ds("reject_class", reject_class);
    testing.create_ds("reject_class", reject_class);

    % add augmentation functions to the train datastore (X flip & random
    % gaussian noise) - helps preventing overfitting
    train_aug = train_rsmpl.augment();

    %% train a model - the 'algo' name will determine which model to train
    model = train_my_model(options.model_algo, options.constants, ...
        "train_ds", train_aug.data_store, "val_ds", testing.data_store);

    %% set working points (maximize train accuracy - its not the best measurement here) and evaluate the model on all data stores
    [~, thresh, CM_train] = train.evaluate(model, CM_title = 'train', print = false, criterion = 'accu', criterion_thresh = 1); 
    [~,~, CM_test] = testing.evaluate(model, CM_title = 'test', print = false, thres_C1 = thresh);

    [train_gest_accuracy(i), train_gest_missed(i), train_mean_delay(i)] = train.detect_gestures(5, 5, 7, false);
    [test_gest_accuracy(i), test_gest_missed(i), test_mean_delay(i)] = testing.detect_gestures(5, 5, 7, false);

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    test_accuracy(i) = sum(diag(CM_test))/sum(sum(CM_test));

    %% save the model its settings and the recordings names that were used to create it
    mdl_struct.options = train.options; % save the corected options structure
    mdl_struct.model = model;
    mdl_struct.test_name = testing.Name;
    mdl_struct.train_name = train.Name;
    mdl_struct.val_name = []; % just to keep the saving structure uniform across all scripts
    mdl_struct.thresh = thresh;
    mdl_struct.cool_time = 5;
    mdl_struct.raw_pred_action = 5;
    save([options.constants.root_path '\6.figures and models\EEGNet CV opt 6\mdl_struct_'  num2str(i)], 'mdl_struct');
end

%% compute the model mean accuracy and its std
mean_train_accu = mean(train_accuracy); std_train_accu = std(train_accuracy);
mean_train_gest_accu = mean(train_gest_accuracy); std_train_gest_accu = std(train_gest_accuracy);
mean_train_gest_miss = mean(train_gest_missed); std_train_gest_miss = std(train_gest_missed);
mean_train_delay = mean(train_mean_delay); std_train_delay = std(train_mean_delay);

mean_test_accu = mean(test_accuracy);std_test_accu = std(test_accuracy);
mean_test_gest_accu = mean(test_gest_accuracy); std_test_gest_accu = std(test_gest_accuracy);
mean_test_gest_miss = mean(test_gest_missed); std_test_gest_miss = std(test_gest_missed);
mean_test_delay = mean(test_mean_delay); std_test_delay = std(test_mean_delay);

% plot the results
figure('Name', 'model performance');
subplot(2,2,1)
bar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu], [std_train_accu, std_test_accu], LineStyle = 'none', Color = 'black');
title('segment accuracy');
subplot(2,2,2)
bar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_test_gest_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_test_gest_accu], [std_train_gest_accu, std_test_gest_accu], LineStyle = 'none', Color = 'black');
title('gestures accuracy');
subplot(2,2,3)
bar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_test_gest_miss]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_test_gest_miss], [std_train_gest_miss, std_test_gest_miss], LineStyle = 'none', Color = 'black');
title('gestures miss rate');
subplot(2,2,4)
bar(categorical({'train', 'test'}), [mean_train_delay, mean_test_delay]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_delay, mean_test_delay], [std_train_delay, std_test_delay], LineStyle = 'none', Color = 'black');
title('gesture delay');
hold off;
