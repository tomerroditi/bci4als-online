clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load");
data_pipeline = model.data_pipeline;

% extract some parameters
start_buff = data_pipeline.buffer_start; end_buff = data_pipeline.buffer_end; % buffers
Fs = data_pipeline.sample_rate;
sequence_step_size = data_pipeline.sequence_step_size; % overlap between sequences
segment_duration_sec = data_pipeline.segment_duration_sec;           % segments duration in seconds
segments_step_size_sec = data_pipeline.segments_step_size_sec;           % following segments overlapping duration in seconds
sequence_len = data_pipeline.sequence_len; % length of a sequence to enter in sequence DL models

%% Lab Streaming Layer Init
lib = lsl_loadlib();
% resolve a stream...
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
inlet = lsl_inlet(result{1});
inlet.open_stream()

%% check signal quality
for i = 1:5
    flag = check_streamed_signal(inlet, data_pipeline);
    if flag
        error('signal quality is low, check the electrodes in the openbci gui. try restarting the hardware'); 
    end
end
%% perform a quick finetuning before starting a session if you desire
answer = input('would you like to fine tune the model with new data? type "yes"/"no": ');
if strcmpi(answer, 'yes')
    % 2 - left, 3 - right
    markers = [2;3]; % marker used for each class relative to all clases - make sure an image for the marker is available
    number_of_trials = 10; % number of cues per class
    trial_length = 5; % length in seconds of each cue
    record_me(markers, number_of_trials, trial_length);
    path = uigetdir(data_pipeline.root_path, 'pls select the folder you saved the new recording to');
    model.fine_tune_model(path);
end

%% extract data from stream, preprocess, classify and execute actions
data_size = floor(segment_duration_sec*Fs + sequence_step_size*Fs*(sequence_len - 1) + start_buff + end_buff);
% set a timer object and start the bci program!
t = timer('TimerFcn',"my_bci(inlet, model, my_pipeline, data_size)", 'Period', segments_step_size_sec,... 
    'ExecutionMode', 'fixedRate', 'TasksToExecute', 10000, 'BusyMode', 'drop');
start(t);
input('press any button to stop the BCI')
stop(t)





