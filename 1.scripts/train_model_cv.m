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
recorders = {'tomer'}; % people we got their recordings
folder_num = {[2:23]}; % recordings numbers for train data - make sure that they exist
DB_files = Files_Paths_Handler(recorders, folder_num);

%% create a data base and train a bci model using cross validation
data_pipeline = Data_Pipeline("segment_duration", 4, "segment_step_size", 0.5);
DB = Data_Base(DB_files, data_pipeline);
DB.print_data_distribution('all data');

%%
model_pipeline = Model_Pipeline();
cv_model = BCI_Model_CV(DB, Model_Pipeline);
cv_model.plot_CV_stats();

% %% save the cv model
% uisave('cv_model', 'cv_model')
