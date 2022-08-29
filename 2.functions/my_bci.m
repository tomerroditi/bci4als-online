function my_bci(inlet, bci_model, my_pipeline, data_size)

persistent data predictions time_from_action labels class_name idle_idx

% initialize some values at the first call
if isempty(data)
    data = [];
    predictions = ones(bci_model.conf_level,1);
    time_from_action = 0;
    labels = my_pipeline.class_label;
    class_name = my_pipeline.class_names;
    idle_idx = strcmpi(class_name, 'Idle');
    disp('bci has started')
end

chunk = inlet.pull_chunk();
chunk(my_pipeline.removed_chan,:) = [];
data = [data, chunk];
if size(data,2) < data_size
    return
end
data = data(:,end - data_size + 1:end);
segments = data;

% filter the data
segments = filter_segments(segments, my_pipeline);

% create the sequence 
segments = create_sequence(segments, my_pipeline);

% normalize the data
segments = norm_eeg(segments, my_pipeline.quantiles);

% extract features if needed
if ~strcmp(my_pipeline.feat_alg, 'none')
    segments = extract_feat(segments, my_pipeline);
end

% predict and label the current segment
scores = predict(bci_model.model, segments(:,:,:));
if scores(idle_idx) >= bci_model.threshold
    curr_prediction = labels(idle_idx);
else
    temp_labels = labels(~idle_idx);
    [~, I] = max(scores(~idle_idx), [], 2);
    curr_prediction = temp_labels(I);
end

% action execution
predictions(1) = []; % erase oldest prediction
predictions(end + 1) = curr_prediction; % insert new prediction
curr_time = tic;
if length(unique(predictions)) == 1 && predictions(1) ~= 1 && (curr_time - time_from_action)/10^7 > bci_model.cool_time
    disp(class_name{labels == predictions(1)});
    time_from_action = tic;
    % insert an action like yes\no sound here
end

% indicate if the model picked up a movement
if any(predictions ~= labels(idle_idx))
    disp(predictions.')
end
end