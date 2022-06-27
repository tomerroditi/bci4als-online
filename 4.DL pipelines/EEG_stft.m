function eeg_stft = EEG_stft(train_ds, val_ds, constants)
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

% clear gpumemory
evalc('gpuDevice(1)');

% extract the input dimentions for the input layer
input_samples = readall(train_ds);
input_size = size(input_samples{1,1});
num_classes = length(unique(constants.class_label));

% correct the 'input_size' dimentions to match the input layer of image input 
% layer - hXwXcXn (height,width,channels), since we always has 1 channel it
% doesnt apear in 'input_size' and we have to manually add it
input_size = [input_size, 1];

% define the network layers
layers_stft = [
    imageInputLayer(input_size, 'Normalization','none')
    PermuteStftLayer(Name = 'Permute')
    stftLayer('Window', rectwin(128), 'OverlapLength', 100,"OutputMode", "spatial", "WeightLearnRateFactor", 0)
    dropoutLayer(0.25)
    groupedConvolution2dLayer([20 4], 2, 'channel-wise', 'Stride', [10 2], 'Padding', 'same') % window_size/2 + 1 = N_DFT_points
    batchNormalizationLayer()
    eluLayer(1)
    reshape_c_dim(2)
    dropoutLayer(0.5)
    groupedConvolution2dLayer([3,3], 2, input_size(1))
    batchNormalizationLayer()
    eluLayer(1)
    averagePooling2dLayer([2 2], "Stride", [2 2], "Padding", "same")
    dropoutLayer(0.5)
    fullyConnectedLayer(num_classes)
    softmaxLayer
    classificationLayer];


layers = layerGraph(layers_stft);

% display the network
% analyzeNetwork(layers)

% set some training and optimization parameters
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
eeg_stft = trainNetwork(train_ds, layers, options);

end