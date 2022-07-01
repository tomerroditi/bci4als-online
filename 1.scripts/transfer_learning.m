% this script is used to do transfer learning of trained EEGNet on one
% person to other people

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'itay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings

train_folders_num = {[], [], [2], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[], [], [1], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist

train_data_paths = create_paths(recorders, train_folders_num);
val_data_paths = create_paths(recorders, val_folders_num);

%% select a model to use for transfer learning
uiopen("load")
options = mdl_struct.options;
model = mdl_struct.model;
constants = options.constants;

%% preprocess the data into train, test and validation sets
train = paths2Mrec(train_data_paths, options);
val = paths2Mrec(val_data_paths, options);

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)

%% normalize data
train.normalize('all');
val.normalize('all');

% resample train set - this is how we reballance our training distribution
% (mainly for continuous segmentation, when we have lots of idle class)
train_rsmpl = train.rsmpl_data();

%% extract features - determined by options.feat_alg
train.extract_feat();
val.extract_feat();

%% create a datastore for the data - this is usefull if we want to augment our data while training the NN
% you can choose either to create the data store from "feat" or from
% "data", the deafalut value is based on options.feat_or_data variable
train.create_ds();
train_rsmpl.create_ds();
val.create_ds();

% add augmentation functions to the train datastore (X flip & random
% gaussian noise) - helps preventing overfitting
train_rsmpl_aug = train_rsmpl.augment();

%% train the model on the new data
% set some training and optimization parameters
training_options = trainingOptions('adam', ...
    'Plots','training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency',constants.verbose_freq, ...
    'MaxEpochs', 100, ...
    'MiniBatchSize', constants.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'ValidationData', val.data_store, ...
    'ValidationFrequency', constants.validation_freq, ...
    'InitialLearnRate', 0.001, ...
    'OutputNetwork', 'last-iteration');

model = trainNetwork(train.data_store, model.Layers, training_options);

%% set working points and evaluate the model on all data stores
[~, thresh] = train.evaluate(model, CM_title = 'train', print = true, criterion = 'accu', criterion_thresh = 1); 
val.evaluate(model, CM_title = 'val', print = true, thres_C1 = thresh); 

%% visualize the predictions
train.visualize("title", 'train'); 
val.visualize("title", 'val'); 

%% visualize gesture execution
train.detect_gestures(4, 5, 7, true); 
val.detect_gestures(4, 5, 7, true); 

%% save the model its settings and the recordings names that were used to create it
mdl_struct.options = train.options; % save the corected options structure
mdl_struct.model = model;
mdl_struct.test_name = [];
mdl_struct.val_name = val.Name;
mdl_struct.train_name = train.Name;
mdl_struct.thresh = thresh;
mdl_struct.cool_time = [];
mdl_struct.raw_pred_action = [];
uisave('mdl_struct', 'mdl_struct');
