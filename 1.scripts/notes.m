%% to do list:
% big tasks:
% - figure out how to implement tall arrays for continuous segmentations
%   for when we have too much data to handle at once...

% small tasks:
% - fix the fc activation visualization
% - verify the location of the electrodes in the plot weights function (very important!)
% - add the mean of the train set in the input layer of EEGNet
% - build a transfer learning script to check the possibility of using
%   EEGNet as cross subject model
% - add a function to evaluate the signal quality when using the bci script
%   or recording new data (inform if something is wrong)
% - prepare a script for online model evaluation
% - insert model threshold as a field in the model structure we save and
%   load it when using the BCI script
% - change the resample method to calculate automaticly the resample
%   factors
% - remove MI6 and add the model learning scripts and add them into
%   'train_my_model'
% - fix the labeling and sup_vec creation in discrete segmentation



%% general notes
% - consider longer time delays (more than 4 seconds) between gestures in the data aquisition
% protocol with random time difference between gestures


%% EEG recording instructures (just some side notes for me)
% - perform some kind of caliberation before starting a recording, meaning
%   check for alpha waves (freq domain), check for spikes after blinking
% - turn off bluetooth devices to prevent noise
% - maybe try to rereference to CZ (might improve the SNR)

