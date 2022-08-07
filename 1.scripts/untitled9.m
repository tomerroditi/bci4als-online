%% load a cv model

%% get a certain model
model = cv_model.get_model(5);
model.classify_gestures(model.val, plot = true)

%% get models performances
accu = cv_model.accu(:,[1:3, 5:9]);         % models accuracies
gest_accu = cv_model.gest_accu(:,[1:3, 5:9]);  % models gestures accuracies
gest_miss = cv_model.gest_miss(:,[1:3, 5:9]);    % models gestures miss rate
delay = cv_model.delay(:,[1:3, 5:9]);       % models average delays


% compute the model mean accuracy and its std
mean_accu = mean(accu,2); std_accu = std(accu,[],2);
mean_gest_accu = mean(gest_accu,2); std_gest_accu = std(gest_accu,[],2);
mean_gest_miss = mean(gest_miss,2); std_gest_miss = std(gest_miss,[],2);
mean_delay = mean(delay,2); std_delay = std(delay,[],2);
% plot the results
figure('Name', 'model performance');
subplot(2,2,1)
bar(categorical({'train', 'val'}), [mean_accu(1), mean_accu(2)]); hold on;
errorbar(categorical({'train', 'val'}), [mean_accu(1), mean_accu(2)], [std_accu(1), std_accu(2)], LineStyle = 'none', Color = 'black');
title('segment accuracy');
subplot(2,2,2)
bar(categorical({'train', 'val'}), [mean_gest_accu(1), mean_gest_accu(2)]); hold on;
errorbar(categorical({'train', 'val'}), [mean_gest_accu(1), mean_gest_accu(2)], [std_gest_accu(1), std_gest_accu(2)], LineStyle = 'none', Color = 'black');
title('gestures accuracy');
subplot(2,2,3)
bar(categorical({'train', 'val'}), [mean_gest_miss(1), mean_gest_miss(2)]); hold on;
errorbar(categorical({'train', 'val'}), [mean_gest_miss(1), mean_gest_miss(2)], [std_gest_miss(1), std_gest_miss(2)], LineStyle = 'none', Color = 'black');
title('gestures miss rate'); ylim([0, 0.6])
subplot(2,2,4)
bar(categorical({'train', 'val'}), [mean_delay(1), mean_delay(2)]); hold on;
errorbar(categorical({'train', 'val'}), [mean_delay(1), mean_delay(2)], [std_delay(1), std_delay(2)], LineStyle = 'none', Color = 'black');
title('gesture delay');
hold off;


