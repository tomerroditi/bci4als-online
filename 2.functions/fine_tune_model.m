function [mdl_struct, new_thresh] = fine_tune_model(mdl_struct, path)

options = mdl_struct.options;
model = mdl_struct.model;
constants = options.constants;

train = paths2Mrec(path, options);

%% check data distribution in each data set
disp('fine tuning training data distribution'); tabulate(train.labels)

%% prepare data for training
train_rsmpl = train.complete_pipeline("rsmpl", true);

%% train the model on the new data
% set some training and optimization parameters
training_options = trainingOptions('adam', ...
    'Verbose', true, ...
    'VerboseFrequency',constants.verbose_freq, ...
    'MaxEpochs', 20, ...
    'MiniBatchSize', constants.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'InitialLearnRate', 0.0001, ...
    'OutputNetwork', 'last-iteration');

model = trainNetwork(train_rsmpl.data_store, model.Layers, training_options);

%% set working points and evaluate the model on all data stores
train.evaluate(model, CM_title = 'train', print = true, thres_C1 = mdl_struct.thresh); 
new_thresh = train.evaluate(model, CM_title = 'train - new thresh', print = true, criterion = 'accu', criterion_thresh = 1);

%% visualize the predictions
train.visualize("title", 'train'); 

%% visualize gesture execution
train.detect_gestures(mdl_struct.raw_pred_action, mdl_struct.cool_time, 7, true); 

%% save the model its settings and the recordings names that were used to create it
mdl_struct.model = model;
uisave('mdl_struct', 'mdl_struct');
end
