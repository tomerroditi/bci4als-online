function my_bci(inlet, model, options, constants, data_size)

persistent data predictions time_from_action labels class_name idle_idx
if isempty(data)
    data = [];
    predictions = ones(constants.raw_pred_action,1);
    time_from_action = 0;
    labels = constants.class_label;
    class_name = constants.class_name_model;
    % sort labels to match the model output
    [labels, indices] = sort(labels, 'ascend');
    class_name = class_name(indices);
    idle_idx = strcmpi(class_name, 'Idle');
    disp('bci has started')
end

chunk = inlet.pull_chunk();
chunk(constants.xdf_removed_chan,:) = [];
data = [data, chunk];
if size(data,2) < data_size
    return
end
data = data(:,end - data_size + 1:end);
segments = data;

% filter the data
segments = filter_segments(segments, options.cont_or_disc, constants);

% create the sequence 
segments = create_sequence(segments, options);

% normalize the data
segments = norm_eeg(segments, constants.quantiles);

% extract features if needed
if ~strcmp(options.feat_alg, 'none')
    segments = extract_feat(segments, options);
end

% predict and label the current segment
scores = predict(model, segments(:,:,:));
curr_prediction = [];
% idle classification
for i = 1:length(labels)
    if strcmpi(class_name{i}, 'Idle') && scores(i) >= constants.model_thresh
        curr_prediction = labels(i);
    end
end
% gesture classification
if isempty(curr_prediction)
    temp_labels = labels(~idle_idx);
    for i = 1:length(temp_labels)
        [~, I] = max(scores, [], 2);
        curr_prediction = temp_labels(I);
    end
end

% action execution
predictions = [predictions(2:end); curr_prediction];
%     disp(predictions);
curr_time = tic;
for i = 1:length(labels)
    if all(predictions == labels(i)) && (curr_time - time_from_action)/10^7 > constants.cool_time
        disp(class_name{i})
        time_from_action = tic;
    end
end
% indicate if the model picked up a movement
if any(predictions ~= labels(idle_idx))
    disp(predictions.')
end
end