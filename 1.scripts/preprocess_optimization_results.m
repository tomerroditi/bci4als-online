% this script is designed to test different thresholds for the models and
% pick the best one.

clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% load models and create their Mrec objects
path = uigetdir; % choose the desired folder
num_models = length(dir(path)) - 2; % extract the number of models 

% initialize empty cells
seg_dur = zeros(num_models,1); seg_threshold = zeros(num_models,1); overlap = zeros(num_models,1);

% itirate over models
f = waitbar(0);
for i = 1:num_models
    waitbar(i/num_models, f, ['preprocessing data, ' num2str(i) ' out of ' num2str(num_models)]);
    load([path '\' num2str(i) '\model']);
    options = model.options;
    seg_dur(i) = options.seg_dur;
    seg_threshold(i) = options.threshold;
    overlap(i) = options.overlap;
    % load recordings if we saved them to save time
    if exist([path '\' num2str(i) '\train.mat'], "file") && exist([path '\' num2str(i) '\val.mat'], "file")
        continue
    end
    % create the recordings objects of the model
    model.load_data();
    % save the full model (with rec objects) to save time if we want to iterate again
    save([path '\' num2str(i) '\model'], 'model');
end
delete(f);

%% evaluate each model
% initialize arrays
val_accuracy = zeros(num_models,1); train_accuracy = zeros(num_models,1);
val_gest_accuracy = zeros(num_models,1); train_gest_accuracy = zeros(num_models,1);
val_gest_missed = zeros(num_models,1); train_gest_missed = zeros(num_models,1);
val_mean_delay = zeros(num_models,1); train_mean_delay = zeros(num_models,1);
val_names = cell(num_models,1);

f = waitbar(0);
for i = 1:num_models
    waitbar(i/num_models, f, ['evaluating models, ' num2str(i) ' out of ' num2str(num_models)]);

    load([path '\' num2str(i) '\model.mat']);
    [train_CM, val_CM] = model.evaluate();
    [accuracy, missed_gest, mean_delay, CM] = model.detect_gestures();
    train_gest_accuracy(i) = accuracy{1}; val_gest_accuracy(i) = accuracy{2};
    train_gest_missed(i) = missed_gest{1}; val_gest_missed(i) = missed_gest{2};
    train_mean_delay(i) = mean_delay{1}; val_mean_delay(i) = mean_delay{2};
    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    val_accuracy(i) = sum(diag(CM_val))/sum(sum(CM_val));
    val_names{i} = model.val.Name;
end
delete(f);

%% visualize results
% order the results in a table
headers = ["train accuracy", "train gesture accuracy", "train missed gestures", "test accuracy",...
    "test gesture accuracy", "test missed gestures", "seg duration", "overlap", "seg threshold", "val names"];
results = table(train_accuracy, train_gest_accuracy, train_gest_missed, val_accuracy, val_gest_accuracy, ...
    val_gest_missed, seg_dur, overlap, seg_threshold, val_names, 'VariableNames', headers);
results_sorted = sortrows(results, ["train missed gestures", "train gesture accuracy"], ["ascend", "descend"]);

%% this part is to examine a specific model
K = 50;
load([path '\' num2str(K) '\model.mat']);

[CM_train, CM_val] = model.evaluate(print = true); 
model.visualize();    
% model.find_optimal_values(); % need to finish this function
model.detect_gestures(print = true);

%% need to fix this part to match the new model object
% % % extract the top 5 models
% % results_low_miss = results(missed_test < 0.2,:);
% % test_accuracy_gest_sorted = sort(results_low_miss{:,"test gesture accuracy"}, 'descend');
% % top_3 = find(ismember(results_low_miss{:,"test gesture accuracy"}, test_accuracy_gest_sorted(1:3)));
% % results_top_3 = results_low_miss(top_3,:);
% % 
% % % plot the results of the best 5 models
% % catg = categorical({'train accu', 'train gest accu', 'train gest missed', 'test accu', 'test gest accu', 'test gest missed'});
% % data_to_plot = results_top_3(:,1:6);
% % 
% % for i = 1:3
% %     params = results_top_3{i,7:9};
% %     figure('Name', ['model number ' num2str(i)]); 
% %     title(['model performance - seg duration: ' num2str(params(1)) ', overlap: ' num2str(params(2)) ',seg threshold: ' num2str(params(3))]);
% %     bar(catg, data_to_plot{i,:});
% % end

