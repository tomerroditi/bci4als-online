function multi_rec = paths2Mrec(paths, my_pipeline)
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

    if isempty(paths)
        multi_rec = multi_recording();
        return
    end
    
    f = waitbar(0, 'preprocessing data, pls wait'); % create a waitbar to show progress
    multi_rec = multi_recording(); % empty multi recording object
    for i = 1:length(paths)
        waitbar(i/length(paths), f, ['preprocessing data, recording ' num2str(i) ' out of ' num2str(length(paths))]); % update the wait bar
        rec = recording(paths{i}, my_pipeline); % create a class member for each path
        multi_rec.append_rec(rec);
    end
    delete(f); %close the wait bar
end