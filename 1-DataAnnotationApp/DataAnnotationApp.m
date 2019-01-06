classdef DataAnnotationApp < handle
    
    properties (Constant)
        FindPeaksRadius = 50;
        AutoFindPeakRadius = 100;
        SamplingFrequency = 200;
        SegmentHeight = 30;
    end
    
    properties (Access = private)
        
        %class management
        classesMap;
        
        %data loading
        currentFile;
        dataLoader;
        currentMatchingAlgo; %Added by Smith to run matching algo
        
        %data
        data;
        magnitude;
        columnNames;
        
        %signal computers
        preprocessingConfigurator;
                
        %annotations
        annotationSet;
        eventAnnotationsPlotter;
        rangeAnnotationsPlotter;
        matchedSet; %Added by Smith to display matched markers

        %markers
        markers;
        markerHandles;
        markersPlotter;
        matchedMarkersPlotter; %Added by Smith to display matched markers
        
        %run matching algorithm - Added by Smith
        matchAnnotationsAlgo;
        
        %ui   
        state;    
        uiHandles;
        plotAxes;
        rangeSelectionAxis = [];
        rangeSelection = [];
        plotHandles;
        
        %ui state
        isSelectingPeaks = 0;
        showingMarkers = 1;
        showingMatchedMarkers = 1; %Added by Smith to display matched markers
        debuggingMatchedMarkers = 1; %Added by Smith to debug matched markers
    end
    
    methods (Access = public)
        
        function obj =  DataAnnotationApp()
            obj.classesMap = ClassesMap.instance();
            obj.dataLoader = DataLoader();
            obj.markersPlotter = MarkersPlotter();
            obj.matchedMarkersPlotter = MatchedMarkersPlotter(); %Added by Smith to display matched marker
            
            obj.eventAnnotationsPlotter = EventAnnotationsPlotter(obj.classesMap);
            obj.eventAnnotationsPlotter.delegate = obj;
            
            obj.rangeAnnotationsPlotter = RangeAnnotationsPlotter(obj.classesMap);
            obj.rangeAnnotationsPlotter.delegate = obj;
            
            obj.currentFile = 1;
            obj.state = DataAnnotatorState.kAddMode;
                        
            obj.loadUI();
            
            %Added by Smith to run matching algorithm
            obj.matchAnnotationsAlgo = MatchAnnotationsAlgo(obj.classesMap);
            obj.currentMatchingAlgo = 1;
            
        end
             
        function handleAnnotationClicked(obj,source,~)
            tag = str2double(source.Tag);
            if obj.state == DataAnnotatorState.kDeleteMode
                obj.eventAnnotationsPlotter.deleteAnnotationAtSampleIdx(tag);
                obj.rangeAnnotationsPlotter.deleteAnnotationAtSampleIdx(tag);
            elseif obj.state == DataAnnotatorState.kModifyMode
                currentClass = obj.uiHandles.classesList.Value;
                obj.eventAnnotationsPlotter.modifyAnnotationToClass(uint32(tag),currentClass);
                obj.rangeAnnotationsPlotter.modifyAnnotationToClass(uint32(tag),currentClass);
            end
        end
    end
    
    methods (Access = private)

        %% methods
        function loadUI(obj)
            obj.uiHandles = guihandles(DataAnnotationUI);
            
            obj.uiHandles.fileNamesList.Callback = @obj.handleSelectionChanged;
            obj.uiHandles.matchingAlgoList.Callback = @obj.handleMatchingAlgoSelectionChanged; %Added by Smith to run matching algo
            obj.uiHandles.runMatchingAlgoButton.Callback = @obj.handleRunMatchingAlgoClicked; %Added by Smith to run matching algo
            obj.uiHandles.loadDataButton.Callback = @obj.handleLoadDataClicked;
            obj.uiHandles.visualizeButton.Callback = @obj.handleVisualizeClicked;
            obj.uiHandles.showMarkersCheckBox.Callback = @obj.handleShowMarkersToggled;
            obj.uiHandles.showMatchedMarkersCheckBox.Callback = @obj.handleShowMatchedMarkersToggled; %Added by Smith to display matched markers
            obj.uiHandles.debugMatchedMarkers.Callback = @obj.handleDebugMatchedMarkersToggled; %Added by Smith to debug matched markers
            obj.uiHandles.stateButtonGroup.SelectionChangedFcn = @obj.handleStateChanged;
            obj.uiHandles.findButton.Callback = @obj.handleFindPeaksClicked;
            obj.uiHandles.saveButton.Callback = @obj.handleSaveClicked;
            obj.uiHandles.addRangeAnnotationButton.Callback = @obj.handleAddRangeClicked;
            obj.uiHandles.peaksCheckBox.Callback = @obj.handleSelectingPeaksSelected;
            
            obj.resetUI();
            obj.loadPlotAxes();
            obj.setUserClickHandle();
            obj.populateFileNamesList();
            obj.populateMatchingAlgoNamesList(); %Added by Smith to run Matching Algo
            obj.populateClassesList();
            
            obj.preprocessingConfigurator = PreprocessingConfigurator(...
                obj.uiHandles.signalsList,...
                obj.uiHandles.signalComputerList,...
                obj.uiHandles.signalComputerVariablesTable);
            
        end
        
        function resetUI(obj)
            obj.uiHandles.loadDataTextbox.String = "";
            obj.updateSelectingPeaksCheckbox();
        end
        
        function loadAll(obj)
            if obj.classesMap.numClasses > 0
                obj.loadData();
                obj.loadAnnotations();
                obj.loadMarkers();
            end
        end
        
        function populateFileNamesList(obj)
            extensions = {'*.mat','*.txt'};
            files = Helper.listDataFiles(extensions);
            obj.uiHandles.fileNamesList.String = files;
        end
        
        %Added by Smith to run matching Algo
        function populateMatchingAlgoNamesList(obj)
            algo = regexp(fileread('./data/matchingalgo.txt'), '\r\n|\r|\n', 'split');
            obj.uiHandles.matchingAlgoList.String = algo;
        end
        
        function loadPlotAxes(obj)
            obj.plotAxes = axes(obj.uiHandles.figure1);
            obj.plotAxes.Units = 'characters';
            obj.plotAxes.Position  = [35 4 270 57];
            obj.plotAxes.Visible = 'On';
        end
        
        function setUserClickHandle(obj)
            dataCursorMode = datacursormode(obj.uiHandles.figure1);
            dataCursorMode.SnapToDataVertex = 'on';
            dataCursorMode.DisplayStyle = 'window';
            dataCursorMode.Enable = 'on';
            set(dataCursorMode,'UpdateFcn',@obj.handleUserClick);
        end
        
        function loadData(obj)
            fileName = obj.getDataFileName();
            [obj.data, obj.columnNames] = obj.dataLoader.loadData(fileName);
        end
        
        function loadMarkers(obj)
            markersFileName = obj.getMarkersFileName();
            obj.markers = obj.dataLoader.loadMarkers(markersFileName);
            
            if ~isempty(obj.markers)
                x1 = obj.findFirstSynchronisationMarker();
                x2 = obj.findLastSynchronisationMarker();
                y1 = obj.findFirstSynchronisationSample();
                y2 = obj.findLastSynchronisationSample();
                
                a = double(y2-y1) / (x2-x1);
                
                for i = 1 : length(obj.markers)
                    currentMarker = obj.markers(i);
                    currentMarker.sample = a * (currentMarker.sample - x1) + y1;
                    obj.markers(i) = currentMarker;
                end
            end
        end
  
        function plotData(obj)
            if ~isempty(obj.data)
                hold(obj.plotAxes,'on');
                
                selectedSignals = obj.preprocessingConfigurator.getSelectedSignalIdxs();
                nSignals = length(selectedSignals);
                obj.plotHandles = cell(1,nSignals+1);
                
                for i = 1 : nSignals
                    signalIdx = selectedSignals(i);
                    obj.plotHandles{i} = plot(obj.plotAxes,obj.data(:,signalIdx));
                end
                obj.plotHandles{nSignals+1} = plot(obj.plotAxes,obj.magnitude);
            end
        end
        
        function clearAll(obj)
            obj.clearMarkerPlots();
            obj.clearDataPlots();
            obj.eventAnnotationsPlotter.clearAnnotations();
            obj.rangeAnnotationsPlotter.clearAnnotations();
            cla(obj.plotAxes);
        end
        
        function deleteAll(obj)
            obj.deleteAllMarkers();
            obj.deleteAllAnnotations();
            obj.deleteData();
            obj.deleteRangeSelection();
        end
        
        function deleteData(obj)
            obj.clearDataPlots();
            obj.magnitude = [];
            obj.data = [];
        end
        
        function clearDataPlots(obj)
            for i = 1 : length(obj.plotHandles)
                plotHandle =  obj.plotHandles{i};
                delete(plotHandle);
            end
            obj.plotHandles = [];
        end
        
        function plotMarkers(obj)
            if ~isempty(obj.markers)
                obj.markersPlotter.plotMarkers(obj.markers,obj.plotAxes,obj.showingMarkers);
            end
        end
        
        %Added by Smith to display matched markers
        function plotMatchedMarkers(obj)
            
            obj.loadMatchedMarkers();
            obj.compareMatchedMarkers(); %Added by Smith to debug matched Markers
            obj.matchedMarkersPlotter.plotMatchedMarkers(obj.matchedSet,obj.plotAxes,obj.showingMatchedMarkers,obj.debuggingMatchedMarkers);
            
        end
        
        %Added by Smith to debug Matched Markers
        function compareMatchedMarkers(obj)
            
            obj.matchedSet.Debug = strings(height(obj.matchedSet),1);
            for i=1:size(obj.matchedSet,1)
                imatched_class = char(obj.matchedSet{i,1});
                imatched_value = obj.matchedSet{i,2};
                if imatched_class ~= "unmatched"
                    found_flag = 0;
                    for j=1:length(obj.annotationSet.eventAnnotations)
                        if obj.annotationSet.eventAnnotations(j).sample == imatched_value
                            found_flag = 1;
                            if obj.annotationSet.eventAnnotations(j).label == obj.classesMap.idxOfClassWithString(imatched_class)
                                obj.matchedSet{i,3} = "green";
                            else
                                obj.matchedSet{i,3} = "red";
                            end
                            break;
                        end
                    end
                    if ~(found_flag)
                        obj.matchedSet{i,3} = "yellow";
                    end
                else
                      obj.matchedSet{i,3} = "blue";
                end
            end
        end
        
        function selectSampleAtLocation(obj,x)
            if isempty(obj.rangeSelection)
                obj.rangeSelection = DataAnnotatorSampleRange(x);
            else
                obj.rangeSelection.addValue(x);
            end
            
            obj.updateRangeSelection();
        end
        
        function updateRangeSelection(obj)
            if isempty(obj.rangeSelection)
                obj.deleteRangeSelection();
            else
                if obj.rangeSelection.isValidRange()
                    obj.plotRangeSelection();
                else
                    obj.deleteRangeSelection();
                end
            end
        end
        
        function plotRangeSelection(obj)
            selectionRanges = obj.rangeSelection.sample1:obj.rangeSelection.sample2;
            selectionMagnitude = obj.magnitude(selectionRanges,:);
            obj.rangeSelectionAxis = plot(obj.plotAxes,selectionRanges,selectionMagnitude,'Color','red');
        end
        
        function deleteRangeSelection(obj)
            if ~isempty(obj.rangeSelectionAxis)
                delete(obj.rangeSelectionAxis);
                obj.rangeSelectionAxis = [];
                obj.rangeSelection = [];
            end
        end
        
        function addPeakAtLocation(obj,x)
            peakIdx = obj.findPeakIdxNearLocation(x);
            
            if peakIdx > 0
                obj.addSampleAtLocation(peakIdx);
            end
        end
        
        function addSampleAtLocation(obj,x)
            y = obj.magnitude(x);
            currentClass = obj.getSelectedClass();
            obj.eventAnnotationsPlotter.addAnnotation(obj.plotAxes,x,y,currentClass);
        end
        
        function updateLoadDataTextbox(obj,~,~)
            obj.uiHandles.loadDataTextbox.String = sprintf('data size: %d x %d',size(obj.data,1),size(obj.data,2));
        end
 
        function populateClassesList(obj)
            classes = obj.classesMap.classesList;
            classes{end+1} = obj.classesMap.synchronisationStr;
            obj.uiHandles.classesList.String = classes;
        end
        
        function deleteAllMarkers(obj)
            obj.clearMarkerPlots();
            obj.markers = [];
        end
        
        function clearMarkerPlots(obj)
            obj.markersPlotter.deleteMarkers();
        end
        
        function deleteAllAnnotations(obj)
            obj.eventAnnotationsPlotter.clearAnnotations();
            obj.rangeAnnotationsPlotter.clearAnnotations();
            obj.annotationSet = [];
        end
                
        function addCurrentRange(obj)
            if ~isempty(obj.rangeSelection)
                label = obj.getSelectedClass();
                rangeAnnotation = RangeAnnotation(obj.rangeSelection.sample1,...
                    obj.rangeSelection.sample2,label);
                obj.rangeAnnotationsPlotter.plotAnnotation(obj.plotAxes, rangeAnnotation);
            end
        end
        
        function updateFileName(obj)
            obj.currentFile = obj.uiHandles.fileNamesList.Value;
        end
        
        %Added by Smith to run matching Algorithm
        function updateMatchingAlgoName(obj)
            obj.currentMatchingAlgo = obj.uiHandles.matchingAlgoList.Value;
        end
        
        function markersFileName = getMarkersFileName(obj)
            fileName = obj.getCurrentFileNameNoExtension();
            markersFileName = sprintf('%s-markers.edl',fileName);
        end
        
        %Added by Smith to display matched markers
        function markersFileName = getMatchedMarkersFileName(obj)
            fileName = obj.getMatchingAlgoName();
            markersFileName = sprintf('%s_data.txt',fileName);
        end
        
        function annotationsFileName = getAnnotationsFileName(obj)
            fileName = obj.getCurrentFileNameNoExtension();
            annotationsFileName = Helper.addAnnotationsFileExtension(fileName);
        end
        
        function fileName = getDataFileName(obj)
            fileName = obj.uiHandles.fileNamesList.String{obj.currentFile};
        end
        
        %Added by Smith to run Matching Algo
        function algoName = getMatchingAlgoName(obj)
            algoName = obj.uiHandles.matchingAlgoList.String{obj.currentMatchingAlgo};
        end
        
        function fileName = getCurrentFileNameNoExtension(obj)
            dataFileName = obj.getDataFileName();
            fileName = Helper.removeFileExtension(dataFileName);
        end
        
        function saveAnnotations(obj)
            eventAnnotations = obj.eventAnnotationsPlotter.getAnnotations();
            rangeAnnotations = obj.rangeAnnotationsPlotter.getAnnotations();
            annotations = AnnotationSet(eventAnnotations,rangeAnnotations);
            if ~isempty(eventAnnotations)
                fileName = obj.getAnnotationsFileName();
                obj.dataLoader.saveAnnotations(annotations,fileName);
            end
        end
        
        function loadAnnotations(obj)
            fileName = obj.getAnnotationsFileName();
            obj.annotationSet = obj.dataLoader.loadAnnotations(fileName);
        end
        
        %Added by Smith to display matched markers
        function loadMatchedMarkers(obj)
            fileName = obj.getMatchedMarkersFileName();
            fileNamePath = sprintf('%s/%s',Constants.markersPath,fileName);
            obj.matchedSet = readtable(fileNamePath);
            obj.matchedSet.Properties.VariableNames = {'Class','Value'};
        end
        
        function plotAnnotations(obj)
            if ~isempty(obj.annotationSet) && ~isempty(obj.magnitude)
                
                obj.eventAnnotationsPlotter.plotAnnotations(obj.plotAxes,obj.annotationSet.eventAnnotations,obj.magnitude);
                obj.rangeAnnotationsPlotter.plotAnnotations(obj.plotAxes,obj.annotationSet.rangeAnnotations);
            end
        end
                
        function peakIdx = findPeakIdxNearLocation(obj,idx)
            
            [~, peakIdx] = max(obj.magnitude(idx-obj.FindPeaksRadius:idx+obj.FindPeaksRadius));
            peakIdx = int32(peakIdx + idx - obj.FindPeaksRadius - 1);
        end
        
        
        function computeMagnitude(obj)
            signalComputer = obj.preprocessingConfigurator.createSignalComputerWithUIParameters();
            
            if ~isempty(signalComputer)
                obj.magnitude = signalComputer.compute(obj.data);
            end
        end
        
        %% UI
        function class = getSelectedClass(obj)
            class = uint8(obj.uiHandles.classesList.Value);
        end

        function updateSelectingPeaksCheckbox(obj)
            obj.uiHandles.peaksCheckBox.Value = obj.isSelectingPeaks;
        end
        
        function shouldSelectPeaks = getShouldSelectPeaks(obj)
            shouldSelectPeaks = obj.uiHandles.peaksCheckBox.Value;
        end
        
        %% Handles
        function outputTxt = handleUserClick(obj,src,~)
            pos = get(src,'Position');
            x = pos(1);
            y = pos(2);
            xStr = num2str(x,7);
            yStr = num2str(y,7);
            outputTxt = {['X: ',xStr],['Y: ',yStr]};
            
            fprintf('%d\n',x);
            
            if obj.state == DataAnnotatorState.kAddMode
                if obj.isSelectingPeaks
                    obj.addPeakAtLocation(x);
                else
                    obj.addSampleAtLocation(x);
                end
            elseif obj.state == DataAnnotatorState.kSelectSamplesMode
                obj.selectSampleAtLocation(x);
            end
        end
        
        function handleLoadDataClicked(obj,~,~)
            obj.deleteAll();
            obj.loadAll();
            
            obj.preprocessingConfigurator.setColumnNames(obj.columnNames);
            obj.updateLoadDataTextbox();
        end
        
        function handleVisualizeClicked(obj,~,~)
            if ~isempty(obj.data)
                obj.clearAll();
                obj.computeMagnitude();
                obj.plotData();
                obj.plotAnnotations();
                obj.plotMarkers();
                obj.plotMatchedMarkers(); %Added by Smith to display matched Markers
            end
        end
        
        function handleStateChanged(obj,~,~)
            
            cursorModeHandle = datacursormode(obj.uiHandles.figure1);
            cursorModeHandle.Enable = 'on';
            
            if obj.state == DataAnnotatorState.kSelectSamplesMode
                obj.deleteRangeSelection();
            end
            
            switch obj.uiHandles.stateButtonGroup.SelectedObject
                case (obj.uiHandles.addRadio)
                    obj.state = DataAnnotatorState.kAddMode;
                case (obj.uiHandles.modifyRadio)
                    obj.state = DataAnnotatorState.kModifyMode;
                    cursorModeHandle.Enable = 'off';
                case (obj.uiHandles.deleteRadio)
                    obj.state = DataAnnotatorState.kDeleteMode;
                    cursorModeHandle.Enable = 'off';
                case (obj.uiHandles.selectRangeRadio)
                    obj.state = DataAnnotatorState.kSelectSamplesMode;
            end
        end
        
        function handleSelectingPeaksSelected(obj,~,~)
            obj.isSelectingPeaks = obj.getShouldSelectPeaks();
        end
        
        function handleFindPeaksClicked(obj,~,~)
            for i = 1 : length(obj.markers)
                marker = obj.markers(i);
                segmentStart = marker.sample - ceil(obj.AutoFindPeakRadius/2);
                segmentStart = max(1,segmentStart);
                segmentEnd = marker.sample + ceil(obj.AutoFindPeakRadius/2);
                segmentEnd = min(segmentEnd,length(obj.magnitude));
                
                if segmentStart < segmentEnd
                    segment = obj.magnitude(segmentStart:segmentEnd);
                    [~, maxSample] = max(segment);
                    peakIdx = maxSample + segmentStart - 1;
                    peakX = peakIdx;
                    peakY = obj.magnitude(peakIdx);
                    obj.addPeak(peakX,peakY,1);
                end
            end
        end
        
        function handleSaveClicked(obj,~,~)
            obj.saveAnnotations();
        end
        
        function handleShowMarkersToggled(obj,~,~)
            obj.showingMarkers = ~obj.showingMarkers;
            obj.markersPlotter.toggleMarkersVisibility(obj.showingMarkers);
        end
        
        %Added by Smith to display matched markers
        function handleShowMatchedMarkersToggled(obj,~,~)
            obj.showingMatchedMarkers = ~obj.showingMatchedMarkers;
            if (obj.showingMatchedMarkers)
                obj.loadMatchedMarkers();
            end
            obj.matchedMarkersPlotter.toggleMarkersVisibility(obj.showingMatchedMarkers);
        end
        
        %Added by Smith to debug matched markers
        function handleDebugMatchedMarkersToggled(obj,~,~)
            obj.debuggingMatchedMarkers = ~obj.debuggingMatchedMarkers;
        end
        
        function handleSelectionChanged(obj,~,~)
            obj.updateFileName();
        end
        
        %Added by Smith to run Matching Algorithm
        function handleMatchingAlgoSelectionChanged(obj,~,~)
            obj.updateMatchingAlgoName();
        end
        
         %Added by Smith to run Matching Algorithm
        function handleRunMatchingAlgoClicked(obj,~,~)
            obj.matchAnnotationsAlgo.runMatchAnnotationsAlgo(obj.getMatchingAlgoName);
        end
        
        function handleAddRangeClicked(obj,~,~)
            obj.addCurrentRange();
        end
       

        %% Helper methods
        function idx = findIdxOfValue(~,valueArray,startIdx,value)
            idx = uint32(-1);
            for i = startIdx : length(valueArray)
                if value == valueArray(i)
                    idx = i;
                    break;
                end
            end
        end
        
         function firstSynchronisatonSample = findFirstSynchronisationSample(obj)
            firstSynchronisatonSample = -1;
            eventAnnotations = obj.annotationSet.eventAnnotations;
            for i = 1 : length(eventAnnotations)
                manualAnnotation = eventAnnotations(i);
                if manualAnnotation.label == obj.classesMap.synchronisationClass
                    firstSynchronisatonSample = manualAnnotation.sample;
                    break;
                end
            end
        end
        
        function lastSynchronisatonSample = findLastSynchronisationSample(obj)
            lastSynchronisatonSample = -1;
            eventAnnotations = obj.annotationSet.eventAnnotations;
            for i = length(eventAnnotations) : -1 : 1
                manualAnnotation = eventAnnotations(i);
                if manualAnnotation.label == obj.classesMap.synchronisationClass
                    lastSynchronisatonSample = manualAnnotation.sample;
                    break;
                end
            end
        end
        
        function firstSynchronisationMarker = findFirstSynchronisationMarker(obj)
            firstSynchronisationMarker = -1;
            for i = 1 : length(obj.markers)
                currentMarker = obj.markers(i);
                if currentMarker.label == Constants.SynchronisatonMarker
                    firstSynchronisationMarker = currentMarker.sample;
                    break;
                end
            end
        end
        
        function lastSynchronisationMarker = findLastSynchronisationMarker(obj)
            lastSynchronisationMarker = -1;
            for i = length(obj.markers) : -1 : 1
                currentMarker = obj.markers(i);
                if currentMarker.label == Constants.SynchronisatonMarker
                    lastSynchronisationMarker = currentMarker.sample;
                    break;
                end
            end
        end
    end
    
end
