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

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
folders_num = {[1:17], [1:5], []}; % recordings numbers - make sure that they exist
data_paths = create_paths(recorders, folders_num);
% apperantly we have bad recordings...
% currently bad recordings from tomer: [2] 

%% load the model and its options
uiopen("load")
options = mdl_struct.options;
model = mdl_struct.model;
constants = options.constants;
val_name = mdl_struct.val_name;
train_name = mdl_struct.train_name;
test_name = mdl_struct.test_name;

%% create a multi recording object for each set
val_paths = names2paths(val_name);
test_paths = names2paths(test_name);
train_paths = names2paths(train_name);

train = paths2Mrec(train_paths, options); % create a class member for train
val = paths2Mrec(val_paths, options); % create a class member for val
test = paths2Mrec(test_paths, options); % create a class member for test
new = paths2Mrec(data_paths(~ismember(data_paths, cat(1, train_paths, val_paths, test_paths))), options); % create a class member for new recordings 
train.group = 'train'; val.group = 'val'; test.group = 'test'; new.group = 'new'; % give each group a name

%% create a multi_recording class object from the paths and options
all_rec = multi_recording({train, val, test, new}); % create a class member from all paths

disp('train recordings are:'); disp(sort(train.Name));
disp('validation recordings are:'); disp(sort(val.Name));
disp('test recordings are:'); disp(sort(test.Name));
disp('new recordings are:'); disp(sort(new.Name));


%% predict data classes and visualize the results
all_rec.create_ds; % create a data store (from normalized segments)
all_rec.evaluate(model, "CM_title", 'all data'); % predict using the model
all_rec.visualize("title", 'all data'); % visualize predictions
all_rec.fc_activation(model); % get the fc layer activations
all_rec.visualize_act('tsne', 3); % search for clusters with t-sne or pca, visualize in 2d or 3d!
