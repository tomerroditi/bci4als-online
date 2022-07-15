% this script is designed to test different thresholds for the models and
% pick the best one.

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% construct the models and their data
folder = uigetdir; % choose the desired folder
dir_list = dir([folder '\*.mat']);
num_models = length(dir_list);
train_mrec = cell(num_models,1);
test_mrec = cell(num_models,1);
models = cell(num_models,1);

%% select folders
% bad recordings from tomer - 2 (not sure why),7,14 (one of the channels is completly corapted)
recorders = {'tomer', 'omri', 'nitay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folder_num = {[3:15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
model = load(fullfile(folder, dir_list(1).name)); model = model.model;
options = model.options;

data_paths = create_paths(recorders, folder_num); % create paths from recorders and folder num
recordings = cell(length(data_paths),1); % initialize an empty cell for the recordings objects
f = waitbar(0, 'creating recordings'); % create a waitbar
for i = 1:length(data_paths)
    waitbar(i/length(data_paths),f,['recording ' num2str(i) ' out of ' num2str(length(data_paths))]); % update waitbar
    rec = recording(data_paths{i}, options); % create the recording object
    rec.complete_pipeline();
    recordings{i} = rec;
end
delete(f)
%%
for i = 1:num_models
    % load the model and its recordings names
    model = load(fullfile(folder, dir_list(i).name)); model = model.model;
    model.get_my_data(recordings);
    models{i} = model;
end

%% evaluate the model on all k-folds and try different working points for the model
% initialize empty arrays
val_accuracy = zeros(num_models,1); train_accuracy = zeros(num_models,1);
val_gest_accuracy = zeros(num_models,1); train_gest_accuracy = zeros(num_models,1);
val_gest_missed = zeros(num_models,1); train_gest_missed = zeros(num_models,1);
val_mean_delay = zeros(num_models,1); train_mean_delay = zeros(num_models,1);
val_names = cell(num_models,1);

for i = 1:num_models
    models{i}.set_values(5,5,7);
    [CM_train, CM_val] = models{i}.evaluate(); 
    [gest_accuracy, gest_missed, mean_delay] = models{i}.detect_gestures();

    train_gest_accuracy(i) = gest_accuracy{1}; val_gest_accuracy(i) = gest_accuracy{2};
    train_gest_missed(i) = gest_missed{1}; val_gest_missed(i) = gest_missed{2};
    train_mean_delay(i) = mean_delay{1}; val_mean_delay(i) = mean_delay{2};

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    val_accuracy(i) = sum(diag(CM_val))/sum(sum(CM_val));

    val_names{i} = models{i}.val.Name;
end

% model explainability
% figure(i)
% plot_weights(model, constants.electrode_loc) % weights plotting

headers = ["train accuracy", "train gesture accuracy", "train missed gestures", "val accuracy",...
    "val gesture accuracy", "val missed gestures", "val recording"];
results = table(train_accuracy, train_gest_accuracy, train_gest_missed, val_accuracy, val_gest_accuracy, ...
    val_gest_missed,  val_names, 'VariableNames', headers);

% compute the model mean accuracy and its std
mean_train_accu = mean(train_accuracy); std_train_accu = std(train_accuracy);
mean_train_gest_accu = mean(train_gest_accuracy); std_train_gest_accu = std(train_gest_accuracy);
mean_train_gest_miss = mean(train_gest_missed); std_train_gest_miss = std(train_gest_missed);
mean_train_delay = mean(train_mean_delay); std_train_delay = std(train_mean_delay);

mean_val_accu = mean(val_accuracy);std_val_accu = std(val_accuracy);
mean_val_gest_accu = mean(val_gest_accuracy); std_val_gest_accu = std(val_gest_accuracy);
mean_val_gest_miss = mean(val_gest_missed); std_val_gest_miss = std(val_gest_missed);
mean_val_delay = mean(val_mean_delay); std_val_delay = std(val_mean_delay);

% plot the results
figure('Name', 'model performance');
subplot(2,2,1)
bar(categorical({'train', 'test'}), [mean_train_accu, mean_val_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_accu, mean_val_accu], [std_train_accu, std_val_accu], LineStyle = 'none', Color = 'black');
title('segment accuracy');
subplot(2,2,2)
bar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_val_gest_accu]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_accu, mean_val_gest_accu], [std_train_gest_accu, std_val_gest_accu], LineStyle = 'none', Color = 'black');
title('gestures accuracy');
subplot(2,2,3)
bar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_val_gest_miss]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_gest_miss, mean_val_gest_miss], [std_train_gest_miss, std_val_gest_miss], LineStyle = 'none', Color = 'black');
title('gestures miss rate');
subplot(2,2,4)
bar(categorical({'train', 'test'}), [mean_train_delay, mean_val_delay]); hold on;
errorbar(categorical({'train', 'test'}), [mean_train_delay, mean_val_delay], [std_train_delay, std_val_delay], LineStyle = 'none', Color = 'black');
title('gesture delay');
hold off;
