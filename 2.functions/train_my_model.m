function [model, selected_feat_idx, DL_flag] = train_my_model(algo, constants, train_ds, val_ds)
% this function trains a model and select features if required
%
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
DL_pipe = dir([constants.root_path '\4.DL pipelines']);
DL_pipe_names = extractfield(DL_pipe, 'name');

% train the desired model 
if ismember([algo '.m'], DL_pipe_names)
    model = eval([algo '(train_ds, val_ds, constants);']); % this will call a DL pipeline
    selected_feat_idx = [];
    DL_flag = true;
else 
    % convert data store into data set
    [train, train_labels] = ds2set(train_ds);
    [val, val_labels] = ds2set(val_ds);

    % insert here any feature selection algorithm you would like 
    selected_feat_idx = []; % returning empty for now

    % insert here any model that you would like to try
    model = []; % just return an empty model for now
    DL_flag = false;
end
warning('on');
end
