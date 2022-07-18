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

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
train_folders_num = {[1:6, 8:10, 12:13, 15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist

train_data_paths = create_paths(recorders, train_folders_num);
val_data_paths = create_paths(recorders, val_folders_num);

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
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% create all the desired options for training 
seg_dur = [2.5, 3, 3.5, 4];
not_overlaped = [1.5, 1, 0.5];
threshold = [0.6, 0.65, 0.7, 0.75, 0.8];

options_set = cell(1,length(seg_dur)*length(not_overlaped)*length(threshold));
counter = 0; % define a counter variable
for i = 1:length(seg_dur)
    options.seg_dur = seg_dur(i);
    for j = 1:length(not_overlaped)
        options.overlap = seg_dur(i) - not_overlaped(j);
        for k = 1:length(threshold)
            options.threshold = threshold(k);
            counter = counter + 1; % update the counter
            options_set{counter} = options; % save the current options structure
        end
    end
end

%% train models with different options
models = cell(5,length(options));
for k = 1:length(options_set)
    options = options_set{k}; % the current options structure
    if options.seg_dur - options.overlap == 1.5
        options.constants.set_max_epochs(70)
        options.constants.set_learn_rate_drop_period(60)
    elseif options.seg_dur - options.overlap == 1
        options.constants.set_max_epochs(50)
        options.constants.set_learn_rate_drop_period(45)
    elseif options.seg_dur - options.overlap == 0.5
        options.constants.set_max_epochs(40)
        options.constants.set_learn_rate_drop_period(35)
    end
    % preprocess the data into train and validation sets
    train = paths2Mrec(train_data_paths, options);
    val = paths2Mrec(val_data_paths, options);

    % train a model - the 'algo' name will determine which model to train
    model = bci_model(train, val, recording(), pipeline = false);
    
    % save the model, its settings and the recordings names that were used to create it
    path = [options.constants.root_path '\6.figures and models\optimization\' num2str(k)];
    mkdir(path)
    model.save(path);
end
