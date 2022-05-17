%% to do list:
% - create a VAE with the EEGNet structure (need to create custom layers
% for the decoder... this will take alot of work)
% - create the script for preprocessing hyperparameters optimization
% - run the bilstm model and compare to the lstm 
% - in validate_model_c script, load the data into train,val,test,new_data
% objects, so when visualizing them we can know who belogns to each set.
% - validate the WGN we add as an augmentation

% - change the MI2 data segmentation function to recieve raw data and
% markers instead of path.
% - create a function to read an edf file and return the data and markers
% in the same way of the XDF files