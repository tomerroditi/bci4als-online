classdef flat_cat < nnet.layer.Layer ...
        & nnet.layer.Formattable ...
        & nnet.layer.Acceleratable

    methods
        function layer = flat_cat(NameValueArgs)
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

            layer.NumInputs = 2;
            layer.InputNames = {'in1', 'in2'};

            % Set layer name.
            layer.Name = NameValueArgs.Name;

            % Set layer description.
            layer.Description = "flat arrays and concatenate them";
            
            % Set layer type.
            layer.Type = "flatten and cat";
            
        end
        
        function Z = predict(~, X,Y)
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
            x_size = size(X);
            y_size = size(Y);
            X = reshape(X, x_size(1)*x_size(2)*x_size(3),1,1, x_size(4));
            Y = reshape(Y, y_size(1)*y_size(2)*y_size(3),1,1, y_size(4));
            Z = cat(1,X,Y);
        end
    end
end