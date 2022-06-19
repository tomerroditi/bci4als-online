function final_ica = ica_decomposition(segments)
% compute the ICA of each section and transform it to the ICA vectors
segments(:,12:13,:) = [];
ICA_data = segments;                                              % just to allocate memory and save run time
for i = 1:size(segments,1)
    ICA_Mdl = rica(squeeze(ICA_data(i,:,:)).', size(ICA_data,2),'Standardize', 1 ); % ICA model
    temp_ICA_data(1,:,:) = transform(ICA_Mdl, squeeze(ICA_data(i,:,:)).').';    % trasform the data
    ICA_data(i,:,:) = temp_ICA_data(1,:,:);
end

% find the ica components that best represents C3, C4 & Cz
locations = logical(strcmp(EEG_chans,'C3') + strcmp(EEG_chans,'C4') + strcmp(EEG_chans,'CZ'));
norm_segments = segments;
a = find(locations)';
final_ica = [];
for v = 1:size(ICA_data,1)
    for i = a
        score = 0;
        electrode = segments(v,i,:);
        mu = ICA_Mdl.Mu(i);
        sigma = ICA_Mdl.Sigma(i);
        electrode = (electrode - mu)./sigma;  % normalize the electrode
        norm_segments(v,i,:) = electrode;
        for j = 1:size(ICA_data,2)
            component = ICA_data(v,j,:);
            pvaf = 1 - var(electrode - component)/var(electrode); % calculate Pvaf
            if pvaf > score % check if its a better ica component to represent the electrode
                score = pvaf;
                comp_num = j;
            end
        end
        final_ica(v,find(locations) == i,:) = ICA_data(v,comp_num,:);
    end
end

% visulize the ica transform
for i = 1:size(norm_segments,1)
    label = targetLabels(1,i);
    t = 1:length(norm_segments(i,1,:));
    figure('Name', strcat('C3 - ', num2str(label)));
    plot(t, squeeze(norm_segments(i,1,:)), t, squeeze(final_ica(i,1,:)));
    legend({'c3','c3 ica'});
    figure('Name', strcat('C4 - ', num2str(label)));
    plot(t, squeeze(norm_segments(i,2,:)), t, squeeze(final_ica(i,2,:)));
    legend({'c4','c4 ica'});
    figure('Name', strcat('CZ - ', num2str(label)));
    plot(t, squeeze(norm_segments(i,3,:)), t, squeeze(final_ica(i,3,:)));
    legend({'cz', 'cz ica'})
end