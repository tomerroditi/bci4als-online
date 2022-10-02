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
recorders = {'tomer'}; % people we got their recordings
train_folders_num = {[3,5,6, 8:10, 12:15]}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11]}; % recordings numbers for validation data- make sure that they exist

train_files = Files_Paths_Handler(recorders, train_folders_num);
val_files = Files_Paths_Handler(recorders, val_folders_num);

%% preprocess the data into train, test and validation sets
data_pipeline = Data_Pipeline("segment_duration", 4, "segment_step_size", 1);
train = Data_Base(train_files, data_pipeline);
val = Data_Base(val_files, data_pipeline);

%% check data distribution in each data set
train.print_data_distribution('training');
val.print_data_distribution('validation');

%% train a model - the 'algo' name will determine which model to train
model_pipeline = Model_Pipeline();
model = BCI_Model(train, model_pipeline, val_DB = val);  

%% evaluate the model on train and val
[train_segment_CM, train_gesture_CM] = model.classify_data_base(train, plot = true, group = 'train');
[val_segment_CM, val_gesture_CM] = model.classify_data_base(val, plot = true, group = 'validation');

%% save the model its settings and the recordings names that were used to create it
path = uigetdir();
model.compact_model();
model.save(path);
