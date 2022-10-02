classdef MyCombinedDatastore < matlab.io.Datastore ...
                             & matlab.mixin.Copyable ...
                             & matlab.io.datastore.FileWritable ...
                             & matlab.io.datastore.mixin.Subsettable ...
                             & matlab.mixin.CustomDisplay

    %MyCombinedDatastore  A Datastore that conceptually represents the combining
    %   of multiple datastores into a single datastore.
    %
    %   NEWDS = matlab.io.datastore.MyCombinedDatastore(DSCELL) takes a cell
    %   array of datastores, DSCELL, and returns NEWDS, a MyCombinedDatastore.
    %   MyCombinedDatastore makes a copy of all the datastores in DSCELL and
    %   resets each of them, storing the result in the UnderlyingDatastores
    %   property. Conceptually, NEWDS is a new datastore instance that is
    %   the horizontally concatenated result of read from each of the
    %   underlying datastores.
    %
    %   MyCombinedDatastore Methods:
    %
    %   preview         -    Read the subset of data from the datastore that is
    %                        returned by the first call to the read method.
    %   read            -    Read subset of data from the datastore.
    %   readall         -    Read all of the data from the datastore.
    %   hasdata         -    Returns true if there is more data in the datastore.
    %   reset           -    Reset the datastore to the start of the data.
    %   combine         -    Form a single datastore from multiple input
    %                        datastores.
    %   transform       -    Define a function which alters the underlying data
    %                        returned by the read() method.
    %   shuffle         -    Return a new MyCombinedDatastore that shuffles 
    %                        all the data in the underlying datastores.
    %   partition       -    Return a new MyCombinedDatastore that contains
    %                        partitioned parts of the original underlying 
    %                        datastores.
    %   numpartitions   -    Return an estimate for a reasonable number of
    %                        partitions to use with the partition function.
    %   writeall        -    Writes all the data in the datastore to a new 
    %                        output location.
    %
    %   MyCombinedDatastore Properties:
    %
    %   UnderlyingDatastores     -  The original underlying datastores that
    %                               will be read from. The read of a
    %                               MyCombinedDatastore is defined by calling
    %                               read on each of the UnderlyingDatastores
    %                               and then vertically concatenating the
    %                               data from read together.
    %
    %   SupportedOutputFormats   -  List of formats supported for writing
    %                               by this datastore.
    %
    %   See also matlab.io.Datastore.transform, matlab.io.Datastore.combine
    
    %   Copyright 2018-2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        % UnderlyingDatastores A cell array which contains the datastores
        % which were combined.
        UnderlyingDatastores (1, :) cell;
    end
    
    properties (Constant)
        SupportedOutputFormats = matlab.io.datastore.writer.FileWriter.SupportedOutputFormats;
    end

    properties (Constant, Hidden)
        DefaultOutputFormat = string(missing);
    end

    methods
        function ds = MyCombinedDatastore(varargin)
        %MyCombinedDatastore   Construct a MyCombinedDatastore object
        %
        %   DSOUT = MyCombinedDatastore(ds1, ds2, ...) creates a
        %   MyCombinedDatastore object containing multiple input datastores.
        %
        %   See also: read, reset, hasdata, combine
            
            if nargin > 0
                datastoresIn = validateAndFlattenDatastoreList(varargin);
                ds.UnderlyingDatastores = datastoresIn;
                for idx = 1:numel(ds.UnderlyingDatastores)
                    ds.UnderlyingDatastores{idx} = copy(ds.UnderlyingDatastores{idx});
                end
                
                reset(ds); % Make sure that each of the underlying datastores is reset to beginning
            end
        end
        
        function data = readall(ds, varargin)

        %READALL   Returns all combined data from the MyCombinedDatastore
        %
        %   DATA = READALL(CDS) returns all of the horizontally-concatenated
        %   data within this MyCombinedDatastore.
        %
        %   DATA = READALL(DS, "UseParallel", TF) specifies whether a parallel
        %   pool is used to read all of the data. By default, "UseParallel" is
        %   set to false.
        %
        %   See also read, hasdata, reset, preview
           
            copyds = copy(ds);
            reset(copyds);
            
            if ~hasdata(copyds)
                % We can't actually know the number of columns that would
                % result from an empty datastore since we can't call read,
                % so we can't call: cell.empty(0,numCols), since we don't
                % know numCols.
                if nargin > 1
                    matlab.io.datastore.read.validateReadallParameters(varargin{:})
                end
                data = {};
                return
            end
            data = readall@matlab.io.Datastore(copyds, varargin{:});
        end
        
        function [data, info] = read(ds)
        %READ   Read data and information about the extracted data
        %
        %   DATA = READ(CDS) returns the horizontal concatentation of 
        %   data read from all the underlying datastores in this
        %   MyCombinedDatastore.
        %   
        %   [DATA, INFO] = read(CDS) also returns an N-by-1 cell array 
        %   combining the second output of the READ method on all the
        %   underlying datastores.
        %
        %   See also hasdata, reset, readall, preview

            if ~hasdata(ds)
                error(message('MATLAB:datastoreio:splittabledatastore:noMoreData'));
            end
            
            numDatastores = numel(ds.UnderlyingDatastores);
            data = cell(1, numDatastores);
            info = cell(1, numDatastores);
            for ii = 1:numel(ds.UnderlyingDatastores)
                if hasdata(ds.UnderlyingDatastores{ii})
                    [data{ii}, info{ii}] = read(ds.UnderlyingDatastores{ii});
                    data{ii} = iMakeUniform(data{ii}, ds.UnderlyingDatastores{ii});
                end
            end
            data = vertcat(data{:});
        end
        
        function reset(ds)
        %RESET   Reset all the underlying datastores to the start of data
        %
        %   See also: hasdata, read

            for ii = 1:numel(ds.UnderlyingDatastores)
                reset(ds.UnderlyingDatastores{ii});
            end
        end
        
        function tf = hasdata(ds)
        %HASDATA   Returns true if more data is available to read
        %
        %   Return a logical scalar indicating availability of data. This
        %   method should be called before calling read.
        %
        %   This method only returns true if all underlying datastores in
        %   the MyCombinedDatastore have data available for reading.
        %
        %   See also: reset, read

            % If all of the underlying datastores are out of data, the
            % MyCombinedDatastore is out of data.
            tf = ~isempty(ds.UnderlyingDatastores) && any(cellfun(@(c) hasdata(c),ds.UnderlyingDatastores));
        end
        
        function s = saveobj(ds)
            s.UnderlyingDatastores = ds.UnderlyingDatastores;
            s.SupportedOutputFormats = ds.SupportedOutputFormats;
        end
        
        % Overriding writeall to customize m-help.
        function writeall(ds, location, varargin)
            %WRITEALL    Read all the data in the datastore and write to disk
            %   WRITEALL(DS, OUTPUTLOCATION, "FileFormat", FORMAT) 
            %   writes files using the specified file format. The allowed 
            %   FORMAT values are: 
            %     - Tabular formats: "txt", "csv", "xlsx", "xls",
            %     "parquet", "parq"
            %     - Image formats: "png", "jpg", "jpeg", "tif", "tiff"
            %     - Audio formats: "wav", "ogg", "flac", "mp4", "m4a"
            %
            %   WRITEALL(__, "FolderLayout", LAYOUT) specifies whether folders
            %   should be copied from the input data locations. Specify
            %   LAYOUT as one of these values:
            %
            %     - "duplicate" (default): Input files are written to the output
	        %       folder using the folder structure under the folders listed
            %       in the "Folders" property.
            %
            %     - "flatten": Files are written directly to the output
            %       location without generating any intermediate folders.
            %
            %   WRITEALL(__, "FilenamePrefix", PREFIX) specifies a common
            %   prefix to be applied to the output file names.
            %
            %   WRITEALL(__, "FilenameSuffix", SUFFIX) specifies a common
            %   suffix to be applied to the output file names.
            %
            %   WRITEALL(DS, OUTPUTLOCATION, "WriteFcn", @MYCUSTOMWRITER) 
            %   customizes the function that is executed to write each 
            %   file. The signature of the "WriteFcn" must be similar to:
            %      
            %      function MYCUSTOMWRITER(data, writeInfo, outputFmt, varargin)
            %         ...
            %      end
            %
            %   where 'data' is the output of the read method on the
            %   datastore, 'outputFmt' is the output format to be written,
            %   and 'writeInfo' is a struct containing the
            %   following fields:
            %
            %     - "ReadInfo": the second output of the read method.
            %
            %     - "SuggestedOutputName": a fully qualified, unique file
            %       name that meets the location and naming requirements.
            %
            %     - "Location": the location argument passed to the write
            %       method.
            %   Any optional Name-Value pairs can be passed in via varargin.
            %
            %   See also: matlab.io.datastore.MyCombinedDatastore
            import matlab.io.datastore.write.*;
            try
                % Validate the location input first.
                location = validateOutputLocation(ds, location);
                ds.OrigFileSep = matlab.io.datastore.internal.write.utility.iFindCorrectFileSep(location);

                % if this datastore is backed by files, get list of files
                files = getFiles(ds);

                % if this datastore is backed by files, get list of folders
                folders = getFolders(ds);

                % Set up the name-value pairs
                nvStruct = parseWriteallOptions(ds, varargin{:});
                
                % Check if the underlying datastore initialized
                % SupportedOutputFormats
                try
                    underlyingFmts = getUnderlyingSupportedOutputFormats(ds);
                catch
                    underlyingFmts = [];
                end
                outFmt = [ds.SupportedOutputFormats, underlyingFmts];

                % Validate the name-value pairs
                nvStruct = validateWriteallOptions(ds, folders, nvStruct, outFmt);

                % Construct the output folder structure.
                createFolders(ds, location, folders, nvStruct.FolderLayout);

                % Write using a serial or parallel strategy.
                writeParallel(ds, location, files, nvStruct);
            catch ME
                % Throw an exception without the full stack trace. If the
                % MW_DATASTORE_DEBUG environment variable is set to 'on',
                % the full stacktrace is shown.
                handler = matlab.io.datastore.exceptions.makeDebugModeHandler();
                handler(ME);
            end
        end

        function tf = isPartitionable(ds)
        %isPartitionable   returns true if this datastore is partitionable
        %
        %   A MyCombinedDatastore is only partitionable when all of its
        %   underlying datastores are one of the following:
        %    - datastores that provide an implementation of the SUBSET
        %      method,
        %    - TransformedDatastores over datastores that provide an
        %      implementation of a SUBSET method,
        %    - CombinedDatastores where every underlying datastore
        %      provides an implementation of a SUBSET method.
        %
        %   This ensures that the horizontal association of data is 
        %   preserved even after partitioning.
        %
        %   See also: isShuffleable, partition, numpartitions, subset

            tf = ds.isSubsettable();
        end
        
        function tf = isShuffleable(ds)
        %isShuffleable   returns true if this datastore is shuffleable
        %
        %   A MyCombinedDatastore is only shuffleable when all of its 
        %   underlying datastores are one of the following:
        %    - datastores that provide an implementation of the SUBSET
        %      method,
        %    - TransformedDatastores over datastores that provide an
        %      implementation of a SUBSET method,
        %    - CombinedDatastores where every underlying datastore
        %      provides an implementation of a SUBSET method.
        %
        %   This ensures that the horizontal association of data is 
        %   preserved even after shuffling.
        %
        %   See also: isPartitionable, shuffle, 
        %             matlab.io.datastore.MyCombinedDatastore/subset
        
            tf = ds.isSubsettable();
        end
        
        function ds = shuffle(ds)
        %SHUFFLE    Return a shuffled version of this MyCombinedDatastore
        %
        %   NEWDS = SHUFFLE(CDS) returns a randomly shuffled copy of CDS.
        %
        %   A MyCombinedDatastore is only shuffleable when all of its 
        %   underlying datastores are subsettable. The isSubsettable
        %   method indicates whether a datastore is subsettable or not.
        %
        %   See also isShuffleable, matlab.io.datastore.Shuffleable
            for i = 1:numel(ds.UnderlyingDatastores)
