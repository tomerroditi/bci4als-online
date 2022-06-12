classdef constants < handle
    % pipeline parameters and constants
    properties (Constant)
        % general settings - DO NOT CHANGE THEM UNLESS YOU WORK ON A DIFFERENT PROBLEM!
        N_CLASSES                  = 3;
        IDLE_LABEL                 = 1; % DO NOT CHANGE THIS
        LEFT_LABEL                 = 2; % DO NOT CHANGE THIS
        RIGHT_LABEL                = 3; % DO NOT CHANGE THIS
        SAMPLE_RATE                = 125;
        
        % buffers size for segmentations (removed after filtering)
        BUFFER_START               = 2500; % number of samples before segment starts
        BUFFER_END                 = 0;    % number of samples after segment ends 
        
        % new recording settings
        TRIALS_PER_CLASS           = 10; % num of examples per class
        TRIAL_LENGTH               = 5;  % duration of each class mark
    
        % filters parameters
        HIGH_FREQ       = 38;      % BP high cutoff frequency in HZ
        HIGH_WIDTH      = 3;       % the width of the transition band for the high freq cutoff
        LOW_FREQ        = 4;       % BP low cutoff frequency in HZ
        LOW_WIDTH       = 3;       % the width of the transition band for the low freq cutoff
        NOTCH           = 50;      % frequency to implement notch filter
        NOTCH_WIDTH     = 0.5;     % the width of the notch filter

        % normalization parameters
        quantiles = [0.05 0.95]; % quantiles of data to normalize by 
    
        % preprocessing settings and options
        xdf_removed_chan = [12,13,14,15,16];  % electrodes to remove
        edf_removed_chan = []

        % augmentation probabilities
        x_flip_p = 0;   % Xflip
        wgn_p = 0       % white gaussian noise
    
        % training options
        VerboseFrequency = 50;
        MaxEpochs =  500;
        MiniBatchSize = 150;
        ValidationFrequency =  50;
    
        % electrodes names and locations
        electrode_num = [1,2,3,4,5,6,7,8,9,10,11]; % electrode number
        electrode_loc = {'C3','C4','Cz','FC1','FC2','FC5','FC6','CP1','CP2','CP5','CP6'}; % electrodes location respectivly to electrode num
        electrode_num_edf = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]; % electrode number
        electrode_loc_edf = {'Pz','Cz','T6','T4','F8','P4','C4','F4','Fz','T5','T3','F7','P3','C3','F3'} % electrodes location respectivly to electrode num
    end
    
    % usefull paths settings
    properties (Access = public)
        eeglab_path
        root_path
        channel_loc_path
        lab_recorder_path
        liblsls_path   
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
    end
end