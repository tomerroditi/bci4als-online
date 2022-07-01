function  record_me(args)
%% MOTOR IMAGERY Training
% This code creates a training paradigm with (#) numTargets on screen for
% (#) numTrials. Before each trial, one of the targets is cued (and remains
% cued for the entire trial).This code assumes EEG is recorded and streamed
% through LSL for later offline preprocessing and model learning.

% The function prompts for a test number, and creates a new folder in
% $rootFolder$. Next, the training begins according to parameters given
% after %Parameters%. The training will be saved into a vector which
% corresponds to the true label of the trial. Simultaneously, the
% lab recorder should create an XDF file(EEG.xdf) that should be paired with
% the training vector.

arguments
    args.constants = constants();
end
constant = args.constants;

% set parameters
trial_len = constant.trial_length;   % each trial length in seconds 
cue_len = 0.5;                       % cue length in seconds
ready_len = 1;                     % ready length in seconds
next_len = 1;                      % next length in seconds
num_trials = constant.num_trials; % number of trials per class
start_recordings = constant.start_recordings;                 % start recording marker
end_recording = constant.end_recording;                      % end recording marker
start_trail = constant.start_trail;                      % start trial marker
end_trail = constant.end_trail;                       % end trial marker
classes_all = constant.class_names;
classes_rec = constant.class_name_rec;
labels = constant.class_marker;

%% Lab Streaming Layer Init
% load the LSL library
disp('Loading the Lab Streaming Layer library...');
lib = lsl_loadlib();                    

% start marker lsl stream
disp('Opening Marker Stream...');
info = lsl_streaminfo(lib, 'MarkerStream', 'Markers', 1, 0, 'cf_string', 'myuniquesourceid23443');
outletStream = lsl_outlet(info);        % create an outlet stream using the parameters above
disp('Open Lab Recorder & check for MarkerStream and EEG stream, start recording, return here and hit any key to continue.');
pause;                                  % Wait for experimenter to press a key

%% Prepare labels to execute in each stimulation
labels = labels(ismember(classes_all, classes_rec)); % use only the classes intended to record
labels = repmat(labels, 1, num_trials); % duplicate labels according to number of trials
labels = labels(randperm(length(labels))); % randomize labels order

%% Record Training Stage
[window, white] = PsychInit(); % Psychtoolbox Screen Params Init
outletStream.push_sample(start_recordings); % start of recording
pause(60); % pause for 60 seconds to create reference for the rest of the recording
num_trials = length(labels);
for trial = 1:num_trials
    pause_time = 4 + 2.*rand(1); % random float between 4 to 6 
    pause(pause_time); % create uneven time distributed events
    
    current_trial = labels(trial); % What condition is it?
    img_file = ['images\' num2str(labels(trial)) '.jpeg'];

    % display "next"
    DrawFormattedText(window, 'Next', 'center','center', white); % place text in center of screen
    Screen('Flip', window);
    pause(next_len);               % "Next" stays on screen

    % display the image related to the current class for a brief time
    ima = imread(img_file, 'jpeg');
    Screen('PutImage', window, ima);  % put image on screen
    Screen('Flip', window);           % now visible on screen
    pause(cue_len);

    % display "Ready"
    DrawFormattedText(window, 'Ready', 'center', 'center', white); % place text in center of screen
    Screen('Flip', window);
    pause(ready_len);                         % "Ready" stays on screen
    
    % display the image related to the current class
    Screen('PutImage', window, ima);         % put image on screen
    Screen('Flip', window);                  % now visible on screen
    outletStream.push_sample(start_trail);    % new trial marker
    outletStream.push_sample(current_trial);  % the class of the trial marker
    pause(trial_len);                      % target stays on screen
    outletStream.push_sample(end_trail);      % end trial marker
end
%% End of recording session
outletStream.push_sample(end_recording);   % 99 is end of experiment
ShowCursor;
sca;
Priority(0);
disp('Stop the LabRecorder recording!');
end

