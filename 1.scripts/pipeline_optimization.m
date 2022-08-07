% this script trains models with different preprocessing schemes, after
% training the models use the preprocess optimization results script to
% analyze your results.
% the models are trained with the same train and validation sets each time 
% but with different parameters.


clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()
path = uigetdir;

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay'}; % people we got their recordings
train_folders_num = {[5:6], [], []}; % recordings numbers for train data - make sure that they exist
val_folders_num =  {[11], [], []}; % recordings numbers for validation data- make sure that they exist

%% create all the desired pipelines for training - modify this as you wish
seg_dur = [2.5];
not_overlaped = [1.5, 1];
threshold = [0.6, 0.65];

pipelines = cell(1,length(seg_dur)*length(not_overlaped)*length(threshold));
options_cell = cell(1,length(seg_dur)*length(not_overlaped)*length(threshold));
counter = 1; % define a counter variable
for i = 1:length(seg_dur)
    for j = 1:length(not_overlaped)
        for k = 1:length(threshold)
            pipelines{counter} = my_pipeline("model_algo", 'EEGNet', 'seg_dur', seg_dur(i),...
                'overlap', seg_dur(i) - not_overlaped(j), 'threshold', threshold(k), 'max_epochs', round(20 + not_overlaped(j)*20),...
                'learn_rate_drop_period', round(20 + not_overlaped(j)*20) - 5);
            % create a structure for the different values of the pipeline
            % to display in a table later
            options.seg_dur = seg_dur(i);
            options.overlap = seg_dur(i) - not_overlaped(j);
            options.threshold = threshold(k);
            options_cell{counter} = options;
            counter = counter + 1; % update the counter
        end
    end
end

%% train models with different options
models = cell(1,length(pipelines));
for k = 1:length(pipelines)
    % preprocess the data into train and validation sets
    train = multi_recording(recorders, train_folders_num, pipelines{k});
    val = multi_recording(recorders, val_folders_num, pipelines{k});

    % train a model
    model = bci_model(train, val);

    % compute accuracies on each data set
    [accuracy_t, missed_gest_t, mean_delay_t, ~, predictions_t] = model.classify_gestures(train); 
    [accuracy_v, missed_gest_v, mean_delay_v, ~, predictions_v] = model.classify_gestures(val);

    train_acc = sum(predictions_t == train.labels)/length(predictions_t);
    val_acc = sum(predictions_v == val.labels)/length(predictions_v);
    
    % create a table to strore all the results
    options_tbl = struct2table(options_cell{k});
    headers = {'train accu', 'val accu', 'train gest accu', 'train gest miss',...
        'val gest accu', 'val gest miss', 'train delay', 'val delay'};
    values = [train_acc, val_acc, accuracy_t, missed_gest_t, accuracy_v, missed_gest_v, mean_delay_t, mean_delay_v];
    results_tbl = array2table(values, "VariableNames", headers);

    curr_tbl = [options_tbl, results_tbl];
    curr_tbl.('model number') = k;
    if exist('results', 'var')
        results = cat(1, results, curr_tbl);
    else
        results = curr_tbl;
    end

    % save the model, its settings and the recordings names that were used to create it
    model.save(path, file_name = ['bci_model_' num2str(k, '%.3d')]);
end
save(fullfile(path,'results'), 'results');

%% calculate model evaluation metric
func = @(x,y) x*(1-y)/(2-x); % completely arbitrary, you may use your own metrics here
metric = rowfun(func, results, "OutputVariableNames", 'metric value', 'InputVariables',{'val gest accu','val gest miss'}, 'OutputFormat', 'table');
results = [metric, results];

%% results visualization
fig = uifigure();
uit = uitable(fig, 'Data', results, ColumnSortable = true);
% color rows with certain properties - indication for good models
func = @(acc, miss) acc > 0.9 && miss < 0.3; % feel free to change this...
idx = rowfun(func, results, 'InputVariables',{'val gest accu','val gest miss'}, 'OutputFormat', 'uniform');
s = uistyle("BackgroundColor","green");
addStyle(uit,s,"row", find(idx))

