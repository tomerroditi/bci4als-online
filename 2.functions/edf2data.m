function [data, markers] = edf2data(path)
% this function reads an edf file from the given path and return the data
% and markers it stores.
%
% Inputs:
%   - path: a local path to the folder containing the edf file
%
% Outputs:
%   - data: raw data extracted from the edf file
%   - markers: markers extracted from the edf file
%   - labels: the labels we inticipate that the data has (we construct it
%   for compatibility reasons only)

% load the file and extract the data from it
[TT_data, TT_mark] = edfread([path, '\eeg.edf']);
data = cell2mat(TT_data.Variables).';
mark_names = TT_mark.Annotations;
mark_times = TT_mark.Onset;

types = mark_names;
% rename the event types
types(strcmp(mark_names, 'OVTK_GDF_Start_Of_Trial')) = '1111.000000000000';
types(strcmp(mark_names, 'OVTK_GDF_Right')) = '2.000000000000000';
types(strcmp(mark_names, 'OVTK_GDF_End_Of_Trial')) = '9.000000000000000';
types(strcmp(mark_names, 'OVTK_GDF_Tongue')) = '1.000000000000000';
types(strcmp(mark_names, 'OVTK_StimulationId_ExperimentStart')) = '111.0000000000000';
types(strcmp(mark_names, 'OVTK_StimulationId_ExperimentStop')) = '99.00000000000000';

% keep only relevant markers
idx = ismember(types, {'1111.000000000000','2.000000000000000','9.000000000000000',...
                       '1.000000000000000','111.0000000000000','99.00000000000000'});
types = char(types(idx));
latency = round(time2num(mark_times(idx)).*125); % sampling rate is 125 [Hz]
latency(ismember(types, "1111.000000000000")) = latency(ismember(types, "1111.000000000000")) + 2*125; % fix a time shift between start marker and actual start of trial
duration = ones(length(latency),1);

% apperantly some recordings were interapted before the end expirement
% marker so we will correct it.
if strcmp(types(end,:), '1111.000000000000')
    types(end,:) = '99.00000000000000';
elseif ~strcmp(types(end,:), '99.00000000000000')
    types(end + 1,:) = '99.00000000000000';
end

% create a atructure array for the markers
for i = 1:length(latency)
    markers(i).type = types(i,:);
    markers(i).latency = latency(i);
    markers(i).duration = duration(i);
end

end









