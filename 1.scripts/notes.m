%% to do list:
% big tasks:
% 1) improve the label protocols

% small tasks:
% 1) prepare a script for online model evaluation
% 5) fix the model explainability function to auto detect the relevant
%    layers


%% general notes
% - consider longer time delays (more than 4 seconds) between gestures in the data aquisition
%   protocol with random time difference between gestures - DONE!

% bad recordings from tomer - 1 (low amp in low freq),2 (effective sample rate is ~90 instead of 125), 8(noise around 31.25 HZ)
% 7,14 (one of the channels is completly corrupted and low sample rate as well), 15 (one channel has low amp in low freq)

% only probabilistic models are suited for this code e.i trees, logistic
% regression, NN etc.. 

% when constructing a feature extraction function, consider dimention 5 as
% trials and dimention 2 as features in the output matrix

%% EEG recording instructures (just some side notes for me)
% - perform some kind of caliberation before starting a recording, meaning
%   check for alpha waves (freq domain), check for spikes after blinking
% - turn off bluetooth devices to prevent noise
% - maybe try to rereference to CZ (might improve the SNR) or avg - DONE!

%% required toolboxes
% 1. DSP tooblox
% 2. Communications toolbox
% 3. Statistics and Machine Learning toolbox
% 4. Deep Learning toolbox
% 5. Parallel Computing toolbox
% 6. Computer Vision toolbox

