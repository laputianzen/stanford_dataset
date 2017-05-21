function AnnotatingSequenceWindowInSamplingFPS(outVidFilePath,vidObj,correspondingBBoxes,startTimeInSecond,endTimeInSecond,basketballPos)

global Status eventIDs correctedEvent valid_processed%{3pt,fr-throw,layup,2pt,sl.dunk,steal/ fail,succ.}
bboxTimeStamps = cell2mat(correspondingBBoxes(:,2))/1e6; % original is microsecond (10^-6)

oneVideoTimeStampsIdx = intersect(find(bboxTimeStamps>=startTimeInSecond),find(bboxTimeStamps<=endTimeInSecond));
oneVideoBboxTimeStamps = unique(bboxTimeStamps(oneVideoTimeStampsIdx));

counter = 1;
% oneVideoBbox time stamp might smaller than actual time interval frame
% number
% case 1: frame from pre-label player bbox time stamp frame number
   frameNum = size(oneVideoBboxTimeStamps,1);
% case 2: get frame number from times between event interval and frame
   %frame_interval = oneVideoBboxTimeStamps(2)-oneVideoBboxTimeStamps(1);
   %frameNum = round((endTimeInSecond - startTimeInSecond)/frame_interval);
%position = zeros(size(oneVideoBboxTimeStamps,1),4);
% ball_position = zeros(size(oneVideoBboxTimeStamps,1),4);
% basket_position = zeros(size(oneVideoBboxTimeStamps,1),4);
% backboard_position = zeros(size(oneVideoBboxTimeStamps,1),4);

ball_position = zeros(frameNum,4);
basket_position = zeros(frameNum,4);
backboard_position = zeros(frameNum,4);

ballTrackingTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'ball_ground_truth.txt'];
valid_processed = 0;
ball_record = LoadGroundTruthTxtData(ballTrackingTxt);
if ~isempty(ball_record) && ~isequal(ball_position,ball_record)
    valid_processed = 1;
    disp(['g' int2str(Status.gameNum) '_s' int2str(Status.eventNum) ' annotations existed!!']) 
    return
end

basketTrackingTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'basket_ground_truth.txt'];
backboardTrackingTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'backboard_ground_truth.txt'];
startTimeTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'locateTime.txt'];
timeTableTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'timeTable.txt'];

flagLocate = 0;
gui_release = 0;
correctedEvent = [];
framePerInterval = round((oneVideoBboxTimeStamps(2)-oneVideoBboxTimeStamps(1))*vidObj.FrameRate);
% create gui
    % Create a figure and axes
    f = figure('Visible','on','Units','Normalized');
    set(f,'MenuBar','none','ToolBar','none');
    set(f,'Position',[0,0,1,1]);
    set(f,'Name','press key {"delete","escape","backspace"} to escape wrong annotation');
    ax = axes('Position',[0 0 0.8 1],'Units','Normalized');
    % Create push button
    btn_Ball = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'basketball',...
        'Position', [0.825 0.525 0.15 0.075],...
        'Callback', {@DrawBBox,'magenta'});          
    % Create push button
    btn_Basket = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'basket',...
        'Position', [0.825 0.4 0.15 0.075],...
        'Callback', {@DrawBBox,'cyan'});
    % Create push button
    btn_BackBoard = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'backboard',...
        'Position', [0.825 0.275 0.15 0.075],...
        'Callback', {@DrawBBox,'yellow'});
    % Create push button
    btn_Finish = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'next frame',...
        'Position', [0.9 0.150 0.075 0.075],...
        'Callback', {@jumpToNewFrame,{btn_Ball,btn_Basket,btn_BackBoard}});
    % Create push button
%     btn_Skip = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'skip this event',...
%         'Position', [0.825 0.110 0.075 0.0325],...
%         'Callback', @jumpToNewVideo);
    btn_Skip = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'skip this event',...
        'Position', [0.9 0.0675 0.075 0.0325],...
        'Callback', @jumpToNewVideo);
    btn_Rewind = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'rewind',...
        'Position', [0.9 0.110 0.075 0.0325],...
        'Callback', @Rewind);   
    % Create push button
