%Added by Smith to run matching Algorithm
classdef MatchAnnotationsAlgo < handle
    
    properties (Access = public)
        app_marker;
        detected_peaks;
        
        app_marker_sync_id;
        detected_peaks_sync_id;
        
        linear_int_slope;
    end
    
    properties (Access = private,Constant)
        tolerance = 100;
    end
    
    methods (Access = public)
        
        function obj = MatchAnnotationsAlgo(classesMap)
            obj.app_marker = readtable('./data/markers/annotations.txt');
            obj.app_marker.Properties.VariableNames = {'Class','Value'};
            obj.app_marker.Value = round(obj.app_marker.Value/200);
            
            obj.detected_peaks = readtable('./data/cache/matlabpeaks.txt');
            obj.detected_peaks.Properties.VariableNames = {'Class','Value'};
            
            %Filter app_marker to start with first sync point and end at last sync point
            obj.app_marker_sync_id = obj.app_marker(ismember(obj.app_marker.Class,{classesMap.synchronisationStr}),:);
            obj.app_marker_sync_id = table2array(obj.app_marker_sync_id([1 , size(obj.app_marker_sync_id,1)],2));
            obj.app_marker = obj.app_marker(obj.app_marker.Value >= obj.app_marker_sync_id(1) & obj.app_marker.Value <= obj.app_marker_sync_id(2),:);

            %Filter detected_peaks to start with first sync point and end at last sync point
            obj.detected_peaks_sync_id = obj.detected_peaks(ismember(obj.detected_peaks.Class,{classesMap.synchronisationStr}),:);
            obj.detected_peaks_sync_id = table2array(obj.detected_peaks_sync_id([1 , size(obj.detected_peaks_sync_id,1)],2));
            obj.detected_peaks = obj.detected_peaks(obj.detected_peaks.Value >= obj.detected_peaks_sync_id(1) & obj.detected_peaks.Value <= obj.detected_peaks_sync_id(2),:);

            %Slope of linear interpolation
            obj.linear_int_slope = (obj.detected_peaks_sync_id(2) - obj.detected_peaks_sync_id(1)) / (obj.app_marker_sync_id(2) - obj.app_marker_sync_id(1));
            obj.app_marker.Interpolated_Value = obj.linear_int_slope*(obj.app_marker.Value - obj.app_marker_sync_id(1)) + obj.detected_peaks_sync_id(1);

        end
        
        function runMatchAnnotationsAlgo(obj,algoName)
            if isequal(algoName,"StringMatching") 
                obj.runStringMatchingAlgo(algoName);
            elseif isequal(algoName,"GraphPairMatching") 
                obj.runGraphPairMatchingAlgo(algoName);
            else
                disp("NULL")
            end
        end
        
        function runStringMatchingAlgo(obj,algoName)
            
            %Iterate over app_markers datatable and perform a string matching algorithm
            fid = fopen(strcat('./data/markers/',algoName,'_data.txt'),'wt');
            
            jcount = 1;
            for i=1:size(obj.app_marker,1)
                imatched_flag = 0;
                for j=jcount:size(obj.detected_peaks,1)
                    if abs(obj.app_marker.Interpolated_Value(i) - obj.detected_peaks.Value(j)) <= obj.tolerance
                        jcount = j+1;
                        fprintf(fid,'%s, %.0f\n',obj.app_marker.Class{i},obj.detected_peaks.Value(j));
                        imatched_flag = 1;
                        break
                    end
                end
                if imatched_flag == 0 && jcount <= size(obj.detected_peaks,1)
                    fprintf(fid,'%s, %.0f\n',"unmatched",round(obj.app_marker.Interpolated_Value(i)));
                end
            end
            fclose(fid);
            msgbox(strcat('File Generated for algo: ',algoName),'Success');
        end
        
        function runGraphPairMatchingAlgo(obj,algoName)
%           fid = fopen(strcat('./data/markers/',algoName,'_data.txt'),'wt');
%             
%           fclose(fid);
            disp("Still in Working");
        end
            
        
    end
end

