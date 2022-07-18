% this script is for model interpertation

clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load")
options = model.options;
net = model.model;
constants = options.constants;

plot_weights(net, constants.electrode_loc) 