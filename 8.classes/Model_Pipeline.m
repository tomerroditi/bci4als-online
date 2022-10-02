classdef Model_Pipeline
    properties (Access = public)
        model_algo        = 'EEGNet'; % ML model to train, choose from the files in the DL pipelines folder
        
        % training parmas
        oversample_train_data = true;
        augment_train_data = true;
        training_options =  trainingOptions( 'adam'...
                                            ,'Plots','training-progress'...
                                            ,'Verbose', true ...
                                            ,'VerboseFrequency', 100 ...
                                            ,'MaxEpochs', 50 ...
                                            ,'MiniBatchSize', 200 ...  
                                            ,'Shuffle','every-epoch'...
                                            ,'ValidationFrequency', 100 ...
                                            ,'LearnRateSchedule', 'piecewise'...
                                            ,'LearnRateDropPeriod', 35 ...
                                            ,'LearnRateDropFactor', 0.1 ...
                                            ,'OutputNetwork', 'last-iteration'...
                                            ,'BatchNormalizationStatistics', 'moving'...
                                            ,'DispatchInBackground', false);

        % model threshold - criterions of matlabs perfcurv function
        criterion_class = 'idle'; % set to 'none' for default classification (highest probability)
        criterion = 'accu';
        criterion_thres = 1;

        % gesture recognition
        confidence_range = [2:6];
        cool_time_range = [2:6];
    end

    methods
        function obj = Model_Pipeline(varargin)
            % set the given optional inputs as the object properties
            for n = 1:2:size(varargin,2)
                switch varargin{n}
                    case 'model_algo' 
                        obj.model_algo = varargin{n+1};
                    case 'oversample_train_data'
                        obj.oversample_train_data = varargin{n+1};
                    case 'augment_train_data'
                        obj.augment_train_data = varargin{n+1};
                    case 'training_options' 
                        obj.training_options = varargin{n+1};
                    case 'criterion_class'
                        obj.criterion_class = varargin{n+1};
                    case 'criterion'
                        obj.criterion = varargin{n+1};
                    case 'criterion_thres'
                        obj.criterion_thres = varargin{n+1};
                    case 'confidence_range' 
                        obj.confidence_range = varargin{n+1};
                    case 'cool_time_range'
                        obj.cool_time_range = varargin{n+1};
                end
            end
            obj.criterion_class = lower(obj.criterion_class);
        end
    end
end