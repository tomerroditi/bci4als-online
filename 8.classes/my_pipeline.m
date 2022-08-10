classdef my_pipeline < handle
    % pipeline parameters and general constants object
    properties (GetAccess = public, SetAccess = protected)
        % classes, their markers and labels
        class_names       = {'Idle', 'Left hand', 'Right hand'}; % classes names - unspecify classes will be labeled as
                                                                 % idle if they exist in the recording
        class_marker      = cellstr(num2str([1;2;3], '%#.16g')); % each class markers in the recording files,
                                                                 % its possible to give more than 1 marker for 
                                                                 % a certain class - use a cell of char instead of a char
        class_label       = [1;2;3];  % the label to use for each class when labeling segments,
                                      % DO NOT use 0 as a label, use -1 to completely reject the class.
                                      
        % markers parameters
        start_recordings  = num2str(111, '%#.16g');   % start recording marker
        end_recording     = num2str(99, '%#.16g');    % end recording marker
        end_trail         = num2str(9, '%#.16g');     % end trial marker 
  
        % model related parameters
        model_algo        = 'EEGNet'; % ML model to train, choose from the files in the DL pipelines folder
                    % features or segments - what data to use for model trainig
        feat_or_data      = 'data'; % specify if you desire to extract data or features, choose from {'data', 'feat'}
        feat_alg          = 'none'; % feature extraction algorithm, choose from {'basic', 'wavelet'}

        % segmentation related parameters
        cont_or_disc      = 'continuous'; % segmentation type choose from {'discrete', 'continuous'}
            % discrete only
        pre_start         = 0.5; % duration in seconds to include in segments before the start marker
        post_start        = 1.5; % duration in seconds to include in segments after the start marker
            % continuous only
        seg_dur           = 4;   % duration in seconds of each segment
        overlap           = 3.5; % duration in seconds of following segments overlapping
        sequence_len      = 1;   % number of segments in a sequence (for sequential DL models)
        sequence_overlap  = 1;   % duration in seconds of overlap between following segments in a sequence
        threshold         = 0.7; % threshold for labeling - percentage of the segment containing the class (only values from 0-1 range)
        
        % hardware 
        sample_rate       = 125; % the sample rate of the headset
        
        % buffers size for segmentations - this is used to prevent inclusion
        % of the unstable part of the filtered signal in the final segments
        % (removed after filtering)
        buffer_start      = 2500; % number of samples before segment starts
        buffer_end        = 0;    % number of samples after segment ends 
        
        % filters parameters
        high_freq         = 38;      % BP high cutoff frequency in HZ
        high_width        = 3;       % the width of the transition band for the high freq cutoff
        low_freq          = 7;       % BP low cutoff frequency in HZ
        low_width         = 3;       % the width of the transition band for the low freq cutoff
        notch             = [50, 31.25, 25];% frequency to apply notch filter on
        notch_width       = 0.5;     % the width of the notch filter
        
        % preprocess algorithms - implemented in the filtering function
        eog_artifact  = false;  % true - removes EOG\emg artifacts, flase - dont remove EOG\emg artifacts
        avg_reference = false;  % true - re reference electrodes to cz, false - dont re reference

        % normalization parameters
        quantiles         = [0.05 0.95]; % quantiles of data to normalize by 
    
        % preprocessing settings and options
        removed_chan  = [12,13,14,15,16];  % electrodes to remove

        % augmentations probabilities - double in range 0-1
        x_flip_p          = 0;    % Xflip
        wgn_p             = 0.9;  % white gaussian noise
    
        % electrodes names and locations
        electrode_num     = [1,2,3,4,5,6,7,8,9,10,11]; % electrode number
        electrode_loc     = {'C3','C4','Cz','FC1','FC2','FC5','FC6','CP1','CP2','CP5','CP6'}; % electrodes location respectivly to electrode num

        % DL model training options parameters - used in the DL pipelines
        verbose_freq           = 100;
        max_epochs             = 50;
        mini_batch_size        = 300;
        validation_freq        = 100;
        learn_rate_drop_period = 45;

        % usefull paths
        root_path
        eeglab_path
        lab_recorder_path
        liblsls_path
        channel_loc_path
    end

    methods 
        % verify and set important paths for the scripts when constructing a class object
        function obj = my_pipeline(varargin)
            % set the given optional inputs as the object properties
            for n = 1:2:size(varargin,2)
                switch varargin{n}
                    case 'model_algo'
                        obj.model_algo = varargin{n+1};
                    case 'cont_or_disc'
                        obj.cont_or_disc = varargin{n+1};
                    case 'feat_or_data'
                        obj.feat_or_data = varargin{n+1};
                    case 'feat_alg' 
                        obj.feat_alg = varargin{n+1};
                    case 'pre_start'
                        obj.pre_start = varargin{n+1};
                    case 'post_start'
                        obj.post_start = varargin{n+1};
                    case 'overlap'
                        obj.overlap = varargin{n+1};
                    case 'seg_dur'
                        obj.seg_dur = varargin{n+1};
                        if obj.overlap == 0
                            obj.overlap = obj.seg_dur - 0.5;
                        end
                    case 'sequence_len' 
                        obj.sequence_len = varargin{n+1};
                    case 'sequence_overlap'
                        obj.sequence_overlap = varargin{n+1};
                    case 'threshold'
                        obj.threshold = varargin{n+1};
                    case 'class_names'
                        obj.class_names = varargin{n+1};
                    case 'class_marker' 
                        obj.class_marker = varargin{n+1};
                    case 'class_label'
                        obj.class_label = varargin{n+1};
                    case 'sample_rate'
                        obj.sample_rate = varargin{n+1};
                    case 'buffer_start'
                        obj.buffer_start = varargin{n+1};
                    case 'buffer_end' 
                        obj.buffer_end = varargin{n+1};
                    case 'start_recordings'
                        obj.start_recordings = varargin{n+1};
                    case 'end_recording'
                        obj.end_recording = varargin{n+1};
                    case 'end_trail'
                        obj.end_trail = varargin{n+1};
                    case 'high_freq'
                        obj.high_freq = varargin{n+1};
                    case 'high_width' 
                        obj.high_width = varargin{n+1};
                    case 'low_freq'
                        obj.low_freq = varargin{n+1};
                    case 'low_width'
                        obj.low_width = varargin{n+1};
                    case 'notch'
                        obj.notch = varargin{n+1};
                    case 'notch_width' 
                        obj.notch_width = varargin{n+1};
                    case 'eog_artifact'
                        obj.eog_artifact = varargin{n+1};
                    case 'avg_reference'
                        obj.avg_reference = varargin{n+1};
                    case 'quantiles'
                        obj.quantiles = varargin{n+1};
                    case 'removed_chan'
                        obj.removed_chan = varargin{n+1};
                    case 'x_flip_p' 
                        obj.x_flip_p = varargin{n+1};
                    case 'wgn_p'
                        obj.wgn_p = varargin{n+1};
                    case 'electrode_num' 
                        obj.electrode_num = varargin{n+1};
                    case 'electrode_loc'
                        obj.electrode_loc = varargin{n+1};
                    case 'verbose_freq'
                        obj.verbose_freq = varargin{n+1};
                    case 'max_epochs'
                        obj.max_epochs = varargin{n+1};
                    case 'mini_batch_size'
                        obj.mini_batch_size = varargin{n+1};
                    case 'validation_freq' 
                        obj.validation_freq = varargin{n+1};
                end
            end
            % use the features if you extract them
            if ~strcmp(obj.feat_alg, 'none') && strcmp(obj.feat_or_data, 'feat')
                disp('notice that you are extracting features but you are not using them in the pipeline!')
                disp('press any key to continue')
                pause()
            end
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
        
            obj.fix_class(); % see the function description below..
        end

        function fix_class(obj)
            % this function merges classes with the same label and sorts the
            % labels and the class names accordingly
            % Inputs: 
            %   obj - a constant object
            % Outputs:
            %   class_label - new sorted and unique labels array
            %   class_name - new merged names for each label
            new_labels = sort(unique(obj.class_label)); % get unique and sorted labels
            new_name = cell(length(new_labels), 1); % initialize new cell to store new class names
            new_marker = cell(length(new_labels), 1); % initialize new cell to store markers of each class 
            for i = 1:length(new_labels)
                new_name{i} = strjoin(obj.class_names(obj.class_label == new_labels(i)), ' + '); % concat joint class names
                % concat markers 
                mark = obj.class_marker(obj.class_label == new_labels(i));
                curr_mark = {};
                for j = 1:length(mark)
                    if isa(mark{j}, 'cell')
                        for k = 1:length(mark{j})
                            curr_mark{end+1} = mark{j}{k};
                        end
                    else
                        curr_mark{end+1} = mark{j};
                    end
                end
                new_marker{i} = curr_mark;
            end
            obj.class_names = new_name;    % replace old names with new names
            obj.class_marker = new_marker; % replace old markers with new markers
        end      

        function set_electrode_loc(obj, loc)
            obj.electrode_loc = loc;
            obj.electrode_num = 1:lrngth(loc);
        end

        function set_removed_chan(obj, chan)
            obj.removed_chan = chan;
        end
    end
end