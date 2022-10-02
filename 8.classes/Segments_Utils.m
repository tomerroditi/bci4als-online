classdef Segments_Utils
    methods (Static)
        function segments_array = filter(segments_array, data_pipeline)
        % filter the time series segments (BP, notch)
            segments_array = filter_segments(segments_array, data_pipeline); 
        end

        function segments_array = normalize(segments_array, data_pipeline)
        % normalize the signal channel (electrode) wise
            segments_array = norm_eeg(segments_array, data_pipeline.quantiles);
        end

        function segments_array = create_sequence(segments_array, data_pipeline)
        % create a sequence from each signal segment
            segments_array = create_sequence(segments_array, data_pipeline);
        end
    
        function features = extract_features(segments_array, data_pipeline) %#ok<INUSL> 
            if ~strcmp(data_pipeline.feat_algo, 'none') 
                % execute the desired feature extraction method
                feat_method = dir('5.feature extraction methods');
                feat_method_name = extractfield(feat_method, 'name');
                if ismember([data_pipeline.feat_algo '.m'], feat_method_name)
                    features = eval([data_pipeline.feat_algo '(segments_array, pipeline);']); % this will call the feature extraction fnc
                else 
                    error(['there is no file named "' data_pipeline.feat_alg '" in the feature extraction method folder.' newline...
                        'please provide a valide file name (exclude the ".m"!) in the my pipeline object']);
                end
            else
                features = [];
            end
        end

        function [seg_or_feat, labels] = oversample(seg_or_feat, labels)
            % this function oversample each class so the data will have a uniform distribution
            % return empty arrays if the input is empty
            if isempty(seg_or_feat)
                seg_or_feat = []; labels = [];
                return
            end

            labels_cats = unique(labels);
            num_max_cat = max(countcats(labels));

            % find each class indices and oversample the data 
            for i = 1:length(labels_cats)
                curr_label = labels_cats(i);
                num_curr_label = sum(labels == curr_label);

                indices = labels == curr_label;
                curr_seg = seg_or_feat(:,:,:,:, indices); % reject all indices of other labels

                ratio = max([round(num_max_cat/num_curr_label), 1]); % ratio to the largest label (idle)
                seg_or_feat = cat(5, seg_or_feat, repmat(curr_seg, 1, 1, 1, 1, ratio - 1));
                labels = cat(1, labels, repmat(curr_label, num_curr_label*(ratio - 1), 1));
            end
        end
    
        function aug_data = augment_data(datastore)
            % this function creates an augmented data from the processed data the
            % NN recieves
            %
            % Inputs:
            %   datastore: a cell array containing the data in the first
            %             column and the labels (as categorical objects) in the second
            %             column
            %
            % outputs:
            %   aug_data: a cell array containing the augmented data in the first
            %             column and the labels (as categorical objects) in the second
            %             column

            % seperate data and labels
            data = datastore(:,1);
            labels = datastore(:,2); 
            
            N = size(data,1); % extract number of samples

            % extract augmentation parameters from global variable
            global augmentation_params
            x_flip_p = augmentation_params('x_flip_p');
            wgn_p = augmentation_params('wgn_p');
            
            % aplly x flip with P probability 
            P = x_flip_p;
            indices_flip = randperm(N, round(N*P));
            data(indices_flip) = cellfun(@(X) flip(X,2), data(indices_flip), "UniformOutput", false);
            
            % aplly white gaussian noise with P probability
            P = wgn_p;
            indices_noise = randperm(N, round(N*P));
            data(indices_noise) = cellfun(@(X) awgn_func(X, 20), data(indices_noise), "UniformOutput", false);
            
            aug_data = [data, labels]; 

            function x = awgn_func(x, snr)
                for i = 1:size(x,3)
                    for j = 1:size(x,4)
                        temp_x = x(:,:,i,j).'; 
                        temp_x = awgn(temp_x, snr, 'measured');
                        x(:,:,i,j) = temp_x.';
                    end
                end
            end
        end
    end
end