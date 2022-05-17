classdef reshape_c_dim < nnet.layer.Layer ...
        & nnet.layer.Formattable ...
        & nnet.layer.Acceleratable

    methods
        function layer = reshape_c_dim(num,NameValueArgs)
            % layer = projectAndReshapeLayer(outputSize,numChannels)
            % creates a projectAndReshapeLayer object that projects and
            % reshapes the input to the specified output size using and
            % specifies the number of input channels.
            %
            % layer = projectAndReshapeLayer(outputSize,numChannels,Name=name)
            % also specifies the layer name.
            
            % Parse input arguments.
            arguments
                num
                NameValueArgs.Name = "";
            end

            % Set layer name.
            layer.Name = NameValueArgs.Name;

            % Set layer description.
            layer.Description = "reorder chanel dimention";
            
            % Set layer type.
            layer.Type = "reorder";
            
        end
        
        function Z = predict(~, x)
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
            dim = finddim(x, 'C');
            x_1 = x(:,:,1:4:end,:);
            x_2 = x(:,:,2:4:end,:);
            x_3 = x(:,:,3:4:end,:);
            x_4 = x(:,:,4:4:end,:);
            Z = cat(dim,x_1,x_2,x_3,x_4);
        end
    end
end