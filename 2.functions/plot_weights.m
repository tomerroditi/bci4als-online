function [] = plot_weights(model, used_electrodes) 
    % extracts the weights of the filters in the 2nd (conv2dlayer)
    temporalFilterWeights = model.Layers(2,1).Weights;
    % extracts the weights of the filters in the 4th (groupedconv2dlayer)
    spatialFilterWeights = model.Layers(4,1).Weights;
    % get the amount of spatial and temporal filters
    szSpatial = size(spatialFilterWeights); 
    szTemporal = size(temporalFilterWeights);
    nTemporalFilters = szTemporal(end);
    nSpatialFPerTempF = szSpatial(end - 1);
    % iterate over all filters and generate plots depicting their weights
    % main loop - go over temporal filters
    for indTempFilter = 1:nTemporalFilters
        subplot(3,nTemporalFilters,indTempFilter)
        weigtsTemporal = temporalFilterWeights(:,:,1,indTempFilter);
        L = size(weigtsTemporal,2);
        % calculate X axis ticks
        transformedWs = abs(fft(weigtsTemporal));
        % we have X data points, so we are limited in our ability to
        % present frequency domain information
        fs = 125;                                                           %######### fixed that to be our sample rate ###########
        % run transform fourier to get the weight per freq
        freqs = (0:L/2).*fs./L;
        % remove redundand mirror image of freqs
        transformedWs = transformedWs(1:L/2 + 1);
        transformedWs(2:end-1) = 2.*transformedWs(2:end - 1);
        % plot the weights per frequency
        plot(freqs,transformedWs)
        % this limit is pretty arbitrary, yet we want to keep all plots up
        % to the same scale
        ylim([0 4])
        xticks([freqs(1):10:freqs(end)]);
        xlim([0 freqs(end)])      % change this limit according to the filters you are ussing
        xlabel('Frequency (Hz)')
        ylabel('Amp')
        title(strcat('Temporal Filter=', num2str(indTempFilter)));
        % inner loop - for each temporal filter, go over the spatial
        % filters
        for indSpatialFilter = 1:nSpatialFPerTempF
            % get the spatial filter weights for the specific filter
            weightsSpatial = spatialFilterWeights(:,:,1,indSpatialFilter, indTempFilter);
            weightsSpatial = double(weightsSpatial);
            % plot the topographic map of weights for the filter (in the
            % right subplot index)
            pltIndex = indSpatialFilter  * nTemporalFilters + indTempFilter;
            subplot(3,nTemporalFilters,pltIndex)
            plot_topography(used_electrodes, weightsSpatial , false, '10-20', false,false, 1000);
            title(strcat('Temp F=',num2str(indTempFilter), ' Spatial F=', num2str(indSpatialFilter)));
        end
    end
end