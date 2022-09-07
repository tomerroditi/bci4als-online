% this script is for data visualization - this helped me
% make a good and correct normalizations across all recordings and also
% determined if a recording is good enought to use it or reject it.


clc; clear all; close all; %#ok<CLALL> 
% a quick paths check and setup (if required) for the script
script_setup()

%% select folders to aggregate data from
recorders = {'tomer', 'omri', 'nitay', 'itay','02','03','04','05','06','07','08','09','10','12'}; % people we got their recordings
folders_num = {[], [100:101], [], [], [], [], [], [], [], [], [], [], [], []}; % recordings numbers - make sure that they exist

all_rec = multi_recording(recorders,folders_num);
all_rec.plot_data(fft = true, raw = true, filt = true);
