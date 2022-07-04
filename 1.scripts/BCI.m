clc; clear all; close all;
% a quick paths check and setup (if required) for the script
script_setup()

%% load the model and its options
uiopen("load"); 
options = mdl_struct.options;
model = mdl_struct.model;
constants = options.constants;

% extract some parameters
start_buff = constants.buffer_start; end_buff = constants.buffer_end; % buffers
Fs = constants.sample_rate;
sequence_overlap = options.sequence_overlap; % overlap between sequences
seg_dur = options.seg_dur;           % segments duration in seconds
overlap = options.overlap;           % following segments overlapping duration in seconds
sequence_len = options.sequence_len; % length of a sequence to enter in sequence DL models
step_size = seg_dur - overlap;
seq_step_size = seg_dur - sequence_overlap;

constants.cool_time = 5;
constants.raw_pred_action = 5;
constants.model_thresh = mdl_struct.thresh;


%% perform a quick finetuning before starting a session
answer = input('would you like to fine tune the model with new data? type "yes"/"no": ');
if strcmpi(answer, 'yes')
    disp('enter the desired path to save the recording in the Lab Recorder Gui, change the file name to EEG.xdf!');
    system([constants.lab_recorder_path '\LabRecorder.exe'])
    record_me()
    path = uigetdir(constants.root_path, 'pls select the folder you saved the new recording to');
    model = fine_tune_model(mdl_struct, path);
end

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
check_streamed_signal(inlet, options, constants);
flag = false;
t_1 = timer('TimerFcn',"flag = check_streamed_signal(inlet, options, constants);", 'Period', 2,... 
    'ExecutionMode', 'fixedRate', 'TasksToExecute', 5, 'BusyMode', 'drop');
start(t_1)
while t_1.TasksExecuted < 5
    pause(4)
    if flag
        error('signal quality is damaged, check the electrodes in the openbci gui. try restarting the hardware'); %#ok<UNRCH> 
    end
end
delete t_1 % its a good practice to delete timers after calling them
%% extract data from stream, preprocess, classify and execute actions
data_size = floor(seg_dur*Fs + seq_step_size*Fs*(sequence_len - 1) + start_buff + end_buff);
% set a timer object
t = timer('TimerFcn',"my_bci(inlet, model, options, constants, data_size)", 'Period', step_size,... 
    'ExecutionMode', 'fixedRate', 'TasksToExecute', 1000, 'BusyMode', 'drop');
start(t);





