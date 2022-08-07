% this script performs data aggregation, data preprocessing and training a
% model to predict right left or idle, follow the instructions bellow to
% manage the script:
% 
% - change the folders paths in the first section to the relevant 
%   recordings you intend to use to train the model.
% - change the options settings according to the desired pipeline you wish
%   to create.
% - for more changes check the 'constants' class function in 'classes'
%   folder.
% - choose a folder to save your trained model to when the save gui is
%   opened


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup();

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings

% train_folders_num = {[], [], [], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], [2:5], []}; % recordings numbers for train data - make sure that they exist
% val_folders_num =  {[], [], [], [], [], [], [], [], [], [], [], [], [2:5]}; % recordings numbers for validation data- make sure that they exist

train_folders_num = {[3:6], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist
pipeline = my_pipeline("seg_dur", 3, "overlap", 2.5,"class_label", [1;2;2], 'cont_or_disc', 'discrete');

%% preprocess the data into train, test and validation sets
train = multi_recording(recorders, train_folders_num, pipeline);
val = multi_recording(recorders, val_folders_num, pipeline);

%% check data distribution in each data set
disp('training data distribution'); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)

%% train a model - the 'algo' name will determine which model to train
model = bci_model(train, val);

%% evaluate the model on train and val
model.classify_gestures(train, plot = true, plot_title = 'train'); 
model.classify_gestures(val, plot = true, plot_title = 'validation'); 

%% model explainability
model.EEGNet_explain();

%% save the model its settings and the recordings names that were used to create it
path = uigetdir();
model.save(path);
