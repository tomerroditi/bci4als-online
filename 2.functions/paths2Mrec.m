function multi_rec = paths2Mrec(paths, options, args)
% this function creates a multi recording object from the given paths and
% options
%
% Inputs:
%   paths: a cell array containing the paths of the data files (EEG
%          recordings in XDF format)
%   options: a structure containing the options for the data preprocessing
%
% Output:
%   multi_rec: a multi recording object containing the data from the data
%              paths, preprocessed as specified in options

arguments
    paths
    options
    args.file_type = 'XDF';
end

    % create a waitbar to show progress
    f = waitbar(0, 'preprocessing data, pls wait');
    
    recordings = cell(1,length(paths));
    for i = 1:length(paths)
        waitbar(i/length(paths), f, ['preprocessing data, recording ' num2str(i) ' out of ' num2str(length(paths))]); % update the wait bar
        recordings{i} = recording(paths{i}, options); % crete a class member for each path
    end
    multi_rec = multi_recording(recordings); % create a class member from all paths
    delete(f); %close the wait bar
end