classdef multi_recording < handle & matlab.mixin.Copyable & recording
    properties (SetAccess = protected)
        rec_idx
        recordings
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
                % concatenate all the relevant data
                obj.path = {}; obj.Name = {}; obj.markers = {};
                counter = 1;
                for i = 1:length(recordings)
                    if ~isa(recordings{i}, 'recording')
                        error('"multi_recording" class inputs must be "recording" class objects!')
                    end
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
                    obj.rec_idx              = cat(1, obj.rec_idx, [counter, counter + length(recordings{i}.labels) - 1]);
                    counter = counter + length(recordings{i}.labels);
                end
                [obj.supp_vec, obj.sample_time] = fix_times(obj.supp_vec, obj.sample_time); % fix time points
                obj.options = recordings{1}.options;
                obj.constants = recordings{1}.constants;
                obj.num_rec = length(obj.path);
                for i = 1:length(recordings)
                    obj.recordings{i} = copy(recordings{i}); % save copies and not pointers!
                end
            end
        end

        %% normalizations
        function normalize(obj, seg_raw_filt_all)
            % normalize the recordings of the object
            for i = 1:length(obj.recordings)
                obj.recordings{i}.normalize(seg_raw_filt_all)
            end
            % retrieve normalized data into the object
            if strcmp(seg_raw_filt_all, 'seg') || strcmp(seg_raw_filt_all, 'all')
                obj.segments = [];
                for i = 1:length(obj.recordings)
                    obj.segments = cat(5,obj.segments, obj.recordings{i}.segments); 
                end
            end
            if strcmp(seg_raw_filt_all, 'raw') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data = [];
                for i = 1:length(obj.recordings)
                    obj.raw_data = cat(2,obj.raw_data, obj.recordings{i}.raw_data); 
                end
            end
            if strcmp(seg_raw_filt_all, 'filt') || strcmp(seg_raw_filt_all, 'all')
                obj.raw_data_filt = [];
                for i = 1:length(obj.recordings)
                    obj.raw_data_filt = cat(2,obj.raw_data_filt, obj.recordings{i}.raw_data_filt); 
                end
            end
        end

        %% features extraction
        function extract_feat(obj)
            obj.features = [];
            f = waitbar(0); % open a wait bar
            % extract features for every recording            
            for i = 1:length(obj.recordings)
                waitbar(i/length(obj.recordings), f, ['extracting features, recording ' num2str(i) ' out of ' num2str(length(obj.recordings))]); % update the wait bar
                obj.recordings{i}.extract_feat();
                obj.features = cat(5, obj.features, obj.recordings{i}.features); % concate the features to create the multi recording features
            end
            delete(f) % close the wait bar
        end

        %% create a data store (DS) from the obj segments and labels
        function create_ds(obj, feat_seg)
            create_ds@recording(obj, feat_seg)
            for i = 1:length(obj.recordings)
                obj.recordings{i}.create_ds(feat_seg)
            end
        end

        %% predictions and evaluation
        function [pred, thresh, CM] = evaluate(obj, model, options)
            arguments
                obj
                model
                options.thres_C1 = [];
                options.CM_title = '';
                options.criterion = [];
                options.criterion_thresh = [];
                options.print = true;
            end
            if ~isempty(obj.group) % give a proper title according to the group name
                options.CM_title = [obj.group ' data'];
            end
            % evaluate for the multi_recording
            [pred, thresh, CM] = evaluate@recording(obj, model, CM_title = options.CM_title, ...
                    criterion = options.criterion, criterion_thresh = options.criterion_thresh, ...
                    thres_C1 = options.thres_C1, print = options.print);
            % evaluate for recordings with or without printing
            for i = 1:length(obj.recordings)
                if isa(obj.recordings{i}, 'multi_recording')
                    options.print = true;
                else
                    options.print = false;
                end
                obj.recordings{i}.evaluate(model, CM_title = options.CM_title, ...
                    criterion = options.criterion, criterion_thresh = options.criterion_thresh, ...
                    thres_C1 = options.thres_C1, print = options.print);
            end
        end

        %% train test validation split
        function [train, test, val] = train_test_split(obj, args)
            arguments
                obj
                args.test_ratio = obj.options.test_split_ratio;
                args.val_ratio = obj.options.val_split_ratio
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
            









