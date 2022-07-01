classdef constants < handle
    % pipeline parameters and constants
    properties (Constant)
        % classes - general, this has to stay conctant! do not change the
        % existing values, if you want you can add new values!
        class_names       = {'Idle', 'Left hand', 'Right hand'}; 
        class_marker      = [1;2;3];

        % classes - training model\recording data, 'class_label' and
        % 'class_name_model' must corespond to each other, meaning the
        % first name matching the first label and so on
        class_label       = [1;2;3];  % the label to use for each class when labeling segments to train a model (DO NOT use -1\0 as a label)
        class_name_model  = {'Idle', 'Left hand', 'Right hand'}; % choose the class names to use when loading recordings
        class_name_rec    = {'Idle', 'Left hand', 'Right hand'};   % choose the class names to use when recording new data

        % hardware 
        sample_rate       = 125;
        
        % buffers size for segmentations (removed after filtering)
        buffer_start      = 2500; % number of samples before segment starts
        buffer_end        = 0;    % number of samples after segment ends 
        
        % recordings setup
        num_trials        = 10; % num of trials per class
        trial_length      = 5;  % duration of each class mark
        start_trail       = 1111;     % start trial marker - DO NOT CHANGE!!!
        start_recordings  = 111; % start recording marker - DO NOT CHANGE!!!
        end_recording     = 99;     % end recording marker - DO NOT CHANGE!!!
        end_trail         = 9;          % end trial marker - DO NOT CHANGE!!!
  
        % filters parameters
        high_freq         = 38;      % BP high cutoff frequency in HZ
        high_width        = 3;       % the width of the transition band for the high freq cutoff
        low_freq          = 4;       % BP low cutoff frequency in HZ
        low_width         = 3;       % the width of the transition band for the low freq cutoff
        notch             = [50, 31.25, 25];      % frequency to implement notch filter
        notch_width       = 0.5;     % the width of the notch filter

        % normalization parameters
        quantiles         = [0.05 0.95]; % quantiles of data to normalize by 
    
        % preprocessing settings and options
        xdf_removed_chan  = [12,13,14,15,16];  % electrodes to remove
        edf_removed_chan  = []

        % augmentation probabilities
        x_flip_p          = 0;   % Xflip
        wgn_p             = 0.3;    % white gaussian noise
    
        % electrodes names and locations
        electrode_num     = [1,2,3,4,5,6,7,8,9,10,11]; % electrode number
        electrode_loc     = {'C3','C4','Cz','FC1','FC2','FC5','FC6','CP1','CP2','CP5','CP6'}; % electrodes location respectivly to electrode num
        electrode_num_edf = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]; % electrode number
        electrode_loc_edf = {'Pz','Cz','T6','T4','F8','P4','C4','F4','Fz','T5','T3','F7','P3','C3','F3'} % electrodes location respectivly to electrode num
    end
    
    properties (GetAccess = public, SetAccess = protected)
        % training options
        verbose_freq           = 100;
        max_epochs             = 60;
        mini_batch_size        = 300;
        validation_freq        = 100;
        learn_rate_drop_period = 50;

        % paths
        eeglab_path
        root_path
        channel_loc_path
        lab_recorder_path
        liblsls_path 

        % gestures recognition
        cool_time       % the minimum time between action executions
        raw_pred_action % the number of predictions in a raw to make an action
        model_thresh    % the model threshold for classification, see the classification function at 'my_bci' function
    end

    
    methods 
        % verify and set important paths for the scripts when constructing a class object
        function obj = constants()
            % find paths of files
            if exist('eeglab.m', 'file')
                obj.eeglab_path = which('eeglab.m');
                [obj.eeglab_path,~,~] = fileparts(obj.eeglab_path);
            else
                obj.eeglab_path = input('pls insert your full eeglab folder path, for example - C:\\Users\\eeglab2021.1: ');
            end
            if exist('LabRecorder.exe', 'file')
                obj.lab_recorder_path = which('LabRecorder.exe');
                [obj.lab_recorder_path,~,~] = fileparts(obj.lab_recorder_path);
            else
                obj.lab_recorder_path = input('pls insert your full lab recorder folder path, for example - C:\\Users\\LabRecorder: ');
            end
            if exist('lsl_loadlib.m', 'file')
                obj.liblsls_path = which('lsl_loadlib.m');
                [obj.liblsls_path,~,~] = fileparts(obj.liblsls_path);
            else
                obj.liblsls_path = input('pls insert your full liblsl folder path, for example - C:\\Users\\liblsl-Matlab: ');
            end

            obj.channel_loc_path = which('channel_loc.ced'); % chanel location file path  ##### not in use for now #####
            [parent_file_path,~,~] = fileparts(which(mfilename)); % gets the parent folder of the current file name
            [obj.root_path,~,~] = fileparts(parent_file_path); % ### need to change this #### assumes that the main folder is the 'grandfather' fodler of the current file
        end

        function set_max_epochs(obj, num_epochs)
            obj.max_num_epochs = num_epochs;
        end

        function set_learn_rate_drop_period(obj, num_epochs)
            obj.learn_rate_drop_period = num_epochs;
        end        
    end
end