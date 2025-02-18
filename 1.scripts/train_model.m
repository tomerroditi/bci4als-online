% this script performs data aggregation, data preprocessing and training a
% model to predict right left or idle, follow the instructions bellow to
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
train_folders_num = {[3,5,6,8,9,10,12,13,15,200:202], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist

pipeline = my_pipeline("seg_dur", 4, "overlap", 3.5, "model_algo", 'EEGNet_lstm', 'sequence_len', 4, 'sequence_overlap', 1, 'threshold', 0.4);

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
% model.EEGNet_explain();

%% save the model its settings and the recordings names that were used to create it
path = uigetdir();
model.save(path);
