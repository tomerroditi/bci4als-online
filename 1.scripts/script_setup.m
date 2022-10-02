function script_setup()
% this function adds usefull paths to matlab search path - eeglab, liblsl,
% chanels locations file, the root path of the project.

    % create a constant object
    addpath(genpath('..\8.classes')); % add the root folder of the project to the search path
    paths = Path_Handler();
    
    % add relevant paths to the matlab searching path
    warning('off'); % suppress a warning about function names conflicts (there is nothing to do with it...)
    addpath(genpath(paths.get_root_path())); 
    addpath(genpath(paths.get_eeglab_path()));
    addpath(genpath(paths.get_lab_recorder_path()));
    addpath(genpath(paths.get_liblsls_path()));
    warning('on');

end