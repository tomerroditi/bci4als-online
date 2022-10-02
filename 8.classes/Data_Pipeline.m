classdef Data_Pipeline < handle
    % pipeline parameters and general constants object
    properties (GetAccess = public, SetAccess = protected)
        % classes and markers
        class_names       = {'idle'; 'left hand'; 'right hand'}; 
        class_markers      = cellstr(num2str([1;2;3], '%#.16g')); % each class markers in the recording files,
                                                                 % its possible to give more than 1 marker for
                                                                 % a certain class - use a cell of str instead of a str                
        expi_start_marker  = num2str(111, '%#.16g');
        expi_end_marker    = num2str(99, '%#.16g');
        trail_end_marker   = num2str(9, '%#.16g');

        % features algorithm - choose from the functions names in feature extraction methods folder
        feat_algo          = 'none';

        % big data handling
        big_data = false;

        % segmentation
        segment_duration_sec        = 4;
        segments_step_size_sec      = 0.5;
        sequence_len                = 1;
        sequence_step_size          = 1;
        segment_labeling_threshold  = 0.7;
        
        % buffers size - usefull to prevent unstable parts of the filtered signal in the final segments
        buffer_start      = 3000; % number of samples before segment starts
        buffer_end        = 0;    % number of samples after segment ends
        
        % filters parameters
        high_freq         = 30;      % BP high cutoff frequency in HZ
        high_width        = 3;       % the width of the transition band for the high freq cutoff
        low_freq          = 7;       % BP low cutoff frequency in HZ
        low_width         = 3;       % the width of the transition band for the low freq cutoff
        notch             = [50, 31.25, 25];% frequency to apply notch filter on
        notch_width       = 0.5;     % the width of the notch filter
        
        % general preprocessing
        eog_artifact  = false;  % true - removes EOG\emg artifacts, flase - dont remove EOG\emg artifacts
        avg_reference = false;  % true - re reference electrodes to cz, false - dont re reference
        electrodes_to_remove  = [12,13,14,15,16];  % electrodes to remove

        % normalization parameters
        quantiles         = [0.05 0.95]; % quantiles of data to normalize by
    
        % data store augmentations
        augmentation_params = containers.Map({'x_flip_p', 'wgn_p'}, {0, 0.8}); %#ok<MCHDP> 
    
        % hardware
        sample_rate       = 125;
        electrode_num     = [1,2,3,4,5,6,7,8,9,10,11]; % electrode number
        electrode_loc     = {'C3','C4','Cz','FC1','FC2','FC5','FC6','CP1','CP2','CP5','CP6'}; % electrodes location respectivly to electrode num

    end

    methods
        function obj = Data_Pipeline(varargin)
            % set the given optional inputs as the object properties
            for n = 1:2:size(varargin,2)
                switch varargin{n}
                    case 'feat_algo' 
                        obj.feat_algo = varargin{n+1};
                    case 'segments_step_size'
                        obj.segments_step_size_sec = varargin{n+1};
                    case 'segment_duration_sec'
                        obj.segment_duration_sec = varargin{n+1};
                    case 'sequence_len'
                        obj.sequence_len = varargin{n+1};
                    case 'sequence_step_size'
                        obj.sequence_step_size = varargin{n+1};
                    case 'segment_threshold'
                        obj.segment_labeling_threshold = varargin{n+1};
                    case 'class_names'
                        obj.class_names = varargin{n+1};
                    case 'class_markers'
                        obj.class_markers = varargin{n+1};
                    case 'sample_rate'
                        obj.sample_rate = varargin{n+1};
                    case 'buffer_start'
                        obj.buffer_start = varargin{n+1};
                    case 'buffer_end'
                        obj.buffer_end = varargin{n+1};
                    case 'expi_start_marker'
                        obj.expi_start_marker = varargin{n+1};
                    case 'expi_end_marker'
                        obj.expi_end_marker = varargin{n+1};
                    case 'trail_end_marker'
                        obj.trail_end_marker = varargin{n+1};
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
                    case 'electrodes_to_remove'
                        obj.electrodes_to_remove = varargin{n+1};
                    case 'augmentation_params'
                        obj.augmentation_params = varargin{n+1};
                    case 'electrode_num'
                        obj.electrode_num = varargin{n+1};
                    case 'electrode_loc'
                        obj.electrode_loc = varargin{n+1};
                end

                [obj.class_names, I] = sort(lower(obj.class_names));
                obj.class_markers = obj.class_markers(I);
            end
        end
    end
end