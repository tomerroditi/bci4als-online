function alexnet = alexnet(train_ds, val_ds, constants)
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

% ##### the weights data is to heavy for git so it needs to be changed to
% load the trained alexnet from matlab instead from local file #####

% reset gpu to prevent limited gpu memory
disp('clearing gpu memory - this might take a while.. thank you for being patient')
evalc('gpuDevice(1)');
disp('gpu memory is cleared!')

% extract the number of classes
input_samples = readall(train_ds);
% data = cellfun(@(X) permute(X,[4 1 2 3]), input_samples(:,1), 'UniformOutput', false);
% data = permute(cell2mat(data), [2 3 4 1]);
% data_mean = mean(data, 4);
num_classes = length(unique(cellfun(@(X)double(X), input_samples(:,2))));

% load parameters of pre trained network
params = load("C:\Users\tomer\Desktop\ALS\project\4.DL pipelines\params_2022_06_01__23_19_02.mat");

% construct the network with its initial parameters
layers = [
    imageInputLayer([227 227 3],"Name","data","Mean",params.data.Mean)
    convolution2dLayer([11 11],96,"Name","conv1","BiasLearnRateFactor",2,"Stride",[4 4],"Bias",params.conv1.Bias,"Weights",params.conv1.Weights, "WeightLearnRateFactor", 1)
    reluLayer("Name","relu1")
    crossChannelNormalizationLayer(5,"Name","norm1","K",1)
    maxPooling2dLayer([3 3],"Name","pool1","Stride",[2 2])
    groupedConvolution2dLayer([5 5],128,2,"Name","conv2","BiasLearnRateFactor",2,"Padding",[2 2 2 2],"Bias",params.conv2.Bias,"Weights",params.conv2.Weights, "WeightLearnRateFactor", 1)
    reluLayer("Name","relu2")
    crossChannelNormalizationLayer(5,"Name","norm2","K",1)
    maxPooling2dLayer([3 3],"Name","pool2","Stride",[2 2])
    convolution2dLayer([3 3],384,"Name","conv3","BiasLearnRateFactor",2,"Padding",[1 1 1 1],"Bias",params.conv3.Bias,"Weights",params.conv3.Weights, "WeightLearnRateFactor", 1)
    reluLayer("Name","relu3")
    groupedConvolution2dLayer([3 3],192,2,"Name","conv4","BiasLearnRateFactor",2,"Padding",[1 1 1 1],"Bias",params.conv4.Bias,"Weights",params.conv4.Weights, "WeightLearnRateFactor", 1)
    reluLayer("Name","relu4")
    groupedConvolution2dLayer([3 3],128,2,"Name","conv5","BiasLearnRateFactor",2,"Padding",[1 1 1 1],"Bias",params.conv5.Bias,"Weights",params.conv5.Weights, "WeightLearnRateFactor", 1)
    reluLayer("Name","relu5")
    maxPooling2dLayer([3 3],"Name","pool5","Stride",[2 2])
    fullyConnectedLayer(4096,"Name","fc6","BiasLearnRateFactor",2,"Bias",params.fc6.Bias,"Weights",params.fc6.Weights)
    reluLayer("Name","relu6")
    dropoutLayer(0.5,"Name","drop6")
    fullyConnectedLayer(4096,"Name","activations","BiasLearnRateFactor",2,"Bias",params.fc7.Bias,"Weights",params.fc7.Weights)
    reluLayer("Name","relu7")
    dropoutLayer(0.5,"Name","drop7")
    fullyConnectedLayer(num_classes,"Name","fc8", "WeightLearnRateFactor", 10)
    softmaxLayer("Name","prob")
    classificationLayer("Name","output")];

% set some training and optimization parameters
options = trainingOptions('adam', ...
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
alexnet = trainNetwork(train_ds, layers, options);

end





