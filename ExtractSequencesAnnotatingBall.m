function ExtractSequencesAnnotatingBall(datasetPath, singleGameEvents, gameIndex, ClipOrEvent, correspondingBBoxes, SamplingOption,cmap)
global Status eventIDs totalGameNum%trainIDs
global processedEvents correctedEventLabels correctedEvent valid_processed

    gameId = singleGameEvents{1,1};
    gameFilePath = [datasetPath filesep 'game' filesep gameId '.mp4'];
    gameObj = VideoReader(gameFilePath);
%     frameRate = gameObj.FrameRate;
    switch ClipOrEvent
        case 'Clip'
            startTimeCol = 4;
            endTimeCol = 5;
            trimStr = 'untrimmed';
        case 'Event'
            startTimeCol = 6;
            endTimeCol = 7;
            trimStr = 'isolated';
        otherwise
            error('No such Video option!!');
    end
    
    switch SamplingOption
        case 'realFPS'
            drawFunc = @AnnotatingBallSequenceInRealFPS;
        case 'samplingFPS'
            %drawFunc = @AnnotatingSequenceInSamplingFPS;
            drawFunc = @AnnotatingSequenceWindowInSamplingFPS;
        otherwise
            error('No such sampling option!!');
    end
processed_record = [datasetPath filesep 'Raw' filesep SamplingOption filesep trimStr filesep 'processed_record_' Status.dataset '.mat'];
if exist(processed_record,'file')
    load(processed_record);
    if isempty(processedEvents{gameIndex})
        processedEvents{gameIndex} = cell(size(singleGameEvents,1),1);
    end
else
    processedEvents = cell(1,totalGameNum);
    if isempty(processedEvents{gameIndex})
        processedEvents{gameIndex} = cell(size(singleGameEvents,1),1);
    end    
end
corrected_record = [datasetPath filesep 'Raw' filesep SamplingOption filesep trimStr filesep 'correctedEvent_record_' Status.dataset '.mat'];
if exist(corrected_record,'file')
    load(corrected_record);
    if isempty(correctedEventLabels{gameIndex})
        correctedEventLabels{gameIndex} = cell(size(singleGameEvents,1),1);
    end
else
    correctedEventLabels = cell(1,totalGameNum);
    if isempty(correctedEventLabels{gameIndex})
        correctedEventLabels{gameIndex} = cell(size(singleGameEvents,1),1);
    end    
end
    for o=1:size(singleGameEvents,1)
%         if ~isempty(processedEvents{gameIndex}{o})
%             continue
%         end
        Status = CalculateAllLabel(processedEvents,Status,eventIDs);
        Status.eventNum = Status.events(o);
        endTimeInSecond = singleGameEvents{o,endTimeCol}/1000;
        if strcmp(ClipOrEvent,'Clip')
            startTimeInSecond = singleGameEvents{o,startTimeCol}/1000;
        else
            endTimeInSecond = endTimeInSecond + 1;
            startTimeInSecond = endTimeInSecond - 4;
        end
        eventLabel = singleGameEvents{o,10};
        trainLabel = singleGameEvents{o,11};
        basketballPos(1) = singleGameEvents{o,8};
        basketballPos(2) = singleGameEvents{o,9};
        
        k = find(ismember(eventIDs,eventLabel));
        Status.Event(k) = Status.Event(k)+1;
        Status.currentEvent = k;
        Status.Total = Status.Total+1;
        Status.Vid.(trainLabel) = Status.Vid.(trainLabel)+1;

        eventIdx = sprintf('%02d',Status.events(o));
        gameIdx = sprintf('%03d',gameIndex);
        %outputFileFolder = [datasetPath filesep 'Raw' filesep SamplingOption filesep 'game' gameIdx];
        %outputFileFolder = [datasetPath filesep 'Raw' filesep SamplingOption filesep 'sequence' filesep trimStr filesep trainLabel filesep eventLabel];
        outputFileFolder = [datasetPath filesep 'Raw' filesep SamplingOption filesep trimStr filesep trainLabel filesep eventLabel ...
            filesep 'g' gameIdx '_s' eventIdx filesep 'img'];

        if ~exist(outputFileFolder,'dir')
            mkdir(outputFileFolder);
        end
        %outputFilenamePrefix = [outputFileFolder filesep 'g' gameIdx '_s' eventIdx '_im'];
        outputFilenamePrefix = [outputFileFolder filesep 'im'];

        %DrawBBoxesInRealFPS(outVidFilePath,vidObj,correspondingBBoxes,startTimeInSecond,endTimeInSecond,cmap);
        %feval(drawFunc,outputFilenamePrefix,gameObj,correspondingBBoxes,startTimeInSecond,endTimeInSecond,cmap);
        feval(drawFunc,outputFilenamePrefix,gameObj,correspondingBBoxes,startTimeInSecond,endTimeInSecond,basketballPos);
        

        if valid_processed
            if isempty(processedEvents{gameIndex}{o})
                processedEvents{gameIndex}{o} = {[trainLabel ',' eventLabel ',' int2str(Status.eventNum)]};
                if ~isempty(correctedEvent)
                    correctedEventLabels{gameIndex}{o} = correctedEvent;
                    save(corrected_record,'correctedEventLabels');
                end
                save(processed_record,'processedEvents');                
            end
        end
        if Status.stopSignal
            return
        end
    end  
end


function Status = CalculateAllLabel(processedEvents,Status,eventIDs)
    trainIDs = fieldnames(Status.Vid);
    for t = 1:length(trainIDs)
        Status.Vid.(trainIDs{t}) = 0;
    end
    for e = 1:length(eventIDs)   
        Status.Event(e) = 0;
    end
    Status.Total = 0;

    for gameID = 1:length(processedEvents)
        for eventID = 1:length(processedEvents{gameID})
            if isempty(processedEvents{gameID}{eventID})
                continue
            end
            label = strsplit(cell2mat(processedEvents{gameID}{eventID}),',');
            trainLabel = label{1}; 
            eventLabel = label{2};
            Status.Vid.(trainLabel) = Status.Vid.(trainLabel)+1;
            k = find(ismember(eventIDs,eventLabel));
            Status.Event(k) = Status.Event(k)+1;
            Status.Total = Status.Total+1;
        end
    end

end