%                 ds.UnderlyingDatastores{i}.verifySubsettable("shuffle");
                ds.UnderlyingDatastores{i} = ds.UnderlyingDatastores{i}.shuffle();
            end
        end
        
        function partds = partition(ds, n, index)
        %PARTITION   Return a MyCombinedDatastore containing a part of the
        %   underlying datastore.
        %
        %   SUBDS = PARTITION(CDS, N, INDEX) partitions CDS into
        %   N parts and returns the partitioned Datastore, SUBDS,
        %   corresponding to INDEX. An estimate for a reasonable
        %   value for N can be obtained by using the NUMPARTITIONS
        %   function.
        %        
        %   A MyCombinedDatastore is only partitionable when all of its 
        %   underlying datastores are partitionable. The isPartitionable
        %   method indicates whether a datastore is partitionable or not.
        %
        %   See also: isPartitionable, numpartitions

            ds.verifySubsettable("partition");
            partds = partition@matlab.io.datastore.mixin.Subsettable(ds, n, index);
        end
    end
    
    methods (Hidden)
        function frac = progress(ds)
        %PROGRESS   Percentage of consumed data between 0.0 and 1.0
        %
        %   Return a fraction between 0.0 and 1.0 indicating progress as a
        %   double.
        %
        %   The progress of a MyCombinedDatastore is equal to the maximum 
        %   progress amongst all the underlying datastores.
        %
        %   See also read, hasdata, reset, readall, preview

            if isempty(ds.UnderlyingDatastores)
                % Progress is always 1 if there are no underlying datastores.
                % This helps provide an indicator that it is not valid to call
                % read on an empty MyCombinedDatastore.
                frac = 1;
            else
                % If any one datastore has reached 100% progress, read is
                % completed. Therefore the maximum progress between all
                % underlying datastores will be a good indicator of the 
                % progress of the MyCombinedDatastore in general.
                frac = max(cellfun(@progress, ds.UnderlyingDatastores));
            end
        end

        function tf = isSubsettable(ds)
        %isSubsettable    returns true if this datastore is subsettable
        %
        %   All underlying datastores must be subsettable in order for a 
        %   MyCombinedDatastore to be subsettable.
        %
        %   See also: isPartitionable, subset, numobservations

            tf = all(cellfun(@isSubsettable, ds.UnderlyingDatastores));
        end
        
        function tf = isRandomizedReadable(ds)
        %isRandomizedReadable    returns true if this datastore is known to
        %   reorder data at random after calling reset or read.
        %
        %   A MyCombinedDatastore is considered to be reading randomized
        %   data if any underlying datastore returns isRandomizedReadable
        %   true.
        %
        %   See also: isPartitionable, partition, read
            
            % Check if any underlying datastores are RandomizedReadable or not.
            tf = any(cellfun(@isRandomizedReadable, ds.UnderlyingDatastores));
        end
        
        function subds = subset(ds, indices)
        %SUBSET   returns a new MyCombinedDatastore containing the 
        %   specified observation indices
        %
        %   SUBDS = SUBSET(DS, INDICES) creates a deep copy of the input
        %   datastore DS containing observations corresponding to INDICES.
        %
        %   It is only valid to call the SUBSET method on a
        %   MyCombinedDatastore if it returns isSubsettable true.
        %
        %   INDICES must be a vector of positive and unique integer numeric
        %   values. INDICES can be a 0-by-1 empty array and does not need 
        %   to be provided in any sorted order when nonempty.
        %
        %   The output datastore SUBDS, contains the observations
        %   corresponding to INDICES and in the same order as INDICES.
        %
        %   INDICES can also be specified as a N-by-1 vector of logical
        %   values, where N is the number of observations in the datastore.
        %
        %   See also matlab.io.Datastore.isSubsettable, 
        %   matlab.io.datastore.mixin.Subsettable.numobservations, 
        %   matlab.io.datastore.ImageDatastore.subset

            ds.verifySubsettable("subset");

            import matlab.io.datastore.internal.validators.validateSubsetIndices;

            try
            indices = validateSubsetIndices(indices, ds.numobservations(), ...
                'MyCombinedDatastore');
            catch ME
                % Provide a more accurate error message in the empty subset case.
                if ME.identifier == "MATLAB:datastoreio:splittabledatastore:zeroSubset"
                    msgid = "mycombineddatastore:zeroSubset";
                    error(message(msgid, "MyCombinedDatastore"));
                end
                throw(ME)
            end
            
            % Forward to the underlying datastore's subset methods
            fcn = @(ds) ds.subset(indices);
            subds = cellfun(fcn, ds.UnderlyingDatastores, "UniformOutput", false);
            subds = MyCombinedDatastore(subds{:});
        end

        function n = numobservations(ds)
        %NUMOBSERVATIONS   the number of observations in this datastore
        %
        %   N = NUMOBSERVATIONS(DS) returns the number of observations in
        %   the current datastore state. 
        %
        %   All integer values between 1 and N are valid indices for the 
        %   SUBSET method.
        %
        %   DS must be a valid datastore that returns isSubsettable true.
        %   N is a non-negative double scalar.
        %   
        %   See also matlab.io.Datastore.isSubsettable,
        %   matlab.io.datastore.mixin.Subsettable.subset

            ds.verifySubsettable("numobservations");
            % Handle the empty case first.
            if isempty(ds.UnderlyingDatastores)
                n = 0;
            else
                n = min(cellfun(@numobservations, ds.UnderlyingDatastores));
            end
        end

        function result = visitUnderlyingDatastores(ds, visitFcn, combineFcn)
        %visitUnderlyingDatastores   Overload for MyCombinedDatastore.
        %
        %   See also: matlab.io.Datastore.visitUnderlyingDatastores

            % Visit MyCombinedDatastore itself.
            % Performs validation of the function handles too.
            result = ds.visitUnderlyingDatastores@matlab.io.Datastore(visitFcn, combineFcn);

            % Visit all the UnderlyingDatastores and combine the results together.
            for index = 1:numel(ds.UnderlyingDatastores)
                underlyingDs = ds.UnderlyingDatastores{index};
                underlyingResult = underlyingDs.visitUnderlyingDatastores(visitFcn, combineFcn);

                result = combineFcn(result, underlyingResult);
            end
        end

    end

    methods(Access = {?matlab.io.datastore.FileWritable, ...
            ?matlab.bigdata.internal.executor.FullfileDatastorePartitionStrategy})
        function files = getFiles(ds)
            files = {};
            for idx = 1:numel(ds.UnderlyingDatastores)
                try
                    files = getFiles(ds.UnderlyingDatastores{idx});
                    return;
                catch
                end
            end
            if isempty(files)
                error(message("MATLAB:datastoreio:datastorewrite:NotBackedByFiles"));
            end
        end
    end

    methods (Access = 'protected')
        function cpObj = copyElement(ds)
            cpObj = copyElement@matlab.mixin.Copyable(ds);
            
            % Deep copy each of the underlying datastores
            for idx = 1:numel(ds.UnderlyingDatastores)
                ds.UnderlyingDatastores{idx} = copy(ds.UnderlyingDatastores{idx});
            end
        end
        
        function n = maxpartitions(ds)
        %MAXPARTITIONS Return the maximum number of partitions
        %   possible for the datastore.

            ds.verifySubsettable("numpartitions");
            n = ds.numobservations();
        end

        function folders = getFolders(ds)
            folders = {};
            for idx = 1:numel(ds.UnderlyingDatastores)
                try
                    folders = getFolders(ds.UnderlyingDatastores{idx});
                    return;
                catch
                end
            end
        end

        function filename = getCurrentFilename(~, info)
            %GETCURRENTFILENAME Get the current file name
            %   Get the name of the file read by the datastore
            if iscell(info)
                if isfield(info{1}, "Filename")
                    filename = string(info{1}.Filename);
                else
                    filename = "";
                end
            elseif isfield(info, "Filename")
                filename = string(info.Filename);
            else
                filename = "";
            end
        end

        function displayScalarObject(ds)
            % header
            disp(getHeader(ds));
            group = getPropertyGroups(ds);
            matlab.mixin.CustomDisplay.displayPropertyGroups(ds, group);
            disp(getFooter(ds));
        end

        function outFmts = getUnderlyingSupportedOutputFormats(ds)
            outFmts = [];
            for idx = 1:numel(ds.UnderlyingDatastores)
                if isa(ds.UnderlyingDatastores{idx}, "MyCombinedDatastore") || ...
                        isa(ds.UnderlyingDatastores{idx}, "matlab.io.datastore.TransformedDatastore")
                    outFmts = [outFmts, getUnderlyingSupportedOutputFormats(ds.UnderlyingDatastores{idx})]; %#ok<AGROW>
                else
                    outFmts = [outFmts, ds.UnderlyingDatastores{idx}.SupportedOutputFormats]; %#ok<AGROW>
                end
            end
            outFmts = unique(outFmts);
        end

        function tf = write(ds, data, writeInfo, outputFmt, varargin)
            if ~any(contains(ds.SupportedOutputFormats, outputFmt))
                for ii = 1 : numel(ds.UnderlyingDatastores)
                    tf = ds.UnderlyingDatastores{ii}.write(data, writeInfo, outputFmt, varargin{:});
                    if tf
                        break;
                    end
                end
            else
                tf = ds.Writer.write(data, writeInfo, outputFmt, varargin{:});
            end
        end

        function tf = currentFileIndexComparator(ds, currFileIndex)
            tf = false;
            for idx = 1:numel(ds.UnderlyingDatastores)
                try
                    tf = currentFileIndexComparator(ds.UnderlyingDatastores{idx}, currFileIndex);
                    return;
                catch
                end
            end
        end
    end

    methods (Static, Hidden)
        function obj = loadobj(s)
            obj = MyCombinedDatastore();
            obj.UnderlyingDatastores = s.UnderlyingDatastores;
            if contains(fieldnames(s),"SupportedOutputFormats")
                obj.SupportedOutputFormats = s.SupportedOutputFormats;
            end
        end
    end
    
    methods (Access = private)
        function verifySubsettable(ds, methodName)
            if ~ds.isSubsettable()
                ds.buildInvalidTraitError(methodName, 'isSubsettable', 'subsettable');
            end
        end

        function buildInvalidTraitError(ds, invalidMethodName, traitMethodName, traitDescription)
            traitTable = ds.buildTraitTable();

            % Render the table display into a string.
            fh = feature('hotlinks');
            if fh
                traitsDisp = evalc('disp(traitTable);');
            else
                % For no desktop, use hotlinks off on evalc to get rid of
                % xml attributes for display, like, <strong>Var1</strong>, etc.
                traitsDisp = evalc('feature hotlinks off; disp(traitTable);');
                feature('hotlinks', fh);
            end

            msgid = "Mycombineddatastore:invalidTraitValue";
            msg = message(msgid, invalidMethodName, traitDescription, traitsDisp, traitMethodName);
            throwAsCaller(MException(msg));
        end

        function t = buildTraitTable(ds)
            % Assemble the metadata for the required table.
            traits = ["isPartitionable", "isShuffleable", "isSubsettable"];
            variableNames = ["Index", "Underlying datastore class", traits];
            variableTypes = ["double", "string", "string", "string", "string"];
            
            % Pre-allocate the table
            t = table('Size', [numel(ds.UnderlyingDatastores), numel(variableNames)], ...
                      'VariableTypes', variableTypes, ...
                      'VariableNames', variableNames);

            % Populate each row of the table.
            for index = 1:numel(ds.UnderlyingDatastores)
                underlyingDatastore = ds.UnderlyingDatastores{index};
                t{index, 1} = index;
                t{index, 2} = string(class(underlyingDatastore));
                t{index, 3} = underlyingDatastore.isPartitionable();
                t{index, 4} = underlyingDatastore.isShuffleable();
                t{index, 5} = underlyingDatastore.isSubsettable();
            end
        end
    end
