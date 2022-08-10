% this script is used to train a model in a cross validation manner. we
% devide our recordings into a k-fold and compute the mean accuracy and std
% to better conclude how our model performs.
% the process includes data aggregation, data preprocessing and training a
% model to predict right left or idle for each fold.
% follow the instructions bellow to manage the script:

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to create cv partition from
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folder_num = {[3,5,6,8,9,10,11,12,13,15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
pipeline = my_pipeline("seg_dur", 4, "overlap", 3.5,"model_algo", 'EEGNet_lstm', 'sequence_len', 4, 'sequence_overlap', 2);

%% create a multi recording object and train a bci model using cross validation
train = multi_recording(recorders, folder_num, pipeline);
cv_model = bci_model_cv(train);
cv_model.plot_means();

%% save the cv model
uisave('cv_model', 'cv_model')
