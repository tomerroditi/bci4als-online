function eegnet_lstm = EEGNet_lstm(train_ds, val_ds, my_pipeline)
% this function generate and train the Deep network presented in the paper 
% "EEGNet: A Compact Convolutional Neural Network for EEG-based 
% Brain-Computer Interfaces", with an additional lstm kayer, and returns
% the trained model.
% pdf of the paper - https://arxiv.org/pdf/1611.08024v4.pdf
% code from the paper - https://github.com/vlawhern/arl-eegmodels
%
% Input: 
%   train_ds: a datastore containing the training data and labels. 
%   val_ds: a datastore containing the validation data and labels.
%   constants: a structure contains the constants of the pipeline.
%
% Output:
%   eegnet_lstm: the trained EEGNet model
%

% clear gpu memory to prevent memory shortage of the gpu
evalc('gpuDevice(1)');

% extract the input dimentions for the input layer
input_samples = read(train_ds);
input_size = size(input_samples{1,1});
num_classes =  numel(categories(input_samples{1,2}));

% define the network layers
layers = [
    sequenceInputLayer(input_size(1:3))
    sequenceFoldingLayer()
    convolution2dLayer([1 64], 8)
    groupedConvolution2dLayer([input_size(1) 1], 2, "channel-wise")
    batchNormalizationLayer()
    eluLayer()
    averagePooling2dLayer([1 4], "Stride", [1 4])
    dropoutLayer(0.25)
    groupedConvolution2dLayer([1 16], 1,"channel-wise","Padding","same")
    convolution2dLayer(1, 16, "Padding", "same")
    batchNormalizationLayer()
    eluLayer()
    averagePooling2dLayer([1 8], "Stride", [1 8], "Padding", "same")
    dropoutLayer(0.25)
    fullyConnectedLayer(20)
    dropoutLayer(0.25)
    sequenceUnfoldingLayer()
    flattenLayer()
    lstmLayer(10, "OutputMode","last")
    fullyConnectedLayer(num_classes)
    softmaxLayer()
    classificationLayer()];

% create a layer graph and connect layers - this is a DAG network
layers = layerGraph(layers);
layers = connectLayers(layers,"seqfold/miniBatchSize","sequnfold/miniBatchSize");

% display the network
analyzeNetwork(layers);

% set some training and optimization parameters - cant use parallel pool
% since we have an LSTMLayer in the network
options = trainingOptions('adam', ...
    'Plots','training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency',my_pipeline.verbose_freq, ...
    'MaxEpochs', my_pipeline.max_epochs, ...
    'MiniBatchSize', my_pipeline.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'ValidationData', val_ds, ...
    'ValidationFrequency', my_pipeline.validation_freq, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropPeriod', my_pipeline.learn_rate_drop_period, ...
    'LearnRateDropFactor', 0.1, ...
    'OutputNetwork', 'last-iteration', ...
    'BatchNormalizationStatistics', 'moving');

% train the network
eegnet_lstm = trainNetwork(train_ds, layers, options);

end