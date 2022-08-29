% this script is for validating models with new recordings, it can be also
% used to check if the recordings are good or not. if the model fails to
% maintain proper accuracy it might be due to bad recordings or due to
% overfitted model. if the model is overfitted you should see it when you
% train the model and check the results on the validation and test sets.
% if the model is okay and the recordings are not good then you should
% recieve low accuracy when predicting on the recording, thus you can check
% every recording seperatly to find which ones are not good enought.
% bad recordings might be caused due to noise, placing electrodes in the
% wrong position or hardware problems (which we can't fix ourselves)


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% select new recordings to visualize
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
folders_num = {[900:901],[],[]}; % recordings numbers - make sure that they exist

%% load the model and its options
uiopen("load")
pipeline = model.my_pipeline;

%% create a multi recording object for each set
% make sure that the recordings that were used to train the model are still available!
model.load_data()
train = model.train;
val = model.val; 
new = multi_recording(recorders, folders_num, model.my_pipeline); % create a class member for new recordings 

%% display the recordings of each group
disp('train recordings are:'); disp(sort(train.Name));
disp('validation recordings are:'); disp(sort(val.Name));
disp('new recordings are:'); disp(sort(new.Name));

%% visualization
model.classify_gestures(train, plot = true, plot_title = 'train');
model.classify_gestures(val, plot = true, plot_title = 'val');
model.classify_gestures(new, plot = true, plot_title = 'new');

%% create one object to hold all recordings 
all_rec = copy(train);
all_rec.append_rec(val);
all_rec.append_rec(new);
all_rec.create_ds();

model.activation_layer_output(all_rec);
model.model_output(all_rec);
