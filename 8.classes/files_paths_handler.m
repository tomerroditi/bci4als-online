classdef files_paths_handler < handle
    properties
        map
    end

    methods (Access = public)
        function obj = files_paths_handler(recorders, folders_num)
            empty_indices = cellfun(@(X)isempty(X), folders_num);
            recorders(empty_indices) = [];
            folders_num(empty_indices) = [];

            folders_num = cellfun(@sort, folders_num, 'UniformOutput', false);
            if isempty(recorders)
                obj.map = containers.Map();
            else
                obj.map = containers.Map(recorders, folders_num);
            end
        end

        function reject_file(obj, file_path)
            strs = split(file_path, '\');
            recorder = strs{end - 1}; 
            folder_num = str2double(strs{end});
            
            values = obj.map(recorder);
            values = values(values ~= folder_num);

            obj.map(recorder) = values;
        end

        function bool = isempty(obj)
            paths = obj.get_paths();
            if isempty(paths)
                bool = true;
            else
                bool = false;
            end
        end
        
        function paths = get_paths(obj)
            paths = obj.create_file_paths();
        end
    end
    
    methods (Access = protected)
        function paths = create_file_paths(obj) 
            paths = {};
            recorders = keys(obj.map);
            folders_num = values(obj.map, recorders);
            % build the paths of the recordings files
            for i = 1:length(recorders)
                for j = 1:length(folders_num{i})
                    curr_path = fullfile('3.recordings', strcat(recorders{i}), num2str(folders_num{i}(j), '%03.f'));
                    paths = cat(1, paths, curr_path);
                end
            end
        end
    end

    methods (Static)
        function name = path_to_name(path)
                strs = split(path, '\');
                name = [strs{end - 1} ' - ' strs{end}];
        end
    end
end