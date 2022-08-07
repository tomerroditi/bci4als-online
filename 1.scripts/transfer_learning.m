% this script is used to do transfer learning of trained EEGNet on one
% subject to other subjects

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings

train_folders_num = {[], [10], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[], [9], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for validation data- make sure that they exist

%% select a model to use for transfer learning
uiopen("load")
pipeline = model.my_pipeline;

%% preprocess the data into train, test and validation sets
train = multi_recording(recorders, train_folders_num, pipeline);
val = multi_recording(recorders, val_folders_num, pipeline);

%% check data distribution in each data set
disp('training data distribution'); train_distr = tabulate(train.labels); tabulate(train.labels)
disp('validation data distribution'); tabulate(val.labels)

%% transfer learning
tl_model = model.transfer_learning(train, val);

%% visualize predictions and gesture execution
tl_model.classify_gestures(train, 'plot', true, 'plot_title', 'train'); 
tl_model.classify_gestures(val, 'plot', true, 'plot_title', 'val'); 

%% save the model
path = uigetdir();
tl_model.save(path)

