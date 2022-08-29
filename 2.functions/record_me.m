function  record_me(class_marker, num_trials, trial_len)
% this function...
%
% Inputs:


% set parameters
cue_len          = 1;     % cue length in seconds
ready_len        = 2;     % ready length in seconds
next_len         = 1;     % next length in seconds
start_recordings = 111;   % start recording marker
end_recording    = 99;    % end recording marker
start_trail      = 1111;  % start trial marker
end_trail        = 9;     % end trial marker


%% Lab Streaming Layer Init
% load the LSL library
lib = lsl_loadlib();                    

% start marker lsl stream
info = lsl_streaminfo(lib, 'MarkerStream', 'Markers', 1, 0, 'cf_string', 'myuniquesourceid23443');
outletStream = lsl_outlet(info);        % create an outlet stream using the parameters above
disp('Open Lab Recorder & check for MarkerStream and EEG stream, start recording, return here and hit any key to continue.');
pause;                                  % Wait for experimenter to press a key

%% Prepare markers to execute in each stimulation
class_marker = repmat(class_marker, num_trials, 1); % duplicate labels according to number of trials
class_marker = class_marker(randperm(length(class_marker))); % randomize labels order

%% Record Training Stage
[~, window, white] = evalc('PsychInit()'); % Psychtoolbox Screen Params Init, use evalc to supress annoying messages 
outletStream.push_sample(start_recordings); % start of recording
pause(40); % pause for 60 seconds to create reference for the rest of the recording - usefull for preprocessing
num_trials = length(class_marker);
cross = imread('cross.jpeg', 'jpeg');
for trial = 1:num_trials
    % cross image
    Screen('PutImage', window, cross);
    Screen('Flip', window);
    
    pause_time = 2 + 4.*rand(1); % random float between 4 to 6 
    pause(pause_time); % create uneven time distributed events

    current_trial = class_marker(trial); % What condition is it?
    img_file = ['images\' num2str(class_marker(trial)) '.jpeg'];

    % display "next"
    DrawFormattedText(window, 'Next', 'center','center', white); % place text in center of screen
    Screen('Flip', window);
    pause(next_len);     % "Next" stays on screen

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

