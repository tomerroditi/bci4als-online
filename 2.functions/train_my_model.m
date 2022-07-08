function [model, selected_feat_idx] = train_my_model(algo, constants, train_ds, val_ds)
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
else 
    % extract the features and labels from the data stores
    train_data_labels = readall(train_ds); val_data_labels = readall(val_ds);
    train = train_data_labels(:,1); val = val_data_labels(:,1);
    train_labels = train_data_labels(:,2); val_labels = val_data_labels(:,2);
    
    % convert features and labels from cell arrays into numerical arrays 
    train = cellfun(@(X) permute(X, [5,1,2,3,4]), train, 'UniformOutput', false);
    val = cellfun(@(X) permute(X, [5,1,2,3,4]), val, 'UniformOutput', false);
    train = cell2mat(train); val = cell2mat(val);

    train_labels = cellfun(@(X) double(X), train_labels, 'UniformOutput', true);
    val_labels = cellfun(@(X) double(X), val_labels, 'UniformOutput', true);

    % insert here any feature selection algorithm you would like 
    selected_feat_idx = []; % returning empty for now

    % insert here any model that you would like to try
    model = []; % just return an empty model for now
    

end
warning('on');
end
