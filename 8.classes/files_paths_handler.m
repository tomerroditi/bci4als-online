classdef files_paths_handler < handle
    properties
        paths = {};
        recorders
        folders_num
    end

    methods (Access = public)
        function obj = files_paths_handler(recorders, folders_num)
            obj.recorders = recorders;
            obj.folders_num = folders_num;
            
            obj.create_file_paths();
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
    end
    
    methods (Access = protected)
        function create_file_paths(obj)            
            % some sorting - very important for the big data data store construction to
            % be aligned with the stored true labels 
            obj.folders_num = cellfun(@sort, obj.folders_num, 'UniformOutput', false);
            [obj.recorders, I] = sort(obj.recorders); % sort the names
            obj.folders_num = obj.folders_num(I); % sort numbers according to names

            % build the paths of the recordings files
            for i = 1:length(obj.recorders)
                for j = 1:length(obj.folders_num{i})
                    path = fullfile('3.recordings', strcat(obj.recorders{i}), num2str(obj.folders_num{i}(j), '%03.f'));
                    obj.paths{end + 1} = path;
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