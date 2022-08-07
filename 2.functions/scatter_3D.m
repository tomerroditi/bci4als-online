function scatter_3D(data_points, recording)

% extract the true labels of the data
labels = recording.labels;

% extract class labels and names
my_pipeline = recording.my_pipeline;
class_labels = my_pipeline.class_label;
class_names = my_pipeline.class_name_model;
class_names_chosen = my_pipeline.class_name_model;
class_names_chosen = cellfun(@(X) strcat(X, ' - chosen'), class_names_chosen, 'UniformOutput', false);
% create a new cell for legend names when ploting specific recordings
legend_names = {};
for i = 1:length(class_names)
    legend_names = cat(2, legend_names, class_names(i), class_names_chosen(i));
end

% plot all data points
figure('Name', 'clusters')
for i = 1:length(class_labels)
    color = [rand,rand,rand];
    scatter3(data_points(labels == class_labels(i),1), data_points(labels == class_labels(i),2),...
        data_points(labels == class_labels(i),3), 36, color); hold on
end
legend(class_names);
drawnow
hold off;


if ~isa(recording, 'multi_recording') % keep going only if its a multi recording object
    return
end

% mark a specific recording in the cluster
while true
    % input message
    in = input(['pls select a recording to display its cluster members from 1:' num2str(recording.num_rec) ' - ']);
    if isempty(in) % stop itterating if no input
        break
    end
    
    rec_indices = recording.rec_idx{in,2}; % the indices of the chosen recording

    % check if we got a group name to add to the plot title
    if ~isempty(recording.group)
        group_name = recording.group;  % specify 'train' 'val' 'test' for plots title
    else
        group_name = [];
    end
    

    % get the picked recording data and labels
    rec_labels = recording.labels(rec_indices);
    rec_points = data_points(rec_indices,:);

    % create the plot title
    if ~isempty(group_name)
        title = ['data points from ' group_name ' set, recording: ' recording.Name{in}];
    else
        title = ['data points from ' recording.Name{in}];
    end

    % plot all data points and the chosen recording
    figure('Name', title)
    for i = 1:length(class_labels)
        color = [rand,rand,rand];
        scatter3(data_points(labels == class_labels(i),1), data_points(labels == class_labels(i),2),...
            data_points(labels == class_labels(i),3), 18, color, 'Marker', '.'); hold on % all data points
        scatter3(rec_points(rec_labels == class_labels(i),1), rec_points(rec_labels == class_labels(i),2),...
            rec_points(rec_labels == class_labels(i),3), 30, color, 'filled'); hold on % selected data points
    end
    legend(legend_names);
    drawnow

end
% close all figures?
answer = input('Do you want to close all plots? type anything to keep them open: ');
if isempty(answer)
    close all;
end
end
