function data_paths = create_paths(recorders, folders_num)
% this function creates paths to the desired recordings files and labels
%
% Inputs:
%   recorders: a cell array with the recorders names
%   folders_num: a cell array with numerical arrays containing the numbers
%                of the desired recordings for each recorder
%
% Outputs:
%   data_paths: a cell array with all the paths to the desired recordings
%


% return an empty array if recordings are not provided
empty_flag = 1;
for i = 1:length(folders_num)
    if ~isempty(folders_num{i})
        empty_flag = 0;
        break
    end
end
if empty_flag
    data_paths = [];
    return
end

% get the local path of the project folder
root_path = which("create_paths");
root_path = split(root_path, {'\','/'});
root_path = root_path(1:end - 2);
if isunix
    root_path = strjoin(root_path, '/'); 
else
    root_path = strjoin(root_path, '\'); 
end


counter = 0;
% some sorting - very important for the big data data store construction to
% be aligned with the stored true labels 
folders_num = cellfun(@sort, folders_num, 'UniformOutput', false);
[recorders, I] = sort(recorders); % sort the names
folders_num = folders_num(I); % sort numbers according to names
% build the paths of the recordings files
for i = 1:length(recorders)
    for j = 1:length(folders_num{i})
        counter = counter + 1;
        path = fullfile(root_path, '3.recordings', strcat(recorders{i}), num2str(folders_num{i}(j),'%03.f'));
        data_paths{counter} = path; %#ok<AGROW> 
    end
end
end