function [sup_vec, time_samp] = fix_times_1(sup_vec, time_samp)
% this function fixes time vectores that have gaps in the time domain
time = sup_vec(2,:);
% set the first time point to be 0
if time(1) ~= 1
    time_samp = time_samp - time(1);
    time = time - time(1);
end
% make time continuous
for i = 1:length(time) - 1
    if time(i+1) - time(i) > 1
        for j = 1:length(time_samp)
            if time_samp(j+1) - time_samp(j) > 60
                time_samp(j+1:end) = time_samp(j+1:end) - (time(i+1) - time(i) + 1);
                time(i+1:end) = time(i+1:end) - (time(i+1) - time(i) + 1);
                break
            end
        end
    end
end
sup_vec(2,:) = time;
end

