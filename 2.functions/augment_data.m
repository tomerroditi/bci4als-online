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
C = constants();

N = size(data,1); % extract number of samples

% aplly x flip with P probability 
P = C.x_flip_p;
indices_flip = randperm(N, round(N*P));
data(indices_flip) = cellfun(@(X) flip(X,2), data(indices_flip), "UniformOutput", false);

% aplly white gaussian noise with P probability
P = C.wgn_p;
indices_noise = randperm(N, round(N*P));
data(indices_noise) = cellfun(@(X) awgn_func(X, 20), data(indices_noise), "UniformOutput", false);

aug_data = [data labels];


end

function x = awgn_func(x, snr)
    for i = 1:size(x,3)
        for j = 1:size(x,4)
            temp_x = x(:,:,i,j).'; 
            temp_x = awgn(temp_x, snr, 'measured');
            x(:,:,i,j) = temp_x.';
        end
    end
end
