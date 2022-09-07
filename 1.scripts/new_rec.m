clc; clear all; close all;

% this script is for recording new data.
% 1. open the openbci gui and connect to the electrodes setup
% 2. load the desired settings in the gui and start an lsl stream
% 3. open labrecorder and unmark the "BIDS" window, change the file name to
%    "EEG.xdf", and set the saving path
% 4. make sure the electrodes are placed correctly - this is very important
% 5. run the script and follow the instructions in the command window
% 6. when the simulation is finished stop the labrecorder!.

% a quick paths check and setup (if required) for the script
script_setup();

%% new recording parameters 
% 2 - left, 3 - right
markers = [2;3]; % marker used for each class relative to all clases - make sure an image for the marker is available
number_of_trials = 20; % number of cues per class
trial_length = 5; % length in seconds of each cue

%% Lab Streaming Layer Init
lib = lsl_loadlib();
% resolve a stream...
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
inlet = lsl_inlet(result{1});
inlet.open_stream()
%% call the simulation function
record_me(markers, number_of_trials, trial_length);
disp('Finished simulation and EEG recording. pls Stop the LabRecorder!');