%     btn_LocStartBallTime = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'Locate Time',...
%         'Position', [0.9 0.025 0.075 0.075],...
%         'Callback', @LocateBallPosTime);
% %     btn_Prev = uicontrol('Style','pushbutton','Units','Normalized','String','a',...
% %         'Position',[0.9 0.0625 0.022 0.0375],...
% %         'Callback',@hPrevDigitButtonCallback);
% %     btn_Now = uicontrol('Style','pushbutton','Units','Normalized','String','b',...
% %         'Position',[0.9265 0.0625 0.022 0.0375],...
% %         'Callback',@hPrevDigitButtonCallback); 
% %     btn_Next = uicontrol('Style','pushbutton','Units','Normalized','String','c',...
% %         'Position',[0.953 0.0625 0.022 0.0375],...
% %         'Callback',@hPrevDigitButtonCallback); 
    btn_Prev = uicontrol('Style','pushbutton','Units','Normalized','String','<',...
        'Position',[0.825 0.110 0.02 0.0325],...
        'Callback',@hPrevFrameButtonCallback);
    btn_Now = uicontrol('Style','pushbutton','Units','Normalized','String','0',...
        'Position',[0.8475 0.110 0.02 0.0325],...
        'Callback',@hNowFrameButtonCallback); 
    btn_Next = uicontrol('Style','pushbutton','Units','Normalized','String','>',...
        'Position',[0.87 0.110 0.02 0.0325],...
        'Callback',@hNextFrameButtonCallback);     
    
    
    
    btn_Terminate = uicontrol('Style', 'pushbutton', 'Units', 'Normalized', 'String', 'exit',...
        'Position', [0.945 0.235 0.030 0.0325],'ForegroundColor','red',...
        'Callback', @Terminate);      
    
    % Create pop-up menu
    popup_correctEvent = uicontrol('Style', 'popup',...
           'String', eventIDs,'Value', Status.currentEvent,...
           'Units', 'Normalized','Position', [0.825 0.230 0.120 0.0325],...
           'Callback', @setmap);
     
       
    cbox_StartBallPos = uicontrol('style','checkbox','Units','Normalized',...
                'position',[0.825,0.1825,0.075,0.0325],'string','start_Ball_Pos','Value',1,'Callback',@ShowStartBllPos);    
    cbox_SaveLabelImage = uicontrol('style','checkbox','Units','Normalized',...
                'position',[0.825,0.150,0.075,0.0325],'string','save_Label_Im','Value',1); 
            
    txt_game = uicontrol('Style','text','Units','Normalized',...
        'Position',[0.825 0.075 0.025 0.025],...
        'String','game:','HorizontalAlignment','right','FontWeight','bold');         
    edit_game = uicontrol('Style','edit','Units','Normalized',...
        'Position',[0.86 0.075 0.03 0.025],...
        'String',int2str(Status.gameNum));
    txt_event = uicontrol('Style','text','Units','Normalized',...
        'Position',[0.825 0.05 0.025 0.025],...
        'String','event:','HorizontalAlignment','right','FontWeight','bold');         
    edit_event = uicontrol('Style','edit','Units','Normalized',...
        'Position',[0.86 0.05 0.03 0.025],...
        'String',int2str(Status.eventNum));  
    txt_frame = uicontrol('Style','text','Units','Normalized',...
        'Position',[0.825 0.025 0.025 0.025],...
        'String','frame:','HorizontalAlignment','right','FontWeight','bold');         
    edit_frame = uicontrol('Style','edit','Units','Normalized',...
        'Position',[0.86 0.025 0.03 0.025],...
        'String','1');     
    
    

    pnl = uipanel(f,'Title','Video Number','FontSize',12,...
                'Position',[0.810 0.620 0.19 0.36]);            

    txt_steal = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.02 0.21 0.10],...
        'String','steal:','HorizontalAlignment','right','FontWeight','bold');  
    edit_steal = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.05 0.2 0.08],...
        'String',int2str(Status.Event(11))); 
    txt_total = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.02 0.21 0.10],...
        'String','total:','HorizontalAlignment','right','FontWeight','bold');         
    edit_total = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.05 0.2 0.08],...
        'String',int2str(Status.Total));         

    txt_dunkSucc = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.16 0.21 0.10],...
        'String','sl. dunk succ.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_dunkSucc = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.19 0.2 0.08],...
        'String',int2str(Status.Event(10)));
    txt_dunkFail = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.16 0.21 0.10],...
        'String','sl. dunk fail:','HorizontalAlignment','right','FontWeight','bold');         
    edit_dunkFail = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.19 0.2 0.08],...
        'String',int2str(Status.Event(9)));       

    txt_2ptSucc = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.30 0.21 0.10],...
        'String','2-pt succ.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_2ptSucc = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.33 0.2 0.08],...
        'String',int2str(Status.Event(8)));
    txt_2ptFail = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.30 0.21 0.10],...
        'String','2-pt fail:','HorizontalAlignment','right','FontWeight','bold');         
    edit_3ptFail = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.33 0.2 0.08],...
        'String',int2str(Status.Event(7)));   

    txt_layupSucc = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.44 0.21 0.10],...
        'String','layup succ.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_layupSucc = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.47 0.2 0.08],...
        'String',int2str(Status.Event(6)));
    txt_layupFail = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.44 0.21 0.10],...
        'String','layup fail:','HorizontalAlignment','right','FontWeight','bold');         
    edit_layupFail = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.47 0.2 0.08],...
        'String',int2str(Status.Event(5)));     
    
    txt_freethrowSucc = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.58 0.21 0.10],...
        'String','free-throw succ.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_freethrowSucc = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.61 0.2 0.08],...
        'String',int2str(Status.Event(4)));
    txt_freethrowFail = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.58 0.21 0.10],...
        'String','free-throw fail:','HorizontalAlignment','right','FontWeight','bold');         
    edit_freethrowFail = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.61 0.2 0.08],...
        'String',int2str(Status.Event(3)));
    
    txt_3ptSucc = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.72 0.21 0.10],...
        'String','3-pt succ.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_3ptSucc = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.27 0.75 0.2 0.08],...
        'String',int2str(Status.Event(2)),'Tag','edit_3ptSucc');
    txt_3ptFail = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.55 0.72 0.21 0.10],...
        'String','3-pt fail:','HorizontalAlignment','right','FontWeight','bold');         
    edit_3ptFail = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.77 0.75 0.2 0.08],...
        'String',int2str(Status.Event(1)));
    
    txt_train = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.05 0.86 0.1 0.10],...
        'String','train:','HorizontalAlignment','right','FontWeight','bold');         
    edit_train = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.15 0.89 0.2 0.08],...
        'String',int2str(Status.Vid.train));
    txt_val = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.35 0.86 0.1 0.10],...
        'String','val.:','HorizontalAlignment','right','FontWeight','bold');         
    edit_val = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.45 0.89 0.2 0.08],...
        'String',int2str(Status.Vid.val));  
    txt_test = uicontrol(pnl,'Style','text','Units','Normalized',...
        'Position',[0.65 0.86 0.1 0.10],...
        'String','test:','HorizontalAlignment','right','FontWeight','bold');         
    edit_test = uicontrol(pnl,'Style','edit','Units','Normalized',...
        'Position',[0.75 0.89 0.2 0.08],...
        'String',int2str(Status.Vid.test));       
    % Make figure visble after adding all components
    f.Visible = 'on';
    
    function DrawBBox(source,event,color)
