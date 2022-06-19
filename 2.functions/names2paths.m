function paths = names2paths(names)
% this function creates the paths for the givven recordings names
%
% Inputs:
%   names: a cell array containing the names of the recordings
%
% Outputs:
%   paths: a cell arrray containing the paths of the givven recordings
%

if isempty(names) % return empty array if names is empty
    paths = [];
    return
end

C = constants();
root_path = C.root_path;
names = cellfun(@(x) split(x,' - '), names, 'UniformOutput', false);
paths = cellfun(@(X) fullfile(root_path, '3.recordings',['rec_' X{1}], X{2}), names, 'UniformOutput', false);
end
