classdef file_loader < handle
    properties (Access = private)
        signal_structure
        markers_structure
    end

    methods (Abstract)
        [signal, markers] = get_signal_and_markers()

        bool = should_be_rejected_due_sample_rate()
    end
end