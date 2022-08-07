% this script is for model interpertation

clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load")
pipeline = model.my_pipeline;
net = model.model;

model.EEGNet_explain() 
model.load_data();
%% LIME - find influencal pixels
reset(model.train.data_store)
while hasdata(model.train.data_store)
    curr = read(model.train.data_store);
    for i = 1:length(curr)
        label = classify(net, curr{i,1});
        scoremap = imageLIME(net, curr{i,1}, label, 'Model', 'linear');
        figure(1)
        imshow(curr{i,1}); hold on;
        imagesc(scoremap, 'AlphaData', 0.5); title(string(label))
        colormap jet
        pause(1)
    end
end