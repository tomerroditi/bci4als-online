% this script finds the best preproccesing parameters for a given model.
% just supply a desired range of values for each parameter and run the 
% script, it will return the best set of parameters.
% the model is trained with the same train, val and test sets each time but
% with different parameters set.
% the script saves every trained model with its accuracy on each set
% (predictions are done by the default classification function of the
% model).
% you can then choose between models with best performances and change their
% classification function (based on the scores of the model) to fit your
% needs.

% #### need to improve and change ####
% - create a custom training loop for the model, the value of the
% parameters 'ValidationFrequency', 'ValidationPatience',
% 'LearnRateDropPeriod' should consider the data_store size instead of
% being a constant size.
% - need to figure out how to use the parfor 

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
folders_num = {[1:12], [], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);
% apperantly we have bad recordings from tomer
% currently bad recordings from tomer: [1,2] 

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

%% create all the desired options for training 
seg_dur = [2.5, 3, 3.5, 4, 4.5, 5];
not_overlaped = [0.5, 1, 1.5, 2];
threshold = [0.6, 0.7, 0.75, 0.8, 0.9];
sequence_len = [3, 4, 5, 6, 7, 8];

options_set = cell(1,length(seg_dur)*length(not_overlaped)*length(threshold)*length(sequence_len));
counter = 0; % define a counter variable
for i = 1:length(seg_dur)
    options.seg_dur = seg_dur(i);
    for j = 1:length(not_overlaped)
        options.overlap = seg_dur(i) - not_overlaped(j);
        for k = 1:length(threshold)
            options.threshold = threshold(k);
            for l = 1:length(sequence_len)
                options.sequence_len = sequence_len(l);
                counter = counter + 1; % update the counter
                options_set(counter) = options; % save the current options structure
            end
        end
    end
end

%% train models with different options
models = cell(5,length(options));
parfor k = 1:length(options_set) %####### need to figure out how to use the parfor #######
    options = options_set{k};
    
    % preprocess the data into train, test and validation sets
    recordings = cell(1,length(data_paths));
    for i = 1:length(data_paths)
        recordings{i} = recording(data_paths{i}, options); % crete a class member for each path
    end
    all_rec = multi_recording(recordings); % create a class member from all paths
    [train, test, val] = all_rec.train_test_split(); % create class member for each set - we might want to create a constant devision, hence this needs to be changed!
    
    % check data distribution in each data set
    train_distr = tabulate(train.labels);
    ratio_1_2 = train_distr(1)/train_distr(2);
    ratio_1_3 = train_distr(1)/train_distr(3);

    % resample train set - this is how we reballance our training distribution
    train_rsmpl = train.rsmpl_data("resample",[0 round(ratio_1_2 - 1) round(ratio_1_3 - 1)]);

    % create a datastore from the normed data - this is usefull if we want to augment our data while training the NN
    % notice that this function uses the normalized segments
    train.create_ds();
    train_rsmpl.create_ds();
    val.create_ds();
    test.create_ds();
    
    % add augmentation functions to the train datastore (X flip & random
    % gaussian noise) - helps preventing overfitting
    train_rsmpl_aug = train_rsmpl.augment();
    
    % train a model - the 'algo' name will determine which model to train
    model = train_my_model(options.model_algo, options.constants, ...
        "train_ds", train_rsmpl_aug.data_store, "val_ds", val.data_store);
    
    % save the model, its settings and the recordings names that were used to create it
    path = ['C:\Users\tomer\Desktop\ALS\project\6.figures and models\optimization\' num2str(k)];
    mkdir path

    mdl_struct.options = options;
    mdl_struct.model = model;
    mdl_struct.test_names = test.Name;
    mdl_struct.val_name = val.Name;
    mdl_struct.train_name = train.Name;
    save([path '\mdl_struct'], 'mdl_struct')
end
