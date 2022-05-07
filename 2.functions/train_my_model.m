function [model, selected_feat_idx] = train_my_model(algo, constants, options)
% this function trains a model and returns it
%
% Inputs:
%   algo: the algorithm to create the model
%   options: a set of optional parameters
%       - train\val_ds: a datastore for training\validation data
%       - features: matrix containing the features
%       - labels: a vector with labels coresponding to the 'features'
%                 matrix
%       - save: save flag
%       - save_path: a string representing the path to save the model in
%
% Outputs:
%   model: the trained model
%   selected_feat_idx: the selected features indices if the model is
%                      feature dependent
%

arguments
    algo
    constants
    options.train_ds = [];
    options.val_ds = [];
    options.features = [];
    options.labels = [];
    options.save = false;
    options.save_path = '';
end

warning('off');

% train the desired model
if strcmp(algo, 'EEGNet')
    model = EEGNet(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_stft')
    model = EEGNet_stft(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEG_AE')
    model = eeg_AE(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_lstm')
    model = EEGNet_lstm(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_bilstm')
    model = EEGNet_bilstm(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_gru')
    model = EEGNet_gru(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_lstm_stft')
    model = EEGNet_lstm_stft(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_bilstm_stft')
    model = EEGNet_bilstm_stft(options.train_ds, options.val_ds, constants);
elseif strcmp(algo, 'EEGNet_gru_stft')
    model = EEGNet_gru_stft(options.train_ds, options.val_ds, constants);
else
    [selected_feat_idx]  = MI5_feature_selection(options.features, options.labels);
    options.features = options.features(:,selected_feat_idx);
    MI6_LearnModel(options.features, options.labels, algo, options.save);   
end

warning('on');
end
