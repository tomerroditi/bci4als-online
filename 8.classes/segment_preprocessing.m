classdef segment_preprocessing
    methods (Static)
        function segments = filter(segments, pipeline)
        % filter the time series segments (BP, notch)
            segments = filter_segments(segments, pipeline); 
        end

        function segments = normalize(segments, pipeline)
        % normalize the signal channel (electrode) wise
            segments = norm_eeg(segments, pipeline.quantiles);
        end

        function segments = create_sequence(segments, pipeline)
        % create a sequence from each signal segment
            segments = create_sequence(segments, pipeline);
        end
    
        function features = extract_features(segments, pipeline)
            if ~strcmp(pipeline.feat_algo, 'none') 
                % execute the desired feature extraction method
                feat_method = dir('5.feature extraction methods');
                feat_method_name = extractfield(feat_method, 'name');
                if ismember([pipeline.feat_alg '.m'], feat_method_name)
                    features = eval([algo '(segments, obj.my_pipeline);']); % this will call the feature extraction fnc
                else 
                    error(['there is no file named "' obj.pipeline.feat_alg '" in the feature extraction method folder.' newline...
                        'please provide a valide file name (exclude the ".m"!) in the my pipeline object']);
                end
            else
                features = [];
            end
        end
    
        function [seg_or_feat, categorical_labels] = oversample(seg_or_feat, categorical_labels)
            % this function oversample each class so the data will have a uniform distribution
            % return empty arrays if the input is empty
            if isempty(seg_or_feat)
                seg_or_feat = []; categorical_labels = [];
                return
            end

            labels_cats = unique(categorical_labels);
            num_max_cat = max(countcats(categorical_labels));

            % find each class indices and oversample the data 
            for i = 1:length(labels_cats)
                curr_label = labels_cats(i);
                num_curr_label = sum(categorical_labels == curr_label);

                indices = categorical_labels == curr_label;
                curr_seg = seg_or_feat(:,:,:,:, indices); % reject all indices of other labels

                ratio = max([round(num_max_cat/num_curr_label), 1]); % ratio to the largest label (idle)
                seg_or_feat = cat(5, seg_or_feat, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
                categorical_labels = cat(1, categorical_labels, repmat(curr_label, num_curr_label*(ratio - 1), 1));
            end
        end
    end
end