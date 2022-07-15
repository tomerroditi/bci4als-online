classdef PermuteStftLayer < nnet.layer.Layer ...
        & nnet.layer.Formattable ...
        & nnet.layer.Acceleratable

    properties
        % Layer properties.
        dimorder
    end
    
    methods
        function layer = PermuteStftLayer(NameValueArgs)
            % layer = projectAndReshapeLayer(outputSize,numChannels)
            % creates a projectAndReshapeLayer object that projects and
            % reshapes the input to the specified output size using and
            % specifies the number of input channels.
            %
            % layer = projectAndReshapeLayer(outputSize,numChannels,Name=name)
            % also specifies the layer name.
            
            % Parse input arguments.
            arguments
                NameValueArgs.Name = "";
            end
                        
            % Set layer name.
            layer.Name = NameValueArgs.Name;

            % Set layer description.
            layer.Description = "squeeze input array and change dims to be 'CTB'";
            
            % Set layer type.
            layer.Type = "Permute";
            
        end
        
        function Z = predict(~, X)
            % Forward input data through the layer at prediction time and
            % output the result.
            %
            % Inputs:
            %         layer - Layer to forward propagate through
            %         X     - Input data, specified as a formatted dlarray
            %                 with a "C" and optionally a "B" dimension.
            % Outputs:
            %         Z     - Output of layer forward function returned as 
            %                 a formatted dlarray with format "SSCB".
         
            % Reshape.

            Z = dlarray(squeeze(stripdims(X)), "CTB");
        end
    end
end