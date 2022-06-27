function scatter_3D(data_points, recording)

labels = recording.labels;

figure('Name', 'clusters')
scatter3(data_points(labels == 1,1), data_points(labels == 1,2), data_points(labels == 1,3), 'r'); hold on
scatter3(data_points(labels == 2,1), data_points(labels == 2,2), data_points(labels == 2,3), 'b'); hold on
scatter3(data_points(labels == 3,1), data_points(labels == 3,2), data_points(labels == 3,3), 'g'); hold on
legend({'class 1 - idle', 'class 2 - left', 'class 3 - right'});
drawnow

if ~isa(recording, 'multi_recording') % keep going only if its a multi recording object
    return
end

% mark a specific recording in the cluster
while true
    % input message
    in = input(['pls select a recording to display its cluster members from 1:' num2str(length(recording.recordings)) ' - ']);
    if isempty(in) % stop itterating if no input
        break
    end
    
    % extract the group name if its a multi class with a group name and
    % determine who is rec variable
    if isa(recording.recordings{in}, 'multi_recording')
        idx_start = recording.rec_idx(in,1);
        rec = recording.recordings{in};
        if isempty(rec.recordings)
            disp('you selected an empty recording, pls select a different one next time.');
            continue
        end
        group_name = rec.group;  % specify 'train' 'val' 'test' for plots title
        % keep getting into multi recordings if its a nested multi recording
        % untill getting to a recording class object
        while isa(rec, 'multi_recording')
            in = input(['the selected recording is a multi recording, select a sub recording from 1:' num2str(length(rec.recordings)) ' - ']);
            idx_start = idx_start + rec.rec_idx(in,1) - 1;
            if isa(rec.recordings{in}, 'recording')
                break
            end
            rec = rec.recordings{in};
        end
        idx_end = idx_start + rec.rec_idx(in,2) - rec.rec_idx(in,1);
        idx_range = idx_start:idx_end;
    else
        rec = recording;
        idx_range = rec.rec_idx(in,1):rec.rec_idx(in,2);
        group_name = [];
    end

    % get the picked recording data and labels
    rec_labels = recording.labels(idx_range);
    rec_points = data_points(idx_range,:);

    % plot all data points
    if ~isempty(group_name)
        title = ['data points from ' group_name ' set, recording: ' rec.Name{in}];
    else
        title = ['data points from ' rec.Name{in}];
    end
    figure('Name', title)
    scatter3(data_points(labels == 1,1), data_points(labels == 1,2), data_points(labels == 1,3), 'r'); hold on
    scatter3(data_points(labels == 2,1), data_points(labels == 2,2), data_points(labels == 2,3), 'b'); hold on
    scatter3(data_points(labels == 3,1), data_points(labels == 3,2), data_points(labels == 3,3), 'g'); hold on

    % plot the picked recording data points as filled points
    scatter3(rec_points(rec_labels == 1,1), rec_points(rec_labels == 1,2), rec_points(rec_labels == 1,3), 'r', 'filled'); hold on
    scatter3(rec_points(rec_labels == 2,1), rec_points(rec_labels == 2,2), rec_points(rec_labels == 2,3), 'b', 'filled'); hold on
    scatter3(rec_points(rec_labels == 3,1), rec_points(rec_labels == 3,2), rec_points(rec_labels == 3,3), 'g', 'filled'); hold on
    legend({'class 1 - idle', 'class 2 - left', 'class 3 - right'});
    drawnow
end
% close all figures?
answer = input('Do you want to close all plots? type anything to keep them open: ');
if isempty(answer)
    close all;
end
end
