function new_thresh = fine_tune_model(bci_model, path)
%##### need to finish this function #####
my_pipeline = bci_model.my_pipeline;
model = bci_model.model;

train = recording(path, my_pipeline);
train.rsmpl_data()
train.create_ds();
train.augment()

%% check data distribution
disp('fine tuning training data distribution'); tabulate(train.labels)

%% train the model on the new data
% set some training and optimization parameters
training_options = trainingOptions('adam', ...
    'Verbose', true, ...
    'VerboseFrequency', 10, ...
    'MaxEpochs', 50, ...
    'MiniBatchSize', my_pipeline.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'InitialLearnRate', 0.0001, ...
    'OutputNetwork', 'last-iteration');

model = trainNetwork(train.data_store, model.Layers, training_options);

%% update the bci_model object model
bci_model.model = model;
[~, new_thresh] = evaluation(bci_model, train.data_store, train.labels, ...
                criterion = 'accu', criterion_thresh = 1, print = true);
bci_model.set_threshold(new_thresh)
end
