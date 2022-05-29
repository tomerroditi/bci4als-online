%% to do list:
% big tasks:
% - create a VAE with the EEGNet structure (need to create custom layers
% for the decoder... this will take alot of work)
% - create the script for preprocessing hyperparameters optimization

% small tasks:
% - validate the WGN we add as an augmentation
% - add an option to choose certain time point to start from in the
% segments options (e.g 1 second before the cue)
% - add an option to differ between time delay for each new segment and
% time delay between sequenced segments.
% - add a function to validate the options structure which alert if
% unsupported values are givven and asigns default values for missing
% fields. insert this function in 'recording' constructor!


