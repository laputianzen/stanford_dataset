clear all
close all

disp('Loading CSV files...');
tic
eventTable = readtable('bball_dataset_april_4.csv','Delimiter',',','ReadVariableNames',false);
% eventFieldName = {'YoutubeId','VideoWidth','VideoHeight','ClipStartTime','ClipEndTime','EventStartTime','EventEndTime',...
%    'EventStartBallX','EventStartBallY','EventLabel','TrainValOrTest'};
% 
% for f = 1:size(eventTable,2)
%     eventTable.Properties.VariableNames{f} = eventFieldName{f};
% end

bboxTable = readtable('train_test_val_merged_detections_v2_ts_fixed 2.csv','Delimiter',',','ReadVariableNames',false);

global eventIDs trainIDs totalGameNum
events = table2cell(eventTable);
bboxes = table2cell(bboxTable);

eventIDs = table2cell(unique(eventTable(:,10)));
trainIDs = table2cell(unique(eventTable(:,11)));
toc

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
% numBatch = 16;
% eachBatchGame = 16;
% specificBatch = 3:5; %begin:end (1~16)
totalGameNum = 257;

% partOfGameIds = [];
% for b = specificBatch
%     if b ~= numBatch
%         partOfGameIds = [partOfGameIds, (b-1)*eachBatchGame+1:b*eachBatchGame];
%     else
%         partOfGameIds = [partOfGameIds, (b-1)*eachBatchGame+1:(b*eachBatchGame+1)];
%     end
% end 
    
%cmap = colormap(hsv(11));
cmap = colormap(colorcube(11));
close(gcf);
bboxVisible = false;
ClipOrEvent = 'Event';    % Event/Clip
datasetPath = 'dataset';
SamplingOption = 'samplingFPS'; %realFPS/samplingFPS
global Status
for t = 1:length(trainIDs)
    Status.Vid.(trainIDs{t}) = 0;
end
for e = 1:length(eventIDs)   
    Status.Event(e) = 0;
end
Status.Total = 0;
Status.dataset = 'small';
Status.stopSignal = false;

disp('');
disp('Executing Main Program...')
load([datasetPath filesep 'chooseEvents.mat']);
for c = 1:size(chooseEvents,2)
    g = chooseEvents(1,c,1);
    e = chooseEvents(:,c,2);
    e = e(find(e)); %eliminate 0 entity
    Status.gameNum = g;
    Status.events = e;
    display(['Extract videos of game ' int2str(g) ' ...' ]);
    eventsIdx = find(ismember(events(:,1),gameIds{g}));
    singleGameEvents = events(eventsIdx,:);
    chooseGameEvents = singleGameEvents(e,:);
    bboxesIdx = find(ismember(bboxes(:,1),gameIds{g}));
    correspondingBBoxes = bboxes(bboxesIdx,:);
    %ExtractSequencesAnnotatingBall(datasetPath, singleGameEvents, g, ClipOrEvent, correspondingBBoxes, SamplingOption,cmap);
    ExtractSequencesAnnotatingBall(datasetPath, chooseGameEvents, g, ClipOrEvent, correspondingBBoxes, SamplingOption,cmap);
    if Status.stopSignal
%         disp(' ');
%         disp('stopping Annotation program...');
        break
    end
end
if Status.stopSignal
    disp('stop Annotation program...')
else
    disp('Annotation Program Done!!!')
end