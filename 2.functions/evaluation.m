function [class_pred, thresh, CM] = evaluation(bci_model, data_store, constants, options)
% this function classifies a data store according to the given model and a
% threshold for class 1 (Idle) or a criterion threshold or by its default
% classification function (max)
%
% Input:
%   - model: classification model
%   - data_store: a data store consistent with the model 
%   - thres_C1 (optional): classification threshold for class 1
%   - CM_title (optional): a header for the CM plot ('test', 'validation'
%   etc.)
%   - criterion (optional): a criterion for the perfcurve function
%   - criterion_thresh (optional): must be suplied with 'criterion', the
%   criterion threshold for classification working point.
%
% Output:
%   - CM: a confusion matrix
%   - thresh: the classification threshold for class 1 if 'criterion' and
%   'criterion_thresh' is given.

arguments
    bci_model
    data_store
    constants
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
    [data, class_true] = ds2set(data_store);
    scores = predict(model, data(:,bci_model.feat_idx));
else
    % extract true labels
    data_set = readall(data_store);
    class_true = cellfun(@double ,data_set(:,2), 'UniformOutput', true);
    % predict using the model
    scores = predict(model, data_store);
end

class_name = constants.class_name_model;  % the classes we are ussing to train the model
class_label = constants.class_label; % the label we gave to each class

% find idle location
idle_idx = strcmp(class_name, 'Idle');

if ~isempty(options.criterion) && ~isempty(options.criterion_thresh) % predict with criterion
    % get the criterion you desire 
    [crit_values,~,thresholds] = perfcurve(class_true, scores(:,idle_idx), 1, 'XCrit', options.criterion);

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

CM = confusionmat(class_true,class_pred);
accuracy = sum(class_true == class_pred)/length(class_true);
% plot the confusion matrix
if options.print
    figure('Name', [options.CM_title title]);
    confusionchart(CM, class_name);
    disp([options.CM_title ' accuracy is: ' num2str(accuracy)]);
end

end