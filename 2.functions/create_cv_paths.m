function [train_paths, val_paths, test_paths] = create_cv_paths(K, val_test_ratio)
% this function creates path to the data of specific recordings. It splits
% the recordings to train, validation and test according to the number of
% folds (K) which dictates the split to train and test&validation, and the
% ratio between validation and test ().
%
% Inputs:
%   K: How many folds to use? splits the recordings to train and
%   validation&test.
%   val_test_ratio: Dictates the ration between the size of the validation
%   and test sets that were left after splitting the overall recorings to
%   train and valdation&test.
%
% outputs:
%   train_paths: A cell array of folds, containing cell arrays of the paths to the recordings of
%   each recorder that were assigned ot the train set.
%   val_paths: A cell array of folds, containing cell arrays of the paths to the recordings of
%   each recorder that were assigned ot the validation set.
%   test_paths: A cell array of folds, containing cell arrays of the paths to the recordings of
%   each recorder that were assigned ot the test set.


    %% select folders to aggregate data from
    recorders = {'tomer', 'omri', 'nitay','itay'}; % people we got their recordings

    % list all usable recordings
    % apperantly we have bad recordings from tomer
    % currently bad recordings from tomer: [1,2] 
    recs_per_recorder = [17, 6,0,3];
    cum_sum_rec_idx = cumsum(recs_per_recorder);
    all_usable_recs_n = cum_sum_rec_idx(end);
    rec_idx = 1:all_usable_recs_n;
    % create the folds for train vs (valdiation + test)
    cv_train = cvpartition(all_usable_recs_n,'KFold',K); 
    % calculate the size of the validation and test sets (in 'recording'
    % units)
    val_size = floor(val_test_ratio * cv_train.TestSize);
    test_size =  cv_train.TestSize - val_size;
    % iterate over the folds, to create the paths
    for foldInd = 1:K
        % get the indexes relevant for training and derieve the validation
        % and test indexes accordingly
        trainIdx = training(cv_train,foldInd);
        valtestIdx = test(cv_train,foldInd);
        % we split the validation&test according to the ratio
        % first get which recordings belong to valdiation&test
        valtestlocs = find(valtestIdx);
        % randomize which ones will be considered as valdiation set
        rndValLocs = valtestlocs(randperm(length(valtestlocs)));
        rndValLocs = rndValLocs(1:val_size(foldInd));
        valIdx = valtestIdx;
        % reset all test indexes
        valIdx(setdiff(1:end, rndValLocs)) = 0; 
        testIdx = valtestIdx;
        % reset all validation indexes
        testIdx(valIdx) = 0;
        % iterate  over recorders to be aligned with Tomer's format (a cell
        % array of arrays, each containing the index for a specific
        % recorder (not an accumulating index over recorders)
        for recorderInd = 1:length(recorders)
            % we keep track of the cum sum, to remove offsets of indexes
            cum_sum_current = cum_sum_rec_idx(recorderInd);
            % hande specific case of first iteration
            if recorderInd == 1
                cum_sum_last = 0;
                cur_idx = 1:cum_sum_current;
            else    
                cum_sum_last = cum_sum_rec_idx(recorderInd - 1);
                cur_idx = (cum_sum_last + 1) :cum_sum_current;
            end
            % get the raw indexes across subjects
            raw_cur_idx = rec_idx(cur_idx);
            % fit each set indexes to its place, according to the current
            % recorder
            train_folders_num{recorderInd} = raw_cur_idx(trainIdx(cur_idx)) - cum_sum_last;
            val_folders_num{recorderInd} = raw_cur_idx(valIdx(cur_idx)) - cum_sum_last;
            test_folders_num{recorderInd} = raw_cur_idx(testIdx(cur_idx))- cum_sum_last;
        end
        % create the paths for each set
        train_paths{foldInd}= create_paths(recorders, train_folders_num);
        val_paths{foldInd} = create_paths(recorders, val_folders_num);
        test_paths{foldInd} = create_paths(recorders, test_folders_num);
    end
end