end

function datastoresOut = validateAndFlattenDatastoreList(datastoresIn)

    datastoresOut = {};

    outputIdx = 1;

    for ii = 1:numel(datastoresIn)
        if ~(isa(datastoresIn{ii},'matlab.io.Datastore') || isa(datastoresIn{ii},'matlab.io.datastore.Datastore'))
            error(message('Mycombineddatastore:nonDatastoreInputs'));
        end

        if isa(datastoresIn{ii},'MyCombinedDatastore')
            numJoined = numel(datastoresIn{ii}.UnderlyingDatastores);
            datastoresOut(outputIdx :(outputIdx+numJoined-1)) = datastoresIn{ii}.UnderlyingDatastores;
            outputIdx = outputIdx + numJoined;
        else
            datastoresOut(end+1) = datastoresIn(ii); %#ok<AGROW>
            outputIdx = outputIdx + 1;
        end
    end
end

function dataOut = iMakeUniform(dataIn, underlyingDatastore)
    % Force the uniform version of read of the underlying datastore.
    % We need to wrap the read in a cell if the underlying datastore is
    % non-uniform (E.G. imageDatastore / fileDatastore) and that datastore's
    % read method is not already combining multiple read units
    % together (E.G. imageDatastore with ReadSize > 1).
    needToMakeUniform = matlab.io.datastore.internal.shim.isReadEncellified(...
        underlyingDatastore);
    if needToMakeUniform
        dataOut = {dataIn};
    else
        dataOut = dataIn;
    end
end