%         currentColor = source.ForegroundColor;
%         if ~isequal(currentColor,[0 0 0])
%             set(source,'ForegroundColor','black');
%             image(videoFrame, 'Parent', ax);          
%         else
        set(source,'ForegroundColor',color);
        h = imrect(ax);
        % Specify a position constraint to imrect
        fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));
        setPositionConstraintFcn(h,fcn); 
        if ~isempty(h) % we plot a bbox
            setColor(h,color);
            temp_pos = round(wait(h));
            if ~isempty(temp_pos)
                switch color
                    case 'magenta'
                        ball_position(counter,1:4) = temp_pos;%round(wait(h));
                        if ~isequal(basketballPos,[-1 -1]) && ~flagLocate
                        realBasketballPos = round([basketballPos(1)*size(videoFrame,2),...
                            basketballPos(2)*size(videoFrame,1)]);
                        if JudgeXYinBBox(realBasketballPos,ball_position(counter,1:4))
                            choice = questdlg('Is this proper shooting time?', ...
                                'Locate Time Menu', ...
                                'Yes','No','No');
                            if  strcmp(choice,'Yes')
                                fid = fopen(startTimeTxt,'w');
                                %vidObj.CurrentTime == oneVideoBboxTimeStamps(counter)
                                fprintf(fid,'%u: %f  x,y: %u %u\n',counter,oneVideoBboxTimeStamps(counter),...
                                    realBasketballPos(1),realBasketballPos(2));
                                fclose(fid);
                                flagLocate = 1;
                            end                     
                        end
                        end
                    case 'cyan'
                        basket_position(counter,1:4) = temp_pos;%round(wait(h));
                    case 'yellow'
                        backboard_position(counter,1:4) = temp_pos;%round(wait(h));
                    otherwise
                        error('No such object!');
                end

                set(source,'Enable','off','ForegroundColor','black');
            else
                % detect keycase {'delete','escape','backspace'} to escape wrong imrect
                set(source,'ForegroundColor','black');
                delete(h)
            end
        else
           % detect keycase {'delete','escape','backspace'} to escape wrong imrect
           set(source,'ForegroundColor','black');
        end
        resume(h);
        %uiwait(gcbf)
    end

    function setmap(source,event)
        val = source.Value;
        maps = source.String;
        % For R2014a and earlier: 
        % val = get(source,'Value');
        % maps = get(source,'String'); 

        %correctEvent = maps{val};
        if val ~= Status.currentEvent
            source.ForegroundColor = 'red'; %[1 0.6 0.78];
        else
            source.ForegroundColor = 'black';
        end
        correctedEvent = maps{val};
        %newmap = maps{val};
        %colormap(newmap);
    end

    function jumpToNewFrame(source,event,annotateBtns)
        if get(cbox_SaveLabelImage,'Value')
            labelFolder = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) filesep 'label'];
            if ~exist(labelFolder,'dir')
                mkdir(labelFolder);
            end
            %delete previous file
            if counter == 1
                delete([labelFolder filesep '*.png']);
                delete([outVidFilePath '*.png']);
            end
            labelSeqFileName = [labelFolder filesep 'im' sprintf('%04d',counter) '.png'];
            originSeqFileName= [outVidFilePath sprintf('%04d',counter) '.png'];
