classdef Segments_Utils
    properties
        pipeline
    end

    methods 
        function segments_array = filter(obj, segments_array)
        % filter the time series segments (BP, notch)
            segments_array = filter_segments(segments_array, obj.pipeline); 
        end

        function segments_array = normalize(obj, segments_array)
        % normalize the signal channel (electrode) wise
            segments_array = norm_eeg(segments_array, obj.pipeline.quantiles);
        end

        function segments_array = create_sequence(obj, segments_array)
        % create a sequence from each signal segment
            segments_array = create_sequence(segments_array, obj.pipeline);
        end
    
        function features = extract_features(obj, segments_array)
            if ~strcmp(obj.pipeline.feat_algo, 'none') 
                % execute the desired feature extraction method
                feat_method = dir('5.feature extraction methods');
                feat_method_name = extractfield(feat_method, 'name');
                if ismember([obj.pipeline.feat_alg '.m'], feat_method_name)
                    features = eval([algo '(segments_array, obj.pipeline);']); % this will call the feature extraction fnc
                else 
                    error(['there is no file named "' obj.pipeline.feat_alg '" in the feature extraction method folder.' newline...
                        'please provide a valide file name (exclude the ".m"!) in the my pipeline object']);
                end
            else
                features = [];
            end
        end
    
        function bool_array = is_unphysiological(obj, segments_array, segments_end_idx, filtered_signal)
            seg_size = size(segments_array);
            num_segments = seg_size(end);
            num_samples_in_segment = seg_size(2);
            bool_array = false(num_segments, 1); % assume that all are physiological

            for i = 1:num_segments
                segment_indices = segments_end_idx(i) - num_samples_in_segment + 1: segments_end_idx(i);
                bool_array(i) = obj.reject_segment_or_not(segment_indices, filtered_signal);
            end
        end
    end

    methods (Access = protected)
        function bool = reject_segment_or_not(obj, segment_indices, filtered_signal)
            % check for unphysiological amplitudes in the segment
            if max(max(abs(filtered_signal(:,segment_indices)))) > 100
                bool = true;
                return
            end
            % check for abnormalities in a chunk - area that includes the segment 
            sample_rate = obj.pipeline.sample_rate;
            num_samples_before_segment = sample_rate*10; % manually selected values
            num_samples_after_segment = sample_rate*3;
            half_window = 10; 
            threshold = 20;

            chunk_indices = (segment_indices(1) - num_samples_before_segment):(segment_indices(end) + num_samples_after_segment);
            chunk_indices(chunk_indices < 1 | chunk_indices > size(filtered_signal,2)) = []; % handle out of range indices

            [max_values, max_indices] = max(abs(filtered_signal(:,chunk_indices)), [], 2);
            [~, max_idx] = max(max_values);
            idx = max_indices(max_idx) + chunk_indices(1);

            chunk_indices = (idx - half_window):(idx + half_window);
            chunk_indices(chunk_indices < 1 | chunk_indices > size(filtered_signal,2)) = []; % handle out of range indices
            inspected_signal = filtered_signal(:,chunk_indices);
            max_values = max(abs(inspected_signal), [], 2);
            max_values = sort(max_values, "descend");
            max_values_diff = max_values(1:end-1) - max_values(2:end);
            if any(max_values_diff > threshold)
                bool = true;
                return
            end
            bool = false; % if no abnormalities then return false...
        end

    end

    methods (Static)
        function [seg_or_feat, labels] = oversample(seg_or_feat, labels)
            % this function oversample each class so the data will have a uniform distribution
            % return empty arrays if the input is empty
            if isempty(seg_or_feat)
                seg_or_feat = []; labels = [];
                return
            end

            labels_cats = unique(labels);
            num_max_cat = max(countcats(labels));

            % find each class indices and oversample the data 
            for i = 1:length(labels_cats)
                curr_label = labels_cats(i);
                num_curr_label = sum(labels == curr_label);

                indices = labels == curr_label;
                curr_seg = seg_or_feat(:,:,:,:, indices); % reject all indices of other labels

                ratio = max([round(num_max_cat/num_curr_label), 1]); % ratio to the largest label (idle)
                seg_or_feat = cat(5, seg_or_feat, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
                labels = cat(1, labels, repmat(curr_label, num_curr_label*(ratio - 1), 1));
            end
        end
    end
end