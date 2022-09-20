% this script performs data preprocessing and training a
% model to predict gestures, follow the instructions bellow to
% manage the script:
% 
% - change the folders numbers in the first section to the relevant 
%   recordings you intend to use to train and validate the model.
% - change the my_pipeline properties values according to the desired pipeline you wish
%   to create.
% - choose a folder to save your trained model to when the save gui is
%   opened

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup();

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
train_folders_num = {[2:10,12:17], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist

train_files = files_paths_handler(recorders, train_folders_num);
val_files = files_paths_handler(recorders, val_folders_num);

pipeline = my_pipeline("segment_duration", 4, "segment_step_size", 1);

%% preprocess the data into train, test and validation sets
train = recording(train_files, pipeline);
val = recording(val_files, pipeline);

%% check data distribution in each data set
train.print_data_distribution('training');
val.print_data_distribution('validation');

%% train a model - the 'algo' name will determine which model to train
model = bci_model(train, val);
model.train_model(oversample = true, augment = true);
model.set_threshold('accu', 1);
model.set_optimal_ct_conf(4:6, 2:6); % set cool time and confidence level

%% evaluate the model on train and val
[train_segment_CM, train_gesture_CM] = model.classify_recording(train, plot = true, group = 'train');
[val_segment_CM, val_gesture_CM] = model.classify_recording(val, plot = true, group = 'validation');

%% model explainability
% model.EEGNet_explain();

%% save the model its settings and the recordings names that were used to create it
path = uigetdir();
model.save(path);