%             if ~exist(seqFileName,'file')
                
                %counter = counter + 1;
            % case 1
            %vidObj.CurrentTime = oneVideoBboxTimeStamps(counter);
            % case 2
            vidObj.CurrentTime = freezeTime;
            frame = readFrame(vidObj);
            % save origin frame
            imwrite(frame,originSeqFileName,'png');
            hFigTemp = figure('Visible','off');           
            imshow(frame,'border','tight');
            hold on;
            drawBoundBoxOnImage(hFigTemp.CurrentAxes,ball_position(counter,:),'magenta');
            drawBoundBoxOnImage(hFigTemp.CurrentAxes,basket_position(counter,:),'cyan');
            drawBoundBoxOnImage(hFigTemp.CurrentAxes,backboard_position(counter,:),'yellow');
            hold off;
            hFigTemp.Visible = 'on';
            frame = getframe(hFigTemp);
            % save label frame
            imwrite(frame.cdata,labelSeqFileName,'png');
            close(hFigTemp);
%             else
%                 disp([seqFileName ' skip!!']);
%             end
        end
        counter = counter + 1;
        if counter > frameNum
            if ~isempty(correctedEvent)
                % Construct a questdlg with three options
                choice = questdlg('Are you sure to change event?', ...
                    'Change Event Menu', ...
                    'Yes','No','No');
                if strcmp(choice,'No')
                    %uiwait(gcf);
                    return
                end
            end
            % save time table 
            fileID = fopen(timeTableTxt,'w');           
            fprintf(fileID,'%u: %f\n',[(1:frameNum);oneVideoBboxTimeStamps']);
            fclose(fileID);  
            
            SavePositionTxt(ballTrackingTxt,ball_position);
            SavePositionTxt(basketTrackingTxt,basket_position);
            SavePositionTxt(backboardTrackingTxt,backboard_position);
            
            
            uiresume(f);
            close(f);
            if ~isequal(ball_position,zeros(size(oneVideoBboxTimeStamps,1),4))
                valid_processed = 1;
            else
                valid_processed = 0;
            end
            return
        end
        set(edit_frame,'String',int2str(counter));
        % case 1
        freezeTime = oneVideoBboxTimeStamps(counter);
        vidObj.CurrentTime = oneVideoBboxTimeStamps(counter);
        % case 2
%         freezeTime = freezeTime + frame_interval;
%         vidObj.CurrentTime = freezeTime;

        tPointer = find(abs(timeStamp-freezeTime) < 0.1/vidObj.FrameRate);
        videoFrame = readFrame(vidObj);
        figure(f);
        image(videoFrame, 'Parent', ax);
        for i = 1:length(annotateBtns)
            set(annotateBtns{i},'Enable','on');
        end

        DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
%         if get(cbox_StartBallPos,'Value')
%             hold on;
%             x = round(basketballPos(1)*size(videoFrame,2));
%             y = round(basketballPos(2)*size(videoFrame,1));
%             plot(ax,x,y,'md');
%             hold off;
%         end

        set(btn_Now,'String',int2str(0),'ForegroundColor','black');
        if counter == frameNum
            source.String = 'finish';
            source.ForegroundColor = 'blue';
        end
        uiresume(gcbf);
%         uiresume(btn_Ball);
%         uiresume(btn_Basket);
%         uiresume(btn_BackBoard);
        %uiwait(gcf)
    end

    function Terminate(source,event,color)
        % Construct a questdlg with three options
        choice = questdlg('Would you like to stop annotation?', ...
            'Exit Menu', ...
            'Yes','No','No');
        % Handle response
        switch choice
            case 'Yes'
                Status.stopSignal = true;
                uiresume(f);
                gui_release = 1;
                close(f);
            case 'No'
                disp('(Cancel exit)');
        end
    end
    function jumpToNewVideo(source,event)
%         uiresume(f);
%         close(f);
%         return
        %valid_processed = 1;
        gui_release = 1;
        uiresume(gcbf);
        close(gcbf);
    end

    function LocateBallPosTime(source,event)
        LocTimeTxt = [outVidFilePath(1:(strfind(outVidFilePath,'img')-1)) 'ballLocTime.txt'];
        fid = fopen(LocTimeTxt,'w');
        time = vidObj.CurrentTime;
        fprintf(fid,'%f %u %u',time,x,y);
        fclose(fid);
        set(source,'Enable','off');
    end

    function ShowStartBllPos(source,event)
        figure(f);
        image(videoFrame, 'Parent', ax);
        DrawStartBallPos(ax,source,basketballPos,videoFrame); 
%         if source.Value % show ball position
%             hold on;
%             x = round(basketballPos(1)*size(videoFrame,2));
%             y = round(basketballPos(2)*size(videoFrame,1));
%             plot(ax,x,y,'md');
%             hold off;
%         end                        
    end

    function hPrevFrameButtonCallback(source,event)
        if tPointer ~= 1 
            set(btn_Ball,'Enable','off');
            set(btn_Basket,'Enable','off');
            set(btn_BackBoard,'Enable','off');

            tPointer = tPointer - 1;
            videoFrame = mov(tPointer).cdata;
            image(videoFrame, 'Parent', ax);
            DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
                     
            
            offset = str2num(get(btn_Now,'String'));
            offset = offset - 1;
            
            cPointer = DrawBBoxOrNot(counter,offset,framePerInterval);
            if ~isempty(cPointer)
                drawBoundBoxOnImage(ax,ball_position(cPointer,:),'magenta');
                drawBoundBoxOnImage(ax,basket_position(cPointer,:),'cyan');
                drawBoundBoxOnImage(ax,backboard_position(cPointer,:),'yellow');
            end              
            
            if offset < 0
                offsetString = int2str(offset); 
                set(btn_Now,'ForegroundColor','blue');
            elseif offset > 0
                offsetString = ['+' int2str(offset)]; 
                set(btn_Now,'ForegroundColor','green');
            else
                offsetString = int2str(offset); 
                set(btn_Now,'ForegroundColor','black');
                if isequal(ball_position(cPointer,:),[0 0 0 0])
                    set(btn_Ball,'Enable','on');
                    set(btn_Basket,'Enable','on');
                    set(btn_BackBoard,'Enable','on');
                end
            end
            set(btn_Now,'String',offsetString);
        end
    end

    function hNowFrameButtonCallback(source,event)
        set(btn_Ball,'Enable','on');
        set(btn_Basket,'Enable','on');
        set(btn_BackBoard,'Enable','on');
        
        tPointer = find(abs(timeStamp-freezeTime) < 0.1/vidObj.FrameRate);
        %tPointer = find(ismember(timeStamp,freezeTime));
        videoFrame = mov(tPointer).cdata;
        image(videoFrame, 'Parent', ax);
        DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
        
        cPointer = DrawBBoxOrNot(counter,0,framePerInterval);
        if ~isempty(cPointer)
            drawBoundBoxOnImage(ax,ball_position(cPointer,:),'magenta');
            drawBoundBoxOnImage(ax,basket_position(cPointer,:),'cyan');
            drawBoundBoxOnImage(ax,backboard_position(cPointer,:),'yellow');
            set(btn_Ball,'Enable','off');
            set(btn_Basket,'Enable','off');
            set(btn_BackBoard,'Enable','off');
        end        
        
        set(btn_Now,'String','0','ForegroundColor','black');
    end

    function hNextFrameButtonCallback(source,event)
        if tPointer ~= length(timeStamp)
            set(btn_Ball,'Enable','off');
            set(btn_Basket,'Enable','off');
            set(btn_BackBoard,'Enable','off');

            tPointer = tPointer + 1;
            videoFrame = mov(tPointer).cdata;
            image(videoFrame, 'Parent', ax);
            DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
            
            offset = str2num(get(btn_Now,'String'));
            offset = offset + 1;

            cPointer = DrawBBoxOrNot(counter,offset,framePerInterval);
            if ~isempty(cPointer)
                drawBoundBoxOnImage(ax,ball_position(cPointer,:),'magenta');
                drawBoundBoxOnImage(ax,basket_position(cPointer,:),'cyan');
                drawBoundBoxOnImage(ax,backboard_position(cPointer,:),'yellow');
            end            
            
            if offset < 0 
                offsetString = int2str(offset); 
                set(btn_Now,'ForegroundColor','blue');
            elseif offset > 0
                offsetString = ['+' int2str(offset)]; 
                set(btn_Now,'ForegroundColor','green');
            else
                offsetString = int2str(offset);
                set(btn_Now,'ForegroundColor','black');
                if isequal(ball_position(cPointer,:),[0 0 0 0])
                    set(btn_Ball,'Enable','on');
                    set(btn_Basket,'Enable','on');
                    set(btn_BackBoard,'Enable','on');
                end
            end
            set(btn_Now,'String',offsetString);
            
        end
    end
    
    function Rewind(source,event)
        if strcmp(source.String,'rewind')
            set(source,'String','pause');
            % case 1
            QuickBrowseClip(ax,vidObj,oneVideoBboxTimeStamps(1),oneVideoBboxTimeStamps(end),'slow',...
                cbox_StartBallPos,basketballPos);
            % case 2
%             QuickBrowseClip(ax,vidObj,startTimeInSecond,endTimeInSecond,'slow');
            set(source,'String','rewind');
        elseif strcmp(source.String,'pause')
            pause
            set(source,'String','rewind');
        end
           
        image(videoFrame, 'Parent', ax);
        DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
%         if get(cbox_StartBallPos,'Value')
%             hold on;
%             x = round(basketballPos(1)*size(videoFrame,2));
%             y = round(basketballPos(2)*size(videoFrame,1));
%             plot(ax,x,y,'md');
%             hold off;
%         end 
    end

% init
if isequal(basketballPos,[-1 -1])
    % no start ball position
    set(cbox_StartBallPos,'Enable','off');
    set(btn_LocStartBallTime,'Enable','off');
end

    % case 1
    QuickBrowseClip(ax,vidObj,oneVideoBboxTimeStamps(1),oneVideoBboxTimeStamps(end),'normal',...
        cbox_StartBallPos,basketballPos);   
    vidObj.CurrentTime = oneVideoBboxTimeStamps(1);
    % case 2
%     QuickBrowseClip(ax,vidObj,startTimeInSecond,endTimeInSecond,'normal');   
%     vidObj.CurrentTime = startTimeInSecond;
    
    freezeTime = vidObj.CurrentTime;
    videoFrame = readFrame(vidObj);
    image(videoFrame, 'Parent', ax);
    DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
%     if get(cbox_StartBallPos,'Value')
%         hold on;
%         x = round(basketballPos(1)*size(videoFrame,2));
%         y = round(basketballPos(2)*size(videoFrame,1));
%         plot(ax,x,y,'md');
%         hold off;
%     end
    [mov,timeStamp] = ReadVideoFrames(vidObj,oneVideoBboxTimeStamps(1),oneVideoBboxTimeStamps(end));
    %tPointer = find(ismember(timeStamp,freezeTime));
    tPointer = find(abs(timeStamp-freezeTime) < 0.1/vidObj.FrameRate);
    
    while ~valid_processed && ~gui_release
        uiwait(f);
    end

end

function SavePositionTxt(TrackingTxt,position)
    fileID = fopen(TrackingTxt,'w');
    % since fprint save column-wise, we first need transpose position
    % matrix
    fprintf(fileID,'%4u %4u %4u %4u\n',position');
    fclose(fileID);
end

function drawBoundBoxOnImage(ax,position,color)
    if ~isequal(position,[0 0 0 0])
        %figure(fig)
        axes(ax)
        rectangle('Position', position,'EdgeColor',color,'LineWidth',2);
        %h = imrect(gca,position);
        %setColor(h,color);
    end   
end

function C = LoadGroundTruthTxtData(filename)
    if exist(filename,'file')
        C = importdata(filename,' ');
    else
        C = [];
    end
end

function DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame)
    if get(cbox_StartBallPos,'Value') && ~isequal(basketballPos,[-1 -1])
        hold on;
        x = basketballPos(1)*size(videoFrame,2);
        y = basketballPos(2)*size(videoFrame,1);        
%         x = round(basketballPos(1)*size(videoFrame,2));
%         y = round(basketballPos(2)*size(videoFrame,1));
        plot(ax,x,y,'md');
        hold off;
    end      
end

function QuickBrowseClip(ax,vidObj,startTimeInSecond,endTimeInSecond,playSpeed,cbox_StartBallPos,basketballPos)
    % quick browse clip/event
    pause(0.2)
    vidObj.CurrentTime = startTimeInSecond;
    switch playSpeed
        case 'normal'
            ratio = 1;
        case 'slow'
            ratio = 3;
        case 'very slow'
            ratio = 6;
    end
    FrameRate = vidObj.FrameRate/ratio;
    while hasFrame(vidObj) && vidObj.CurrentTime <= endTimeInSecond
        %videoFrame(counter).cdata = readFrame(vidObj);
        videoFrame = readFrame(vidObj);
        image(videoFrame, 'Parent', ax);
        ax.Visible = 'off';
        DrawStartBallPos(ax,cbox_StartBallPos,basketballPos,videoFrame);
        %pause(1/vidObj.FrameRate);
        pause(1/FrameRate);
        %counter = counter + 1;
    end
end

function val = JudgeXYinBBox(basketballPos,ballBboxPos)
geLeftEdge = (basketballPos(1) >= (ballBboxPos(1)-ballBboxPos(3)/2));
leRightEdge= (basketballPos(1) <= (ballBboxPos(1)+ ballBboxPos(3)*3/2));
geTopEdge = (basketballPos(2) >= ballBboxPos(2) - ballBboxPos(4)/2);
leBottomEdge= (basketballPos(2) <= (ballBboxPos(2)+ ballBboxPos(4)*3/2));

val = geLeftEdge && leRightEdge && geTopEdge && leBottomEdge;

end

function [mov,time] = ReadVideoFrames(vidObj,startTimeInSecond,endTimeInSecond)
k = 1;
vidObj.CurrentTime = startTimeInSecond;
while hasFrame(vidObj) && vidObj.CurrentTime <= endTimeInSecond
    %time(k) = vidObj.CurrentTime; % read first frame will not change
    %current time 
    mov(k).cdata = readFrame(vidObj);
    time(k) = vidObj.CurrentTime;
    k = k+1;
end

end

function cPointer = DrawBBoxOrNot(counter,tPointer,framePerInterval)
    cPointer = [];
    if mod(tPointer,framePerInterval) == 0
        relativeCount = tPointer/framePerInterval;
        cPointer = counter + relativeCount;
    end        
end

