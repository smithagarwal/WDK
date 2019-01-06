classdef MatchedMarkersPlotter < handle
    properties (Access = public)
        markerHandles;
        markerColors = {[1 0 0],[1 1 0],[0 1 0], [0 0 1], [0 1 1], [1 105/255 180/255], [0.5 0 0.5], [0 0 0]};
        markerLineWidths = [1,1,4,1,1,1,1,1];
    end
    
    methods (Access = public)
        
        function plotMatchedMarkers(obj, markers_dt, plotAxes, visible,debug)
            if (visible)
                visible = true;
            end
            
            visibleStr = MatchedMarkersPlotter.getVisibleStr(visible);
            
            nrow = height(markers_dt);
            markers(1,nrow) = VideoMarker();
            
            for i=1:nrow
                markers(i).sample = markers_dt.Value(i);
                markers(i).text = markers_dt.Class{i};
                if (debug)
                    markers(i).label = markers_dt.Debug{i};
                else
                    markers(i).label = "black";
                end
                
            end
            
            nMarkers = length(markers);
            obj.markerHandles = repmat(DataAnnotatorMarkerHandle,1,nMarkers);
            
            markerHeights = ylim(plotAxes);
            
            for i = 1 : length(markers)
                marker = markers(i);
%                 color = obj.markerColors(marker.label);
                color = marker.label;
%                 lineWidth = obj.markerLineWidths(marker.label);
                lineWidth = 1;
                
                markerHandle = DataAnnotatorMarkerHandle();
                
                markerHandle.lineHandle = line(plotAxes,[marker.sample, marker.sample],...
                    [markerHeights(1) markerHeights(2)],...
                    'Color',color,'LineWidth',lineWidth,...
                    'LineStyle','-','Visible',visibleStr);
                
                if ~isempty(marker.text)
                    textHandle = text(plotAxes,double(marker.sample-15),...
                        markerHeights(2) /2 , marker.text,...
                        'Rotation',90, 'Visible',visibleStr);
                    
                    set(textHandle, 'Clipping', 'on');
                    markerHandle.textHandle = textHandle;
                end
                
                obj.markerHandles(i) = markerHandle;
            end
        end
        
        function deleteMarkers(obj)
            
            for i = 1 : length(obj.markerHandles)
                markerHandle = obj.markerHandles(i);
                delete(markerHandle.lineHandle);
                delete(markerHandle.textHandle);
            end
            obj.markerHandles = [];
        end
        
        function toggleMarkersVisibility(obj,visible)
            visibleStr = MatchedMarkersPlotter.getVisibleStr(visible);
            for i = 1 : length(obj.markerHandles)
                markerHandle = obj.markerHandles(i);
                markerHandle.textHandle.Visible = visibleStr;
                markerHandle.lineHandle.Visible = visibleStr;
            end
        end
    end
    
    methods (Access = private, Static)
        function visibleStr = getVisibleStr(visible)
            visibleStr = 'off';
            if visible
                visibleStr = 'on';
            end
        end
    end
end
