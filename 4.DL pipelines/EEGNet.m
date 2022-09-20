function eegnet = EEGNet(train_ds, val_ds, my_pipeline)
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

% clear gpu memory to prevent memory shortage of the gpu
evalc('gpuDevice(1)');

% extract the input dimentions for the input layer
input_samples = read(train_ds);
input_size = size(input_samples{1,1});
num_classes =  numel(categories(input_samples{1,2}));

% correct the 'input_size' dimentions to match the input layer of image input 
% layer - hXwXcXn (height,width,channels), since we always has 1 channel it
% doesnt apear in 'input_size' and we have to manually add it
if length(input_size) == 2
    input_size = [input_size, 1];
end

% define the network layers
layers = [
    imageInputLayer(input_size, 'Normalization', 'none')
    convolution2dLayer([1 64], 8)
    groupedConvolution2dLayer([input_size(1) 1], 2,"channel-wise")
    batchNormalizationLayer
    eluLayer
    averagePooling2dLayer([1 4],"Stride",[1 4])
    dropoutLayer(0.25)
    groupedConvolution2dLayer([1 16], 1,"channel-wise","Padding","same")
    convolution2dLayer(1, 16, "Padding", "same")
    batchNormalizationLayer
    eluLayer
    averagePooling2dLayer([1 8],"Stride",[1 8], "Name", 'activations')
    dropoutLayer(0.25)
    fullyConnectedLayer(num_classes)
    softmaxLayer
    classificationLayer];

% display the network
% analyzeNetwork(layers)

% set some training and optimization parameters
options = trainingOptions('adam'...
    ,'Plots','training-progress'...
    ,'Verbose', true...
    ,'VerboseFrequency',my_pipeline.verbose_freq...
    ,'MaxEpochs', my_pipeline.max_epochs...
    ,'MiniBatchSize', my_pipeline.mini_batch_size...  
    ,'Shuffle','every-epoch'...
    ,'ValidationData', val_ds...
    ,'ValidationFrequency', my_pipeline.validation_freq...
    ,'LearnRateSchedule', 'piecewise'...
    ,'LearnRateDropPeriod', my_pipeline.learn_rate_drop_period...
    ,'LearnRateDropFactor', 0.1...
    ,'OutputNetwork', 'last-iteration'...
    ,'BatchNormalizationStatistics', 'moving'...
    ,'DispatchInBackground', false);

% train the network
eegnet = trainNetwork(train_ds, layers, options);

end