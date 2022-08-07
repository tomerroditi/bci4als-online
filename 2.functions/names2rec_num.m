function [recorder, num] = names2rec_num(names)
% this function creates the paths for the givven recordings names
%
% Inputs:
%   names: a cell array containing the names of the recordings
%
% Outputs:
%   paths: a cell arrray containing the paths of the givven recordings
%

if isempty(names) % return empty array if names is empty
    recorder = []; num = [];
    return
end
recorder = {};
num = {};
names = cellfun(@(x) split(x,' - '), names, 'UniformOutput', false);
for i = 1:size(names,1)
    if ~ismember(names{i}{1}, recorder)
        recorder{end+1} = names{i}{1};
        num{end+1} = [str2double(names{i}{2})];
        continue
    end
    recorder_idx = ismember(recorder, names{i}{1});
    num{recorder_idx}(end+1) = str2double(names{i}{2});
end
end
