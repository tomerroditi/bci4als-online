function big_data_root_path = new_data_folder()
% this function creates a new folder in the data folder, for new big data
% multi recording objects
    listing = dir('9.data');
    if isempty(listing)
        fold_name = num2str(1, '%03.f');
    else
        names = extractfield(listing, 'name');
        names(strcmp(names,'.') | strcmp(names,'..') | strcmp(names, 'readme.txt')) = [];
        names = cellfun(@str2num, names); % convert str to double
        if ~isempty(names)
            fold_name = num2str(max(names) + 1, '%03.f');
        else
            fold_name = num2str(1, '%03.f');
        end
    end
    big_data_root_path = fullfile('9.data', fold_name);
    mkdir(fullfile(big_data_root_path));
end