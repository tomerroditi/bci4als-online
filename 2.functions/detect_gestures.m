function [accuracy, missed_gest, mean_delay, CM] = detect_gestures(bci_model, recording, predictions,  visualize, plot_title)
    % this functions is used to calculate the model accuracy on
    % gesture execution. you can set new values for conf_level,
    % cool_time and max_delay field of the recording bci_model
    % object as well.
    % Inputs:
    %   print(optional) - bool, print CM and gesture visualization or not
    % Outputs:
    %   accuracy - the model gesture accuracy
    %   missed_gest - the model missed gestures percentage
    %   mean_delay - the mean time between true gesture execution
    %                time and gesture recognition
    %   CM - a confusion matrix of gesture recognition
    %   gest_times_pred - the time of each gesture recognition and
    %                     the gesture label

    % extracting parameters for code readability
    K = bci_model.conf_level;
    cool_time = bci_model.cool_time;
    max_delay = bci_model.max_delay;
    labels = recording.labels;
    my_pipeline = recording.my_pipeline;
    class_label = my_pipeline.class_label;
    class_name = my_pipeline.class_names;

    % get idle label and index
    idle_idx = strcmp(class_name, 'Idle');
    idle_label = class_label(idle_idx); % find the label of Idle class

    % calculate true and predicted gesture execution times
    curr_gest_times_pred = get_gestures(predictions, K, cool_time, my_pipeline, recording.sample_time);
    gest_times_pred = curr_gest_times_pred; % save the original vector for ploting
    gest_times_GT = []; 
    while isempty(gest_times_GT) % find true gestures
        i = 1;
        if K == 0
            error('no gestures to detect in the data, check the data labels for labels other than idle!')
        end
        while i <= length(labels) - K
            if all(labels(i:i+K) ~= idle_label)
                gest_times_GT(:,end+1) = [labels(i); recording.sample_time(i)];
                i = i + round(5/(my_pipeline.seg_dur - my_pipeline.overlap)); % roughtly 5 sec jump
            else
                i = i + 1;
            end
        end
        K = K - 1; % reduce confidence when findning the real gestures if its too high
    end

    % compare true gestures and predicted ones
    delay = []; % initialize an empty array to calculate the mean delay of gesture detection
    GT_pred = []; % initialize an array to store the true and predicted gestures
    gest_times_GT(2,:) = gest_times_GT(2,:) - my_pipeline.seg_dur*my_pipeline.threshold; % place the true gesture times at roughtly the beggining of the gesture
    for i = 1:size(gest_times_GT, 2)
        time_diff = curr_gest_times_pred(2,:) - gest_times_GT(2,i);
        M = min(time_diff(time_diff >= 0)); % find the closest future predicted gesture to the current gesture
        if M < max_delay % allow up to max_delay second response delay from the start of the gesture execution
            delay = cat(1, delay, M); % save delay of gesture execution
            GT_pred = cat(2, GT_pred, [gest_times_GT(1,i) ; curr_gest_times_pred(1, time_diff == M)]);
            curr_gest_times_pred(:, time_diff == M) = [];
        else
            GT_pred = cat(2, GT_pred, [gest_times_GT(1,i); idle_label]); % missed gesture
        end
    end
    GT_pred = cat(2, GT_pred, [ones(1,size(curr_gest_times_pred,2)) ; curr_gest_times_pred(1,:)]); % false positives
   
    % calculate the accuracy misse rate and mean delay
    mean_delay = mean(delay);
    CM = confusionmat(GT_pred(1,:), GT_pred(2,:), "Order", class_label); % confusion matrix
    accuracy =  sum(diag(CM(~idle_idx, ~idle_idx)))/sum(sum(CM(:,~idle_idx))); 
    missed_gest = sum(CM(:,idle_idx))/sum(sum(CM(~idle_idx,:)));

    % plot the gestures 
    if visualize                
        figure('Name', ['gesture execution moments - ' plot_title])
        plot(recording.supp_vec(2,:), recording.supp_vec(1,:), 'r*', 'MarkerSize', 1); hold on;
        plot(gest_times_pred(2,:), gest_times_pred(1,:), 'bs', 'MarkerSize', 5); hold on;
        plot(gest_times_GT(2,:), gest_times_GT(1,:), 'gs', 'MarkerSize', 3, 'MarkerFaceColor', 'green');
        xlabel('time [s]'); ylabel('class'); 
        title(['model accuracy is: ' num2str(accuracy) ' with a miss rate of: ' num2str(missed_gest) ', and a mean delay of:' num2str(mean_delay)]);
        legend({'time points', 'predicted executed gesture', 'true executed gestures'})
        figure('Name', ['geasture detection CM - ' plot_title])
        confusionchart(CM, class_name);
    end
end