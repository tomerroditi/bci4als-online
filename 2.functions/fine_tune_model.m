function [bci_model, new_thresh] = fine_tune_model(bci_model, path)
%##### need to finish this function #####
my_pipeline = bci_model.my_pipeline;
model = bci_model.model;

train = recording(path, my_pipeline);
train.normalize();
train.extract_feat();
train.rsmpl_data()
train.create_ds();
train.augment()

%% check data distribution
disp('fine tuning training data distribution'); tabulate(train.labels)

%% train the model on the new data
% set some training and optimization parameters
training_options = trainingOptions('adam', ...
    'Verbose', true, ...
    'VerboseFrequency',my_pipeline.verbose_freq, ...
    'MaxEpochs', 20, ...
    'MiniBatchSize', my_pipeline.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'InitialLearnRate', 0.0001, ...
    'OutputNetwork', 'last-iteration');

model = trainNetwork(train.data_store, model.Layers, training_options);

train.evaluate(model, CM_title = 'train', print = true, thres_C1 = bci_model.thresh); 
new_thresh = train.evaluate(model, CM_title = 'train - new thresh', print = true, criterion = 'accu', criterion_thresh = 1);


%% update the bci_model object model
bci_model.model = model;
end
