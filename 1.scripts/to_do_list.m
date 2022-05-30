%% to do list:
% big tasks:
% - create a VAE with the EEGNet structure (need to create custom layers
% for the decoder... this will take alot of work)
% - create the script for preprocessing hyperparameters optimization

% small tasks:
% - validate the WGN we add as an augmentatio
% - add a function to validate the options structure which alert if
% unsupported values are givven and asigns default values for missing
% fields. insert this function in 'recording' constructor!
% - add statistical analysis and visualize it
% -figure out what to do with the statistical analysis, maybe use it to
% recognize noisy recordings. 
% - figure out what to do with high amplitude points in a recording, maybe
% clip them to some threshold
% - add visualization of filtered raw data in the stat analysis function
% - add an option to controll the augmentations from Constants object


