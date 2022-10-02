classdef Files_Paths_Handler < handle & matlab.mixin.Copyable
    properties (SetAccess = protected)
        map
        paths
    end

    methods (Access = public)
        function obj = Files_Paths_Handler(recorders, folders_num)
            empty_indices = cellfun(@(X)isempty(X), folders_num);
            recorders(empty_indices) = [];
            folders_num(empty_indices) = [];

            folders_num = cellfun(@sort, folders_num, 'UniformOutput', false);
            if isempty(recorders)
                obj.map = containers.Map();
            else
                obj.map = containers.Map(recorders, folders_num);
            end

            obj.create_paths();
        end

        function bool = isempty(obj)
            if isempty(obj.paths)
                bool = true;
            else
                bool = false;
            end
        end
        
        function paths = get_paths(obj)
            paths = obj.paths;
        end
        
        function reject_path(obj, path, path_idx)
            % to use path_idx set path to []. 
            % for example reject_path([], [1,2]), reject_path([], [0 0 1 0])
            if nargin == 2
                path_idx = strcmp(obj.paths, path);
            end
            obj.paths(path_idx) = [];
        end

        function num_files = get_number_of_files(obj)
            num_files = numel(obj.paths);
        end
    end
    
    methods (Access = protected)
        function create_paths(obj)
            path_handler = Path_Handler();
            obj.paths = {};
            recorders = keys(obj.map);
            folders_num = values(obj.map, recorders);
            % build the paths of the recordings files
            for i = 1:length(recorders)
                curr_folder = fullfile(path_handler.root_path, '3.recordings', recorders{i}); 
                dir_struct = dir(curr_folder);
                names = {dir_struct.name};
                names_no_ext = cellfun(@(X) split(X, '.'), names, 'UniformOutput', false);
                names_no_ext = cellfun(@(X) X{1}, names_no_ext, 'UniformOutput', false);
                for j = 1:length(folders_num{i})
                    file_name_no_ext = num2str(folders_num{i}(j), '%03.f');
                    idx = strcmp(names_no_ext, file_name_no_ext);
                    if ~any(idx)
                        obj.reject_file(recorders{i}, folders_num{i}(j))
                        continue
                    end
                    curr_name = names{idx};
                    curr_path = fullfile(curr_folder, curr_name);
                    obj.paths = cat(1, obj.paths, curr_path);
                end
            end
        end

        function reject_file(obj, recorder, file_num)
            vals = obj.map(recorder);
            vals(vals == file_num) = [];
            if isempty(vals)
                obj.map(recorder) = [];
            else
                obj.map(recorder) = vals;
            end
            disp(['The recording file ' recorder ' - '  num2str(file_num) ' does not exist,' newline...
                    'it has been removed from the file path handler']);
        end
    end

    methods (Static)
        function name = path_to_name(path)
                strs = split(path, '\');
                name = [strs{end - 1} ' - ' strs{end}(1:end - 4)];
        end
    end
end