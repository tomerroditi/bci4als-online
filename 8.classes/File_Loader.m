classdef (Abstract) File_Loader < handle
    properties (Abstract) 
        signal_structure
        markers_structure
    end

    methods (Abstract) 
        [signal, markers] = get_signal_and_markers(obj)

        verify_reliable_file(obj, pipeline)
    end
end