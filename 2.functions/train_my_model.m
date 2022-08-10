function [model, selected_feat_idx, DL_flag] = train_my_model(algo, my_pipeline, train_ds, val_ds)
% this function trains a model and select features if required
% Inputs:
%   algo: the algorithm to create the model
%   constants: a Constants object matching the recordings that are used
%   train\val_ds: a datastore for training\validation data
%
% Outputs:
%   model: the trained model
%   selected_feat_idx: the selected features indices if the model is
%                      feature dependent
%

warning('off'); % supress warnings print

% check what DL pipelines are available in the folder "4.DL pipelines"
DL_pipe = dir([my_pipeline.root_path '\4.DL pipelines']);
DL_pipe_names = extractfield(DL_pipe, 'name');

% train the desired model 
if ismember([algo '.m'], DL_pipe_names) % DL models
    model = eval([algo '(train_ds, val_ds, my_pipeline);']); % this will call the DL pipeline
    selected_feat_idx = []; % we currently use none feature NN
    DL_flag = true;
else % classic ml models
    error('classic ml is not supported yet, pls use a valid DL pipeline name')
    % convert data store into data set - not supporting big data!
    [train, train_labels] = ds2set(train_ds);
    [val, val_labels] = ds2set(val_ds);

    % notice that dim 5 in feature mat is for trials! change it if
    % you like so ussing permute...

    % insert here any feature selection algorithm you would like 
    selected_feat_idx = feature_selection(train, train_labels); 

    % insert here any model that you would like to try
    model = []; % just return an empty model for now
    DL_flag = false;
end
warning('on');
end
