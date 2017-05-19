clear all
close all

eventTable = readtable('bball_dataset_april_4.csv','Delimiter',',','ReadVariableNames',false);
% eventFieldName = {'YoutubeId','VideoWidth','VideoHeight','ClipStartTime','ClipEndTime','EventStartTime','EventEndTime',...
%    'EventStartBallX','EventStartBallY','EventLabel','TrainValOrTest'};
% 
% for f = 1:size(eventTable,2)
%     eventTable.Properties.VariableNames{f} = eventFieldName{f};
% end

bboxTable = readtable('train_test_val_merged_detections_v2_ts_fixed 2.csv','Delimiter',',','ReadVariableNames',false);

events = table2cell(eventTable);
bboxes = table2cell(bboxTable);

eventIDs = table2cell(unique(eventTable(:,10)));
trainIDs = table2cell(unique(eventTable(:,11)));

%gameIds = unique(events(:,1));
gameIds = cell(1);
id = 1;
for i=1:size(events,1)
    startTimeInSecond = events{i,6}/1000;
    endTimeInSecond = events{i,7}/1000;
    if isempty(gameIds{1}) || ~ismember(events(i,1),gameIds) 
        if endTimeInSecond-startTimeInSecond > 6
            continue
        end
        gameIds{id,1} = events{i,1};
        id = id + 1;
    end
end

datasetPath = 'dataset';
max_Num = 0;
for g = 1:length(gameIds)
    display(['Extract videos of game ' int2str(g) ' ...' ]);
    eventsIdx = find(ismember(events(:,1),gameIds{g}));
    singleGameEvents = events(eventsIdx,:);
%     bboxesIdx = find(ismember(bboxes(:,1),gameIds{g}));
%     correspondingBBoxes = bboxes(bboxesIdx,:);
    TempgameEventLog{g} = singleGameEvents(:,10);
    TemptrainLog{g} = singleGameEvents(:,11);
    if max_Num < size(singleGameEvents,1)
        max_Num = size(singleGameEvents,1);
    end
end

gameEventLog = cell(max_Num,length(gameIds));
trainEventLog     = cell(max_Num,length(gameIds));
trainVidLog  = cell(1,length(gameIds));
%trainVidLog = [];
for g = 1:length(gameIds)
    eventsIdx = find(ismember(events(:,1),gameIds{g}));
    singleGameEvents = events(eventsIdx,:);
    for e = 1:length(eventsIdx)
        gameEventLog{e,g} = cell2mat(singleGameEvents(e,10));
        trainEventLog(e,g) = singleGameEvents(e,11);
    end
    trainVidLog{g} = cell2mat(unique(trainEventLog(1:length(eventsIdx),g)));
    eventVidLog{g} = unique(gameEventLog(1:length(eventsIdx),g));
    fuseEventVidLog{g} = setdiff(unique(strtok(eventVidLog{g})),'steal');
    stealEventVidLog{g} = intersect(unique(strtok(eventVidLog{g})),'steal');
    templackEventVidLog = setdiff(eventIDs,eventVidLog{g});
    for t = 1:length(templackEventVidLog)
        lackEventVidLog{t,g} = templackEventVidLog{t};
    end
end

sufficientEventGame = find(cellfun(@length,fuseEventVidLog) == 5);
chooseGame = sufficientEventGame(1:22); %train:18, val:2, test:2
trainLogChooseGame = trainVidLog(chooseGame);
stealGameIdx = 2:12
stealChooseGame = sufficientEventGame(stealGameIdx);

eventQ = fuseEventVidLog{chooseGame(1)};

seed = 100;
rng(seed);
for c = 1:length(chooseGame)
    game = chooseGame(c);
    nonEmptyIdx = find(~cellfun(@isempty,gameEventLog(:,game)));
    for q = 1:length(eventQ)        
        list = find(ismember(strtok(gameEventLog(nonEmptyIdx,game)),eventQ{q}));
        k = randi(length(list),1,1);
        chooseEvents(q,c,1) = game;
        chooseEvents(q,c,2) = list(k);       
    end
end

% add steal event
seed = 102;
rng(seed);
for c = 1:length(stealChooseGame)
    game = stealChooseGame(c);
    nonEmptyIdx = find(~cellfun(@isempty,gameEventLog(:,game)));
    stealList = find(ismember(gameEventLog(nonEmptyIdx,game),'steal success'));
    k = randi(length(stealList),1,1);
    chooseEvents(6,stealGameIdx(c),1) = game;
    chooseEvents(6,stealGameIdx(c),2) = stealList(k);
end
    
save([datasetPath filesep 'chooseEvents.mat'],'chooseEvents');

trainVidIdx = find(ismember(trainVidLog,'train'));
testVidIdx  = find(ismember(trainVidLog,'test'));
valVidIdx   = find(ismember(trainVidLog,'val'));

testGameEvent = gameEventLog(:,testVidIdx);
valGameEvent = gameEventLog(:,valVidIdx);

trainRatio = round([length(trainVidIdx),length(testVidIdx),length(valVidIdx)]/length(valVidIdx));
trainBase = round(100/(sum(trainRatio)));
trainVidNum = trainRatio * trainBase;

%eventBase = sum(trainVidNum)/length(eventIDs);
eventBase  = 11;
%commonVidPool = (1:length(gameIds))';
for event = 1:length(eventIDs)
queryMap = -ones(size(gameEventLog));
for g = 1:length(gameIds)
    eventsIdx = find(ismember(events(:,1),gameIds{g}));
    singleGameEvents = events(eventsIdx,:);
    for e = 1:length(eventsIdx)
        k = ismember(gameEventLog(1:length(eventsIdx),g),eventIDs{event});
        queryMap(1:length(eventsIdx),g) = k;
    end
end
[rows cols vals] = find(queryMap>0);
testEventCandidates{event} = intersect([testVidIdx,valVidIdx],unique(cols));
%commonVidPool = intersect(commonVidPool,testEventCandidates{event});
end

uniqueGameForEvent = testEventCandidates;
for event = 1:length(eventIDs)
    for res = setdiff(1:length(eventIDs),event)
        uniqueGameForEvent{event} = setdiff(uniqueGameForEvent{event} ,testEventCandidates{res});
    end
end

save([datasetPath filesep 'GameEventTrainLog.mat'],'gameEventLog','trainEventLog','trainVidLog');



