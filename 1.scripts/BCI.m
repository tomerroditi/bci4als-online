clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load");
my_pipeline = model.my_pipeline;

% extract some parameters
start_buff = my_pipeline.buffer_start; end_buff = my_pipeline.buffer_end; % buffers
Fs = my_pipeline.sample_rate;
sequence_overlap = my_pipeline.sequence_overlap; % overlap between sequences
seg_dur = my_pipeline.seg_dur;           % segments duration in seconds
overlap = my_pipeline.overlap;           % following segments overlapping duration in seconds
sequence_len = my_pipeline.sequence_len; % length of a sequence to enter in sequence DL models
step_size = seg_dur - overlap;
seq_step_size = seg_dur - sequence_overlap;

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
    flag = check_streamed_signal(inlet, my_pipeline);
    if flag
        error('signal quality is damaged, check the electrodes in the openbci gui. try restarting the hardware'); 
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
    path = uigetdir(my_pipeline.root_path, 'pls select the folder you saved the new recording to');
    model.fine_tune_model(path);
end

%% extract data from stream, preprocess, classify and execute actions
data_size = floor(seg_dur*Fs + seq_step_size*Fs*(sequence_len - 1) + start_buff + end_buff);
% set a timer object and start the bci program!
t = timer('TimerFcn',"my_bci(inlet, model, my_pipeline, data_size)", 'Period', step_size,... 
    'ExecutionMode', 'fixedRate', 'TasksToExecute', 10000, 'BusyMode', 'drop');
start(t);
input('press any button to stop the BCI')
stop(t)





