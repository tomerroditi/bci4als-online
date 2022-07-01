%% to do list:
% big tasks:
% - figure out how to implement tall arrays for continuous segmentations
%   for when we have too much data to handle at once...

% small tasks:
% 4) add a function to evaluate the signal quality when using the bci script
%    or recording new data (inform if something is wrong)
% 5) prepare a script for online model evaluation
% 8) fix the fc activation visualization (not urgent) 
% 9) remove MI6 and add the model learning scripts and add them into
%    'train_my_model' (not urgent)


%% general notes
% - consider longer time delays (more than 4 seconds) between gestures in the data aquisition
% protocol with random time difference between gestures


%% EEG recording instructures (just some side notes for me)
% - perform some kind of caliberation before starting a recording, meaning
%   check for alpha waves (freq domain), check for spikes after blinking
% - turn off bluetooth devices to prevent noise
% - maybe try to rereference to CZ (might improve the SNR)

