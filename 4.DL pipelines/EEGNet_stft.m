function eegnet_stft = EEGNet_stft(train_ds, val_ds, constants)
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
%
% Output:
%   eegnet: the trained EEGNet model
%

% extract the input dimentions for the input layer
input_samples = readall(train_ds);
input_size = size(input_samples{1,1});

% shift the data dimentions to match the input layer of sequential/image input 
% layer - hXwXcXn (height,width,channels,number of images)
if length(input_size) < 3
    input_size = [input_size, 1];
end

% define the network layers
layers = [
    imageInputLayer(input_size, 'Normalization','none', 'Name', 'input')
    convolution2dLayer([1 64],8,"Padding","same")
    batchNormalizationLayer
    groupedConvolution2dLayer([input_size(1) 1],2,"channel-wise")
    batchNormalizationLayer
    eluLayer
    averagePooling2dLayer([1 4],"Stride",[1 4])
    dropoutLayer(0.5)
    groupedConvolution2dLayer([1 16],1,"channel-wise","Padding","same")
    convolution2dLayer(1,16,"Padding","same")
    batchNormalizationLayer
    eluLayer
    averagePooling2dLayer([1 8],"Stride",[1 8])
    dropoutLayer(0.25, 'Name', 'drop1')];

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
    dropoutLayer(0.25, 'Name', 'drop2')];

layers_out = [
        flat_cat('Name', 'flatten')
        fullyConnectedLayer(3)
        softmaxLayer
        classificationLayer];

layers = layerGraph(layers);
layers = addLayers(layers, layers_stft);
layers = addLayers(layers, layers_out);
layers = connectLayers(layers, "input", "Permute");
layers = connectLayers(layers, "drop1", "flatten/in1");
layers = connectLayers(layers, "drop2", "flatten/in2");


% display the network
% analyzeNetwork(layers)

% set some training and optimization parameters
options = trainingOptions('adam', ...
    'Plots','training-progress', ...
    'Verbose', true, ...
    'VerboseFrequency',constants.VerboseFrequency, ...
    'MaxEpochs', 1500, ...
    'MiniBatchSize', size(input_samples,1), ...  % we have a small data set so we can feed the network all at one time
    'Shuffle','every-epoch', ...
    'ValidationData', val_ds, ...
    'ValidationFrequency', constants.ValidationFrequency, ...
    'ValidationPatience', 15,...
    'LearnRateSchedule', 'piecewise',...
    'LearnRateDropPeriod', 500,...
    'LearnRateDropFactor', 0.1,...
    'OutputNetwork', 'last-iteration');

% train the network
eegnet_stft = trainNetwork(train_ds, layers, options);

end