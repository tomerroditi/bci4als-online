function [class_pred, thresh, CM] = evaluation(bci_model, data_store, labels, options)
% this function classifies a data store according to the given model and a
% threshold for class 1 (Idle) or a criterion threshold or by its default
% classification function (max)
%
% Input:
%   - bci_model: a bci_model object
%   - data_store: a data store consistent with the model 
%   - constants: a constants object
%   - thres_C1 (optional): classification threshold for class 1
%   - CM_title (optional): a header for the CM plot ('test', 'validation', etc.)
%   - criterion (optional): a criterion for the perfcurve function
%   - criterion_thresh (optional): must be suplied with 'criterion', the
%   criterion threshold for classification working point.
%
% Output:
%   - class_pred: a double array with the predicted class of each trial
%   - CM: a confusion matrix
%   - thresh: the classification threshold for class 1 if 'criterion' and
%   'criterion_thresh' is given.

arguments
    bci_model
    data_store
    labels
    options.thres_C1 = []
    options.CM_title = ''
    options.criterion = []
    options.criterion_thresh = []
    options.print = false;
end

if isempty(data_store)
    class_pred = [];
    thresh = [];
    CM = [];
    return
end

model = bci_model.model;
if ~bci_model.DL_flag
    % convert data store into data set 
    % this part might need to be debugged, I havent tested it yet
    [data, ~] = ds2set(data_store);
    scores = predict(model, data(:,bci_model.feat_idx));
else
    % predict using the model
    scores = predict(model, data_store);
end

class_name = bci_model.my_pipeline.class_names;  % the classes we are ussing to train the model
class_label = bci_model.my_pipeline.class_label; % the label we gave to each class

% find idle location
idle_idx = strcmp(class_name, 'Idle');

if ~isempty(options.criterion) && ~isempty(options.criterion_thresh) % predict with criterion
    % get the criterion you desire 
    [crit_values,~,thresholds] = perfcurve(labels, scores(:,idle_idx), 1, 'XCrit', options.criterion);

    % set a working point for class Idle
    [~,I] = min(abs(crit_values - options.criterion_thresh));
    thresh = thresholds(I); % the working point

    % label the samples according to the criterion threshold
    [~, class_pred_idx] = max(scores(:,~idle_idx), [], 2);
    class_label_no_idle = class_label(~idle_idx);
    class_pred = class_label_no_idle(class_pred_idx);
    class_pred(scores(:,idle_idx) >= thresh) = class_label(idle_idx);

    title = [' confusion matrix - ' options.criterion ' = '  num2str(options.criterion_thresh)];
elseif ~isempty(options.thres_C1) % predict with threshold for Idle class
    % label the samples according to the threshold
    [~, class_pred_idx] = max(scores(:,~idle_idx), [], 2);
    class_label_no_idle = class_label(~idle_idx);
    class_pred = class_label_no_idle(class_pred_idx);
    class_pred(scores(:,idle_idx) >= options.thres_C1) = class_label(idle_idx);
    title = [' confusion matrix - Idle threshold = '  num2str(options.thres_C1)];
    thresh = [];
else % deafult prediction
    [~, class_pred_idx] = max(scores, [], 2);
    class_pred = class_label(class_pred_idx);
    title = ' confusion matrix';
    thresh = [];
end

CM = confusionmat(labels,class_pred);
accuracy = sum(labels == class_pred)/length(labels);
% plot the confusion matrix
if options.print
    figure('Name', [options.CM_title title]);
    confusionchart(CM, class_name);
    disp([options.CM_title ' accuracy is: ' num2str(accuracy)]);
end

end