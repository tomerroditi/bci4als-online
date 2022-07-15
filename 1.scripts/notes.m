%% to do list:
% big tasks:
% - figure out how to implement tall arrays for continuous segmentations
%   for when we have too much data to handle at once...
% - implement tall arrays in multi_recording objects, add another function
% for adding a recording obj into a multi recording obj and construct the
% multi recording by adding one rec at a time to prevent 'out of memory'
% data when constructing "big data" multi recording obj. adjust the data
% store creation to act properly with the tall array.

% small tasks:
% 1) prepare a script for online model evaluation
% 2) make more recordings - top priority
% 3) test the model in online sessions


%% general notes
% - consider longer time delays (more than 4 seconds) between gestures in the data aquisition
%   protocol with random time difference between gestures - DONE!

% bad recordings from tomer - 1 (low amp in low freq),2 (effective sample rate is ~90 instead of 125), 8(noise around 31.25 HZ)
% 7,14 (one of the channels is completly corrupted), 15 (one channel has low amp in low freq)

% only probabilistic models are suited for this code

% when constructing a feature extraction function, consider dimention 1 as
% trials and dimention 2 as features in the output matrix

%% EEG recording instructures (just some side notes for me)
% - perform some kind of caliberation before starting a recording, meaning
%   check for alpha waves (freq domain), check for spikes after blinking
% - turn off bluetooth devices to prevent noise
% - maybe try to rereference to CZ (might improve the SNR) or avg - DONE!

