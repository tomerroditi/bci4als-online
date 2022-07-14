function eegnet_lstm_stft = EEGNet_lstm_stft(train_ds, val_ds, constants)
% this function generate and train the Deep network presented in the paper 
% "EEGNet: A Compact Convolutional Neural Network for EEG-based 
% Brain-Computer Interfaces", with an additional bilstm kayer, and returns
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
%   eegnet_bilstm: the trained EEGNet model
%

% extract the input dimentions for the input layer
input_samples = read(train_ds);
input_size = size(input_samples{1,1});
num_classes = length(unique(cellfun(@(X)double(X), input_samples(:,2))));

% input_size = [11, 300, 1, 4];
% num_classes = 3;

% define the network layers
layers_input = [    
    sequenceInputLayer(input_size(1:3))
    sequenceFoldingLayer()];

layers_CNN = [
    convolution2dLayer([1 64], 8, "Padding","same", 'Name', 'conv1')
    batchNormalizationLayer()
    groupedConvolution2dLayer([input_size(1) 1], 2, 'channel-wise')
    batchNormalizationLayer()
    eluLayer(1)
    averagePooling2dLayer([1 4], "Stride", [1 4])
    dropoutLayer(0.5)
    groupedConvolution2dLayer([1 16], 1, 'channel-wise', "Padding","same")
    convolution2dLayer([1 1], 16, "Padding", "same")
    batchNormalizationLayer()
    eluLayer(1)
    averagePooling2dLayer([1 8], "Stride", [1 8])
    dropoutLayer(0.5)
    sequenceUnfoldingLayer(Name = 'sequnfold1')
    flattenLayer('Name', 'flatten1')];

layers_stft = [
    PermuteStftLayer(Name = 'Permute')
    stftLayer('Window', rectwin(128), 'OverlapLength', 100,"OutputMode", "spatial")
    dropoutLayer(0.25)
    groupedConvolution2dLayer([65 1], 4, 'channel-wise') % window_size/2 + 1 = N_DFT_points
    batchNormalizationLayer()
    eluLayer(1)
    convolution2dLayer([1 4], 8, 'Padding','same','Stride', [1 2])
    batchNormalizationLayer()
    eluLayer(1)
    averagePooling2dLayer([1 2], "Stride", [1 2])
    dropoutLayer(0.25)
    sequenceUnfoldingLayer(Name = 'sequnfold2')
    flattenLayer("Name", 'flatten2')];

layers_lstm = [
    concatenationLayer(1,2, Name = 'concat')
    lstmLayer(128, "OutputMode","last")
    dropoutLayer(0.25)
    fullyConnectedLayer(num_classes)
    softmaxLayer()
    classificationLayer()];

% create a layer graph and connect layers - this is a DAG network
layers = layerGraph();
layers = addLayers(layers, layers_input);
layers = addLayers(layers, layers_stft);
layers = addLayers(layers, layers_CNN);
layers = addLayers(layers, layers_lstm);
layers = connectLayers(layers, "seqfold/out", "Permute");
layers = connectLayers(layers, "seqfold/out", "conv1");
layers = connectLayers(layers, "seqfold/miniBatchSize", "sequnfold1/miniBatchSize");
layers = connectLayers(layers, "seqfold/miniBatchSize", "sequnfold2/miniBatchSize");
layers = connectLayers(layers, "flatten1", "concat/in1");
layers = connectLayers(layers, "flatten2", "concat/in2");

% display the network
analyzeNetwork(layers);

% set some training and optimization parameters - cant use parallel pool
% since we have an LSTMLayer in the network
options = trainingOptions('adam', ...
    'Plots','training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency',constants.verbose_freq, ...
    'MaxEpochs', constants.max_epochs, ...
    'MiniBatchSize', constants.mini_batch_size, ...  
    'Shuffle','every-epoch', ...
    'ValidationData', val_ds, ...
    'ValidationFrequency', constants.validation_freq, ...
    'LearnRateSchedule', 'piecewise',...
    'LearnRateDropPeriod', constants.learn_rate_drop_period,...
    'LearnRateDropFactor', 0.1,...
    'OutputNetwork', 'last-iteration');

% train the network
eegnet_lstm_stft = trainNetwork(train_ds, layers, options);

end