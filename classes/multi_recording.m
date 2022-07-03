classdef multi_recording < handle & matlab.mixin.Copyable & recording
    properties (SetAccess = protected)
        rec_idx     % indices of segments of each recording
        num_rec
    end

    properties (Access = public)
        group
    end

    methods
        %% define the object
        function obj = multi_recording(recordings)
            if nargin > 0  % support an empty class members
                if isempty(recordings)
                    return
                end
                % initialize some empty arrays and variables
                obj.path = {}; obj.Name = {}; obj.markers = {}; obj.rec_idx = {};
                counter_seg = 1; counter_raw = 1; counter_filt = 1;
                obj.options = recordings{1}.options;
                obj.constants = recordings{1}.constants;
                for i = 1:length(recordings)
                    if isempty(recordings{i}.raw_data)
                        continue
                    end
                    % check for inconsistencies between recordings options and constants
                    if ~isequal(obj.options, recordings{i}.options) || ~isequaln(obj.constants, recordings{1}.constants)
                        error(['the recordings object you are trying to gather has different options structures or constants objects' newline...
                            'The different recording we first encountered is ' recordings{i}.Name]);
                    end
                    if ~isa(recordings{i}, 'recording')
                        error('"multi_recording" class inputs must be "recording" class objects!')
                    end
                    % concatenate all the relevant data
                    obj.features             = cat(5, obj.features, recordings{i}.features);
                    obj.segments             = cat(5, obj.segments, recordings{i}.segments);
                    obj.supp_vec             = cat(2, obj.supp_vec, recordings{i}.supp_vec);
                    obj.sample_time          = cat(2, obj.sample_time, recordings{i}.sample_time);
                    obj.raw_data             = cat(2, obj.raw_data, recordings{i}.raw_data);
                    obj.raw_data_filt        = cat(2, obj.raw_data_filt, recordings{i}.raw_data_filt);
                    obj.path                 = cat(1, obj.path, recordings{i}.path);
                    obj.Name                 = cat(1, obj.Name, recordings{i}.Name);
                    obj.markers              = cat(1, obj.markers, recordings{i}.markers);
                    obj.labels               = cat(1, obj.labels, recordings{i}.labels);
                   
                    seg_idx = counter_seg:counter_seg + length(recordings{i}.labels) - 1; % segments indices
                    raw_idx = counter_raw: counter_raw + size(recordings{i}.raw_data, 2) - 1; % raw data indices
                    filt_idx = counter_filt: counter_filt + size(recordings{i}.raw_data_filt, 2) - 1; % filtered data indices
                    
                    % place the recording name and indices inside a cell
                    % array so we can track the data later
                    if isa(recordings{i}, 'multi_recording') 
                        idx = recordings{i}.rec_idx;
                        idx(:,2) = cellfun(@(X) X + seg_idx(1) - 1, idx(:,2), 'UniformOutput', false);
                        idx(:,3) = cellfun(@(X) X + raw_idx(1) - 1, idx(:,3), 'UniformOutput', false);
                        idx(:,4) = cellfun(@(X) X + filt_idx(1) - 1, idx(:,4), 'UniformOutput', false);
                        obj.rec_idx = cat(1, obj.rec_idx, idx);
                    else
                        obj.rec_idx = cat(1, obj.rec_idx, {recordings{i}.Name, seg_idx, raw_idx, filt_idx});
                    end
                    % update counters
                    counter_seg = counter_seg + length(recordings{i}.labels);
                    counter_raw = counter_raw + size(recordings{i}.raw_data, 2);
                    counter_filt = counter_filt + size(recordings{i}.raw_data_filt, 2);
                end
                [obj.supp_vec, obj.sample_time] = fix_times(obj.supp_vec, obj.sample_time); % fix time points
                obj.num_rec = size(obj.rec_idx, 1); % extract number of recordings 
            end
        end

        %% train test validation split
        function [train, test, val] = train_test_split(obj, args)
            arguments
                obj
                args.test_ratio = 0;
                args.val_ratio = 0;
            end
            % calculate the number of recordings for each set
            num_test = round(obj.num_rec*args.test_ratio);
            num_val  = round(obj.num_rec*args.val_ratio);
            % create a random indices array
            split_rec_idx = randperm(obj.num_rec, obj.num_rec);
            % allocate indices for each set
            test_idx  = split_rec_idx(1:num_test);
            val_idx   = split_rec_idx(num_test + 1:num_test + num_val);
            train_idx = split_rec_idx(num_test + num_val + 1:end);
            % create new objects
            train = multi_recording(obj.recordings(train_idx));
            test  = multi_recording(obj.recordings(test_idx));
            val   = multi_recording(obj.recordings(val_idx));

            train.group = 'train';
            test.group = 'test';
            val.group = 'validation';
        end
    end
end
            









