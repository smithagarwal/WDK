classdef SegmentsLabeler < handle
    properties (Access = public)
        labelingStrategy;
        manualAnnotations;
    end
    
    methods (Access = public)
        
        function labelSegments(obj,segmentCells)
            if ~isempty(obj.manualAnnotations)
                labeler = EventsLabeler(obj.labelingStrategy);
                for i = 1 : length(segmentCells)
                    segments = segmentCells{i};
                    manualAnnotation = obj.manualAnnotations(i);
                    
                    labels = labeler.label([segments.eventIdx],manualAnnotation.eventAnnotations);
                    
                    for j = 1 : length(segments)
                        segment = segments(j);
                        segment.class = labels(j);
                    end
                end
            end
        end
    end
end