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

    mdl_struct = load([path '\' num2str(i) '\mdl_struct']);
    mdl_struct = mdl_struct.mdl_struct;
    options = mdl_struct.options;

    seg_dur(i) = options.seg_dur;
    seg_threshold(i) = options.threshold;
    overlap(i) = options.overlap;

    if exist([path '\' num2str(i) '\train.mat'], "file") && exist([path '\' num2str(i) '\test.mat'], "file")
        continue
    end
    train_name = mdl_struct.train_name;
    test_name = mdl_struct.val_name; % i saved them as val

    train_paths = names2paths(train_name);
    test_paths = names2paths(test_name);
    
    train = paths2Mrec(train_paths, options);
    test = paths2Mrec(test_paths, options);

    train.normalize('all'); test.normalize('all'); % normalize mrec data
    train.extract_feat(); test.extract_feat(); % extract features (if required)
    train.create_ds(); test.create_ds(); % create mrec data stores 
    train.group = 'train'; test.group = 'test'; % give each group a name
    save([path '\' num2str(i) '\train'], 'train');
    save([path '\' num2str(i) '\test'], 'test');
end
delete(f);

%% evaluate each model
% initialize arrays
train_accuracy = zeros(num_models,1); test_accuracy = zeros(num_models,1);
train_accuracy_gest = zeros(num_models,1); test_accuracy_gest = zeros(num_models,1);
missed_train = zeros(num_models,1); missed_test = zeros(num_models,1);
CM_gest_test = cell(num_models,1); CM_gest_train = cell(num_models,1);

f = waitbar(0);
K = 3; cool_time = 5; % initialize parameters
for i = 1:num_models
    waitbar(i/num_models, f, ['evaluating models, ' num2str(i) ' out of ' num2str(num_models)]);

    train = load([path '\' num2str(i) '\train.mat']); train = train.train;
    test = load([path '\' num2str(i) '\test.mat']); test = test.test;
    mdl_struct = load([path '\' num2str(i) '\mdl_struct']); model = mdl_struct.mdl_struct.model;

    [~, thresh, CM_train] = train.evaluate(model, CM_title = 'train', criterion = 'accu', criterion_thresh = 1); 
    [~, ~, CM_test] = test.evaluate(model, CM_title = 'test', thres_C1 = thresh);
    
    [train_accuracy_gest(i), missed_train(i)] = detect_gestures(train, K, cool_time, false);
    [test_accuracy_gest(i), missed_test(i)] = detect_gestures(test, K, cool_time, false);

    train_accuracy(i) = sum(diag(CM_train))/sum(sum(CM_train));
    test_accuracy(i) = sum(diag(CM_test))/sum(sum(CM_test));
end
delete(f);

%% visualize results
% order the results in a table
headers = ["train accuracy", "train gesture accuracy", "train missed gestures", "test accuracy",...
    "test gesture accuracy", "test missed gestures", "seg duration", "overlap", "seg threshold"];
results = table(train_accuracy, train_accuracy_gest, missed_train, test_accuracy, test_accuracy_gest, ...
    missed_test, seg_dur, overlap, seg_threshold, 'VariableNames', headers);
results_sorted = sortrows(results, ["train missed gestures", "train gesture accuracy"], ["ascend", "descend"]);

%%
K = 50;
train = load([path '\' num2str(K) '\train.mat']); train = train.train;
test = load([path '\' num2str(K) '\test.mat']); test = test.test;
mdl_struct = load([path '\' num2str(K) '\mdl_struct']); model = mdl_struct.mdl_struct.model;

[~, thresh, CM_train] = train.evaluate(model, CM_title = 'train', criterion = 'accu', criterion_thresh = 1, print = true); 
[~, ~, CM_test] = test.evaluate(model, CM_title = 'test', thres_C1 = thresh, print = true);
    
train.visualize(title = 'train');
test.visualize(title = 'test');

train.detect_gestures(1, 5, true);
test.detect_gestures(1, 5, true);


% % extract the top 5 models
% results_low_miss = results(missed_test < 0.2,:);
% test_accuracy_gest_sorted = sort(results_low_miss{:,"test gesture accuracy"}, 'descend');
% top_3 = find(ismember(results_low_miss{:,"test gesture accuracy"}, test_accuracy_gest_sorted(1:3)));
% results_top_3 = results_low_miss(top_3,:);
% 
% % plot the results of the best 5 models
% catg = categorical({'train accu', 'train gest accu', 'train gest missed', 'test accu', 'test gest accu', 'test gest missed'});
% data_to_plot = results_top_3(:,1:6);
% 
% for i = 1:3
%     params = results_top_3{i,7:9};
%     figure('Name', ['model number ' num2str(i)]); 
%     title(['model performance - seg duration: ' num2str(params(1)) ', overlap: ' num2str(params(2)) ',seg threshold: ' num2str(params(3))]);
%     bar(catg, data_to_plot{i,:});
% end

