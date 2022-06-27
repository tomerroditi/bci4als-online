function my_bci(inlet, model, options, constants, data_size)

persistent data predictions time_from_action
if isempty(data)
    data = [];
    predictions = ones(constants.raw_pred_action,1);
    time_from_action = 0;
    disp('bci has started')
end

chunk = inlet.pull_chunk();
chunk(constants.xdf_removed_chan,:) = [];
data = [data, chunk];
if size(data,2) < data_size
    return
end
segments = data(:,end - data_size + 1:end);

% filter the data
segments = filter_data(segments, options.cont_or_disc, constants);

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
if scores(1) >= constants.model_thresh
    curr_prediction = 1;
elseif scores(2) > scores(3)
    curr_prediction = 2;
else
    curr_prediction = 3;
end

% action execution
predictions = [predictions(2:end); curr_prediction];
%     disp(predictions);
curr_time = tic;
if all(predictions == constants.LEFT_LABEL) && (curr_time - time_from_action)/10^7 > constants.cool_time
    disp('left')
    time_from_action = tic;
elseif all(predictions == constants.RIGHT_LABEL) && (curr_time - time_from_action)/10^7  > constants.cool_time
    disp('right')
    time_from_action = tic;
end
disp(predictions.')
end