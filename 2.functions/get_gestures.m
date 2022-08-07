function gest_time = get_gestures(labels, K, cool_time, my_pipeline, sample_time)
% this function is used to extract the executed gestures from
% the labels according to some parameters.
% Inputs:
%   K - the number of same labels in a raw to execute a gesture
%   cool_time - time window to not execute a gesture after executing a gesture
%   constants - a constant objects.
%   sample_time - the time where each segment ends.

    idle_idx = strcmp(my_pipeline.class_names, 'Idle'); % get the idle label index
    class_label_no_idle = my_pipeline.class_label(~idle_idx); % take only the not idle labels
    gest_time = [0;0]; % initialize a vector for gesture class and time of execution
    % start detecting the gestures
    for i = K:length(labels)
        if sample_time(i) - gest_time(2,end) < cool_time
            % if we detected a gesture we need to wait cool_time
            % seconds befor starting to look for another one
            continue
        end
        for j = 1:length(class_label_no_idle)
            if labels(i - K + 1:i) == class_label_no_idle(j) % check for K identical predictions in a row
                gest_time(:,i) = [class_label_no_idle(j) ; sample_time(i)]; % save the detected gesture and its time
                break
            end
        end 
    end
    gest_time(:,gest_time(1,:) == 0) = []; % remove zeros
end