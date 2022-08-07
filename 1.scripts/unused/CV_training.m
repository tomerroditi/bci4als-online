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
folder_num = {[3,5,6,8:13,15], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers for train data - make sure that they exist
path = uigetdir(); % select a folder to save the models to

%% define the wanted pipeline and data split options
options.model_algo       = 'EEGNet';     % ML model to train, choose from the files names in DL pipelines folder
% continuous only
options.seg_dur          = 4;            % duration in seconds of each segment
options.overlap          = 3.5;          % duration in seconds of following segments overlapping
options.threshold        = 0.7;          % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)

%% create cv partition from the recordings and train a model for each fold
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

% create a CV partition object, we will use leave one out method
num_fold = length(recordings);
C = cvpartition(num_fold, 'KFold', num_fold); % we will use the regresion partition since recordings dont have a class

% initialize some empty matrices
val_accu = zeros(num_fold,1);       train_accu = zeros(num_fold,1);
val_gest_accu = zeros(num_fold,1);  train_gest_accu = zeros(num_fold,1);
val_gest_mis = zeros(num_fold,1);   train_gest_miss = zeros(num_fold,1);
val_mean_delay = zeros(num_fold,1); train_mean_delay = zeros(num_fold,1);
val_names = cell(num_fold,1);

for i = 1:num_fold
    %% gather data into train and val multi recordings
    train = multi_recording(recordings = recordings(training(C, i)));
    val = multi_recording(recordings = recordings(test(C, i)));
    
    %% some displays to keep track while running
    % display current recordings in each set
    disp(['the ' num2str(i) ' fold sets are:']);
    disp('train recordings are:'); disp(sort(train.Name));
    disp('val recordings are:'); disp(sort(val.Name));

    % check data distribution in each data set
    disp('training data distribution'); tabulate(train.labels)
    disp('val data distribution'); tabulate(val.labels)

    %% train a model & predict on our data bases
    model = bci_model(train, val, recording());
    % labels predictions
    [CM_train, CM_val] = model.evaluate(); 
    % gestures predictions
    model.find_optimal_values()
    [gest_accu, gest_miss, mean_delay] = model.detect_gestures();

    train_gest_accu(i) = gest_accu{1};   val_gest_accu(i) = gest_accu{2};
    train_gest_miss(i) = gest_miss{1};   val_gest_mis(i) = gest_miss{2};
    train_mean_delay(i) = mean_delay{1}; val_mean_delay(i) = mean_delay{2};

    % compute accuracy
    train_accu(i) = sum(diag(CM_train))/sum(sum(CM_train));
    val_accu(i) = sum(diag(CM_val))/sum(sum(CM_val));
    
    % get the valdiation recording name
    val_names{i} = model.val.Name;
    
    % save the model object - use the object save function to save low memory size objects!
    model.save([path '\bci_model_'  num2str(i)]);

end

%% place the results in a table and visualize them
headers = ["train accuracy", "train gesture accuracy", "train missed gestures", "val accuracy",...
    "val gesture accuracy", "val missed gestures", "val recording"];
results = table(train_accu, train_gest_accu, train_gest_miss, val_accu, val_gest_accu, ...
    val_gest_mis,  val_names, 'VariableNames', headers);

% compute the model mean accuracy and its std
mean_train_accu = mean(train_accu); std_train_accu = std(train_accu);
mean_train_gest_accu = mean(train_gest_accu); std_train_gest_accu = std(train_gest_accu);
mean_train_gest_miss = mean(train_gest_miss); std_train_gest_miss = std(train_gest_miss);
mean_train_delay = mean(train_mean_delay); std_train_delay = std(train_mean_delay);

mean_test_accu = mean(val_accu);std_test_accu = std(val_accu);
mean_test_gest_accu = mean(val_gest_accu); std_test_gest_accu = std(val_gest_accu);
mean_test_gest_miss = mean(val_gest_mis); std_test_gest_miss = std(val_gest_mis);
mean_test_delay = mean(val_mean_delay); std_test_delay = std(val_mean_delay);

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
