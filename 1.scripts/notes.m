%% to do list:
% big tasks:
% - figure out how to implement tall arrays for continuous segmentations
%   for when we have too much data to handle at once...

% small tasks:
% 1) prepare a script for online model evaluation
% 2) make more recordings
% 3) test the model in online sessions
% 4) remove signal before and after recording start\end markers
% 5) remove MI6 and add the model learning scripts and add them into
%    'train_my_model' (not urgent)


%% general notes
% - consider longer time delays (more than 4 seconds) between gestures in the data aquisition
%   protocol with random time difference between gestures - DONE!

% bad recordings from tomer - 1 (not sure why),2 (effective sample rate is ~90 instead of 125), 8(noise around 31.25 HZ)
% 7,14 (one of the channels is completly corrupted), 15 (one channel has low
% amp in low freq)

%% EEG recording instructures (just some side notes for me)
% - perform some kind of caliberation before starting a recording, meaning
%   check for alpha waves (freq domain), check for spikes after blinking
% - turn off bluetooth devices to prevent noise
% - maybe try to rereference to CZ (might improve the SNR)

