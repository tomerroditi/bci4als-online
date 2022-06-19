function [train_paths, test_paths] = create_cv_paths(recorders, folders_num, K)
% this function creates path to the data of specific recordings. It splits
% the recordings to train, validation and test according to the number of
% folds (K) which dictates the split to train and test&validation, and the
% ratio between validation and test ().
%
% Inputs:
%   recorders: a cell containing the names of the recorders
%   folders_num: a cell containing the recording number for each recorder,
%                matching the names in 'recorders'
%   K: How many folds to use? splits the recordings to train and
%      validation&test.
%
%
% outputs:
%   train_paths: A cell array containing cell arrays of the training data paths for each fold
%   val_paths: A cell array containing cell arrays of the validation data paths for each fold
%

    % create paths for all recordings
    data_paths = create_paths(recorders, folders_num);

    % preallocate memory for partitioned paths
    train_paths = cell(1,K);
    test_paths = cell(1,K);

    % create the cross validation partition
    C = cvpartition(length(data_paths),'KFold',K); % we will use the regresion partition since recordings dont have a class

    % create the k-folds from all the paths
    for i = 1:K
        train_paths{i} = data_paths(training(C,i));
        test_paths{i} = data_paths(test(C,i));
    end
end