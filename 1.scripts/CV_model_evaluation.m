% this script is designed to test different thresholds for the models and
% pick the best one.

% warnings suppressers (mainy for arrays changing size in iterations)


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% construct the models and their data
folder = uigetdir; % choose the desired folder; % choose the desired folder
num_models = length(dir([folder '\*.mat']));
train_mrec = cell(num_models,1);
test_mrec = cell(num_models,1);
models = cell(num_models,1);

%% select folders
% bad recordings from tomer - 2 (not sure why),7,14 (one of the channels is completly corapted)
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folder_num = {[1, 3:6, 8:13, 15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist

load([folder '\mdl_struct_1'])
options = mdl_struct.options;

data_paths = create_paths(recorders, folder_num); % create paths from recorders and folder num
recordings = cell(length(data_paths),1); % initialize an empty cell for the recordings objects
f = waitbar(0, 'creating recordings'); % create a waitbar
for i = 1:length(data_paths)
    waitbar(i/length(data_paths),f,['recording ' num2str(i) ' out of ' num2str(length(data_paths))]); % update waitbar
    rec = recording(data_paths{i}, options); % create the recording object
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
test_accuracy = zeros(num_models,1); train_accuracy = zeros(num_models,1);
test_gest_accuracy = zeros(num_models,1); train_gest_accuracy = zeros(num_models,1);
test_gest_missed = zeros(num_models,1); train_gest_missed = zeros(num_models,1);
test_mean_delay = zeros(num_models,1); train_mean_delay = zeros(num_models,1);
test_names = cell(num_models,1);

K = 5; cool_time = 5; % initialize parameters
for i = 1:num_models
    [~, thresh, CM_train] = train_mrec{i}.evaluate(models{i}, CM_title = 'train', criterion = 'accu', criterion_thresh = 1); 
    [~, ~, CM_test] = test_mrec{i}.evaluate(models{i}, CM_title = 'test', thres_C1 = thresh);

    [train_gest_accuracy(i), train_gest_missed(i), train_mean_delay(i)] = train_mrec{i}.detect_gestures(K, cool_time, false);
    [test_gest_accuracy(i), test_gest_missed(i), test_mean_delay(i)] = test_mrec{i}.detect_gestures(K, cool_time, true);

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    test_accuracy(i) = sum(diag(CM_test))/sum(sum(CM_test));

    test_names{i} = test_mrec{i}.Name;
end

% model explainability
% figure(i)
% plot_weights(model, constants.electrode_loc) % weights plotting
headers = ["train accuracy", "train gesture accuracy", "train missed gestures", "test accuracy",...
    "test gesture accuracy", "test missed gestures", "test recording"];
results = table(train_accuracy, train_gest_accuracy, train_gest_missed, test_accuracy, test_gest_accuracy, ...
    test_gest_missed,  test_names, 'VariableNames', headers);

% compute the model mean accuracy and its std
mean_train_accu = mean(train_accuracy); std_train_accu = std(train_accuracy);
mean_train_gest_accu = mean(train_gest_accuracy); std_train_gest_accu = std(train_gest_accuracy);
mean_train_gest_miss = mean(train_gest_missed); std_train_gest_miss = std(train_gest_missed);
mean_train_delay = mean(train_mean_delay); std_train_delay = std(train_mean_delay);

mean_test_accu = mean(test_accuracy);std_test_accu = std(test_accuracy);
mean_test_gest_accu = mean(test_gest_accuracy); std_test_gest_accu = std(test_gest_accuracy);
mean_test_gest_miss = mean(test_gest_missed); std_test_gest_miss = std(test_gest_missed);
mean_test_delay = mean(test_mean_delay); std_test_delay = std(test_mean_delay);

% plot the results
figure('Name', 'model performance');
subplot(2,2,1)
bar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_accu, mean_test_accu], [std_train_accu, std_test_accu], LineStyle = 'none', Color = 'black');
title('segment accuracy');
subplot(2,2,2)
bar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_test_gest_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_test_gest_accu], [std_train_gest_accu, std_test_gest_accu], LineStyle = 'none', Color = 'black');
title('gestures accuracy');
subplot(2,2,3)
bar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_test_gest_miss]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_test_gest_miss], [std_train_gest_miss, std_test_gest_miss], LineStyle = 'none', Color = 'black');
title('gestures miss rate');
subplot(2,2,4)
bar(categorical({'train', 'test'}), [mean_train_delay, mean_test_delay]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_delay, mean_test_delay], [std_train_delay, std_test_delay], LineStyle = 'none', Color = 'black');
title('gesture delay');
hold off;
