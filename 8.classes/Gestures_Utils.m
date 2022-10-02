classdef Gestures_Utils
    methods (Static)
        function [gestures, gesture_start_indices] = get_true_gestures_from(segments_end_time, labels)
            gestures = []; gesture_start_indices = [];
            
            seg_step_size_sec = round(min(diff(segments_end_time)), 3); % ussing round due to minor computation error
            avg_seg_in_gest = Gestures_Utils.get_average_segments_in_gesture(labels);
            min_labels_for_gest = ceil(avg_seg_in_gest/3);

            for i = 2:(length(labels) - min_labels_for_gest + 1)
                if labels(i) == 'idle' %#ok<BDSCA> % labels is categorical array
                    continue
                elseif labels(i) == labels(i - 1) && (segments_end_time(i) - segments_end_time(i - 1)) <  5
                    % assuming that time between gestures is at least 5 seconds.
                    % the second condition is to prevent missing new
                    % gestures in cases where the labels are the same but
                    % the segments are located far in time from each other
                    % meaning we probably rejected segments between them,
                    % or its the end of one file data segments and the start of
                    % another file data segments.
                    continue
                elseif any(labels(i) ~= labels(i: i + min_labels_for_gest - 1)) || ...
                        any(round(diff(segments_end_time(i: i + min_labels_for_gest - 1)), 3) ~= seg_step_size_sec)
                    % this condition is to prevent from partial captured
                    % gestures to be counted as true gestures. partial
                    % captured gestures are caused due to rejected segments
                    % (segments that are not physiological etc.)
                    continue
                else
                    gestures = cat(1, gestures, labels(i));
                    gesture_start_indices = cat(1, gesture_start_indices, segments_end_time(i));
                end
            end

            % check that we didnt miss the first gesture
            if labels(1) ~= 'idle' %#ok<BDSCA> 
                gestures = cat(1, labels(1), gestures);
                gesture_start_indices = cat(1, segments_end_time(1), gesture_start_indices);
            end
        end

        function avg_seg_in_gest = get_average_segments_in_gesture(labels)
            not_idle_labels_idx = find(labels ~= 'idle');
            diffr = diff(not_idle_labels_idx);
            idx = find(diffr ~= 1);
            avg_seg_in_gest = ceil(mean(diff(idx)));
        end
        
        function [gestures, gest_start_indices] = get_predicted_gestures_from(segments_end_time, labels, confidence, cool_time)
            gestures = []; gest_start_indices = 0;

            for j = confidence:length(labels)
                curr_labels = labels(j - confidence + 1:j);
                curr_seg_end_time = segments_end_time(j - confidence + 1:j);
                if any(curr_labels == 'idle') ||...
                        length(unique(curr_labels)) ~= 1 ||...
                        any(diff(curr_seg_end_time) > 5) ||... % same assumption as in get_true_gestures_from
                        segments_end_time(j) - gest_start_indices(end) < cool_time
                    continue
                else
                    gestures = cat(1, gestures, labels(j));
                    gest_start_indices = cat(1, gest_start_indices, segments_end_time(j));
                end
            end
            gest_start_indices(1) = []; % remove the initiale zero

            if isempty(gest_start_indices)
                % convert it to an empty double for future concatenations
                gest_start_indices = [];
            end
        end
    
        function [sync_true_gest, sync_true_times, sync_pred_gest, sync_pred_time] = sync_gestures(true_gest, true_times, pred_gest, pred_times) 

            max_delay_time = 7; % maximum time for delayed gesture detection
            max_ahead_time = 2; % maximum time for early gesture detection
            % These max times are assentialy a time window around any true
            % gesture. Predicted gesture in that time window will be
            % associated with the true gesture in it.
            % In case that there are 2 or more predictions in that time window the earliest
            % gesture predicted in that time window will be associated with
            % that gesutre, while the others will be associated with a true
            % "idle" gesture (predicting gestures when nothing happened).

            sync_pred_gest = [];
            sync_pred_time = [];

            for i = 1:length(true_gest)
                curr_pred_time_idx = (pred_times - true_times(i)) <= max_delay_time & ...
                                      (pred_times - true_times(i)) >= -max_ahead_time;
                positive_indices = find(curr_pred_time_idx);
                if length(positive_indices) > 1
                    curr_pred_time_idx(positive_indices(2:end)) = 0; % take only the first gesture
                end
                
                if any(curr_pred_time_idx)
                    num_true_before_curr_pred = sum((pred_times(curr_pred_time_idx) - true_times) >= 0);
                    if num_true_before_curr_pred == i
                        % relate pred and true gestures only if the pred gesture is
                        % the nearest future one to the current true gesture, otherwise
                        % it will be related to the next true gesture (in the next iteration) 
                        sync_pred_gest = cat(1, sync_pred_gest, pred_gest(curr_pred_time_idx));
                        sync_pred_time = cat(1, sync_pred_time, pred_times(curr_pred_time_idx));
                        
                        pred_gest = pred_gest(~curr_pred_time_idx);
                        pred_times = pred_times(~curr_pred_time_idx);
                    else
                        sync_pred_gest = cat(1, sync_pred_gest, {'idle'});
                        sync_pred_time = cat(1, sync_pred_time, true_times(i));
                    end
                else
                    sync_pred_gest = cat(1, sync_pred_gest, {'idle'});
                    sync_pred_time = cat(1, sync_pred_time, true_times(i));
                end
            end

            sync_pred_gest = cat(1, sync_pred_gest, pred_gest);
            sync_pred_time = cat(1, sync_pred_time, pred_times);
            if ~isa(sync_pred_gest, 'categorical')
                % in case we didnt predicted any gestures we need to
                % convert from cell array to categorical array for future
                % use
                sync_pred_gest = categorical(sync_pred_gest, categories(true_gest));
            end

            sync_true_gest = cat(1, true_gest, repmat({'idle'}, length(pred_gest), 1));
            sync_true_times = cat(1, true_times, pred_times);
        end
    end
end