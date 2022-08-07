function alexnet_tf = alexnet_tf(train_ds, val_ds, my_pipeline)
% this function finetunes the alexnet model with input data that contains a
% continuous wavelet transformation of the segments. (check 'wavelets' in
% feature extraction methods folder)
%
% Input: 
%   train_ds: a datastore containing the training data and labels. 
%   val_ds: a datastore containing the validation data and labels.
%
% Output:
%   eegnet: the trained EEGNet model
%

% % ##### the weights data is to heavy for git so it needs to be changed to
% % load the trained alexnet from matlab instead from local file #####

% reset gpu to prevent limited gpu memory
evalc('gpuDevice(1)');

% extract the number of classes
sample = read(train_ds);
num_classes = numel(categories(sample{1,2}));

net = alexnet;
transfer_learning_layers = net.Layers(1:end-3);
layers = [
    transfer_learning_layers
    fullyConnectedLayer(num_classes, 'WeightLearnRateFactor', 20, 'BiasLearnRateFactor', 20)
    softmaxLayer
    classificationLayer];

% set some training and optimization parameters
options = trainingOptions('sgdm', ...
    'Plots','training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency', 10, ...
    'MaxEpochs', 30, ...
    'MiniBatchSize', 40, ... 
    'Shuffle','every-epoch', ...
    'ValidationData', val_ds, ...
    'ValidationFrequency', 10, ...
    'InitialLearnRate', 0.0001);

% train the network
alexnet_tf = trainNetwork(train_ds, layers, options);

end





