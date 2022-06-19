% this script is designed to test different thresholds for the models and
% pick the best one.

% warnings suppressers (mainy for arrays changing size in iterations)


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% construct the models and their data
num_models = 12;
train_mrec = cell(num_models,1);
test_mrec = cell(num_models,1);
models = cell(num_models,1);
folder = 'C:\Users\tomer\Desktop\ALS\project\6.figures and models\EEGNet CV';

%% select folders
% bad recordings from tomer - 2 (not sure why),7,14 (one of the channels is completly corapted)
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folder_num = {[1, 3:6, 8:13, 15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist

load([folder '\mdl_struct_1'])
options = mdl_struct.options;

data_paths = create_paths(recorders, folder_num);
recordings = cell(length(data_paths),1);
f = waitbar(0, 'creating recordings');
for i = 1:length(data_paths)
    waitbar(i/length(data_paths),f,['recording ' num2str(i) ' out of ' num2str(length(data_paths))]);
    rec = recording(data_paths{i}, options);
    rec.normalize('all'); % normalize the data
    rec.extract_feat(); % extract features (if required)
    rec.create_ds; % create a data store (from normalized segments)
    recordings{i} = rec;
end
delete(f)

for i = 1:num_models
    % load the model and its recordings names
    load([folder '\mdl_struct_' num2str(i)])
    models{i} = mdl_struct.model;
    train_name = mdl_struct.train_name;
    test_name = mdl_struct.test_name;
    
    % create a multi recording object for each set - make sure that the
    % recordings that were used to train the model are still available!
    train_idx = zeros(length(data_paths),1);
    test_idx = zeros(length(data_paths),1);

    for j = 1:length(data_paths)
        if ismember(recordings{j}.Name, train_name)
            train_idx(i) = j; 
        elseif ismember(recordings{j}.Name, test_name)
            test_idx(i) = j;
        end
    end
    train_idx(train_idx == 0) = []; % remove zeros
    test_idx(test_idx == 0) = [];   % remove zeros

    % construct the mrec objects
    train_mrec{i} = multi_recording(recordings(train_idx));
    test_mrec{i} = multi_recording(recordings(test_idx));

    train_mrec{i}.create_ds(); test_mrec{i}.create_ds(); % create mrec data stores 
    train_mrec{i}.group = 'train'; test_mrec{i}.group = 'test'; % give each group a name
end

%% evaluate the model on all k-folds and try different working points for the model
% initialize empty arrays
train_accuracy = zeros(num_models,1); test_accuracy = zeros(num_models,1);
train_accuracy_gest = zeros(num_models,1); test_accuracy_gest = zeros(num_models,1);
missed_train = zeros(num_models,1); missed_test = zeros(num_models,1);

K = 3; cool_time = 5; % initialize parameters
for i = 1:num_models
    [~, thresh, CM_train] = train_mrec{i}.evaluate(models{i}, CM_title = 'train', criterion = 'spec', criterion_thresh = 0.8); 
    [~, ~, CM_test] = test_mrec{i}.evaluate(models{i}, CM_title = 'test', thres_C1 = thresh);
    
    CM_gest_train = detect_gestures(train_mrec{i}, K, cool_time, false);
    CM_gest_test = detect_gestures(test_mrec{i}, K, cool_time, false);

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    test_accuracy(i) = sum(diag(CM_test))/sum(sum(CM_test));

    train_accuracy_gest(i) = sum(diag(CM_gest_train(2:3,2:3)))/sum(sum(CM_gest_train(2:3,2:3))); 
    test_accuracy_gest(i) = sum(diag(CM_gest_test(2:3,2:3)))/sum(sum(CM_gest_test(2:3,2:3)));

    missed_train(i) = sum(CM_gest_train(:,1))/sum(sum(CM_gest_train));
    missed_test(i) = sum(CM_gest_test(:,1))/sum(sum(CM_gest_test));
end

% model explainability
% figure(i)
% plot_weights(model, constants.electrode_loc) % weights plotting

% compute the model mean accuracy and its std
mean_train_accu = mean(train_accuracy);
mean_test_accu = mean(test_accuracy);

std_train_accu = std(train_accuracy);
std_test_accu = std(test_accuracy);

% compute the model mean accuracy and its std on gestures detection
mean_gest_train_accu = mean(train_accuracy_gest);
mean_gest_test_accu = mean(test_accuracy_gest);

std_gest_train_accu = std(train_accuracy_gest);
std_gest_test_accu = std(test_accuracy_gest);

% compute the model missed gestures mean and std
mean_gest_train_miss = mean(missed_train);
mean_gest_test_miss = mean(missed_test);

std_gest_train_miss = std(missed_train);
std_gest_test_miss = std(missed_test);

% plot the results - segments
catg = categorical({'train', 'test'});     % categories
means = [mean_train_accu, mean_test_accu]; % means
stds = [std_train_accu, std_test_accu];    % stds

figure('Name', 'model performance'); title('segments');
bar(catg, means); hold on;
errorbar(catg, means, stds, LineStyle = 'none', Color = 'black');

% plot the results - gestures
catg = categorical({'train - accuracy', 'test - accuracy', 'train - missed', 'test - missed'}); % categories
means = [mean_gest_train_accu, mean_gest_test_accu, mean_gest_train_miss, mean_gest_test_miss]; % means
stds = [std_gest_train_accu, std_gest_test_accu, std_gest_train_miss, std_gest_test_miss];      % stds

figure('Name', 'model gestures performance'); title('gestures');
bar(catg, means); hold on;
errorbar(catg, means, stds, LineStyle = 'none', Color = 'black')
