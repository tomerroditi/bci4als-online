classdef path_handler < handle
    properties
        root_path
        eeglab_path
        lab_recorder_path
        liblsls_path
        channel_loc_path
    end

    methods 
        function obj = path_handler()
            % find paths of files
            if exist('eeglab.m', 'file')
                obj.eeglab_path = which('eeglab.m');
                [obj.eeglab_path,~,~] = fileparts(obj.eeglab_path);
            else
                obj.eeglab_path = input('pls insert your full eeglab folder path, for example - "C:\\Users\\eeglab2021.1": ');
            end
            if exist('LabRecorder.exe', 'file')
                obj.lab_recorder_path = which('LabRecorder.exe');
                [obj.lab_recorder_path,~,~] = fileparts(obj.lab_recorder_path);
            else
                obj.lab_recorder_path = input('pls insert your full lab recorder folder path, for example - "C:\\Users\\LabRecorder": ');
            end
            if exist('lsl_loadlib.m', 'file')
                obj.liblsls_path = which('lsl_loadlib.m');
                [obj.liblsls_path,~,~] = fileparts(obj.liblsls_path);
            else
                obj.liblsls_path = input('pls insert your full liblsl folder path, for example - "C:\\Users\\liblsl-Matlab": ');
            end

            obj.channel_loc_path = which('channel_loc.ced'); % chanel location file path  ##### not in use for now #####
            [parent_file_path,~,~] = fileparts(which(mfilename)); % gets the parent folder of the current running code file
            [obj.root_path,~,~] = fileparts(parent_file_path);
        end

        function path = get_root_path(obj)
            path = obj.root_path;
        end
    
        function path = get_eeglab_path(obj)
            path = obj.eeglab_path;
        end
    
        function path = get_lab_recorder_path(obj)
            path = obj.lab_recorder_path;
        end
    
        function path = get_liblsls_path(obj)
            path = obj.liblsls_path;
        end
    end
end





