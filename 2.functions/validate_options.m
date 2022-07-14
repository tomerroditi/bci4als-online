function options = validate_options(options)
% this function is used to change/correct the values of the field in the
% options structure to prevent errors and redandant actions.


if strcmp(options.feat_or_data, 'data')
    options.feat_alg = 'none';
end

if strcmp(options.cont_or_disc, 'discrete')
    options.resample = [0,0,0];
    options.sequence_len = 1;
end

if strcmp(options.model_algo, 'alexnet')
    options.sequence_len = 1;
    options.feat_or_data = 'feat';
    options.feat_alg = 'wavelet'; % remove this if you add more feature functions that can be used as alexnet inputs
end

end