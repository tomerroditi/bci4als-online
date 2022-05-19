% this script is for model interpertation

clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load")
options = mdl_struct.options;
model = mdl_struct.model;
constants = options.constants;

plot_weights(model, constants.electrode_loc) 