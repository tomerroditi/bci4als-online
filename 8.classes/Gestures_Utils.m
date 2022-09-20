classdef Gestures_Utils
    methods (Static)
        function [gestures, gesture_start_indices] = get_true_gestures(labels, segments_end_idx)
            not_idle_indices = labels ~= 'idle';

            difference = diff(not_idle_indices);
            new_gest_start_indices = find(difference == 1) + 1;
            if not_idle_indices(1) == 1
                new_gest_start_indices = cat(1, 1, new_gest_start_indices); % add the first gesture
            end

            gestures = labels(new_gest_start_indices);
            gesture_start_indices = segments_end_idx(new_gest_start_indices);
        end
        
        function [gestures, gest_start_indices] = get_predicted_gestures(labels, segments_end_idx, confidence, cool_time)
            gestures = []; gest_start_indices = 0;

            num_indices_between_following_segments = floor(obj.pipeline.segments_step_size_sec*obj.pipeline.sample_rate);
            min_indices_between_gestures = round(cool_time/obj.pipeline.segments_step_size_sec)*num_indices_between_following_segments;

            for j = confidence:length(labels)
                curr_labels = labels(j - confidence + 1:j);
                curr_seg_end_idx = segments_end_idx(j - confidence + 1:j);
                if any(curr_labels == 'idle') ||...
                        length(unique(curr_labels)) ~= 1 ||...
                        any(diff(curr_seg_end_idx) ~= num_indices_between_following_segments) ||...
                        segments_end_idx(j) - gest_start_indices(end) < min_indices_between_gestures
                    continue
                else
                    gestures = cat(1, gestures, labels(j));
                    gest_start_indices = cat(1, gest_start_indices, segments_end_idx(j));
                end
            end
            gest_start_indices(1) = []; % remove the initiale zero
        end
   
    end
end