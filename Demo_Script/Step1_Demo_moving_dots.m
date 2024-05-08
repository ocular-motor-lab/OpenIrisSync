clear all;
AssertOpenGL;

% This demo simulates an experiment that you might want to run to measure
% the optokinetic response and incorporate hardware syncing. Horizontally 
% moving dots are presented and a white square is presented at the bottom
% of the screen for one frame at the beginning and end of each trial. This 
% script produces a figure of the seral output of the phototransistor 
% during the trials. There are event flags for OpenIris that are 
% also placed before and after the first and last flip of each trial. This 
% can be used for hardware syncing. No need to calibrate to run the code. 
% Note that the serial output is recorded for a set number of data points
% so it will begin and end recording the serial output before and after the 
% stimulus is presented.

% To run the demo you need to...
% (1) Open OpenIris and set up as usual and determine where you want your 
%     data to go
% (2) Open Arduino IDE and make sure that the serial output is off by 
%     clicking the Serial Monitor button on the top right hand side of the 
%     IDE window. You will know when the serial output is off because there 
%     will not be any live output of the phototransistor appearing in the 
%     window (needed to run the demo script).
% (3) Check/change the hardcoded values below.

% Hard coded values that you will need to define for your set up
% screen width and height
ds.height_m       = 0.2975; 
ds.width_m        = 0.5345;
ds.frame_rate_Hz   = 120;

% Screen distance, needed for calculating pixel/deg
ds.DistToScreen  = 0.4; 

% Arduino serial port
APort = "COM3"; % change this to change the port

% Demo experiment variables
session_name = 'TEST'; % Name of the session file
data.trials = 4; % number of trials


%% Set up Arduino serial port
% Trouble shooting: you may have to close and reopen ArduinoIDE  or MATLAB if it
% is not functioning properly. 

% to get a list of the serial ports if needed
% serialportlist("available") or serialportlist

% specify serial port for matlab and initializing a structure to store data
if ~exist('arduinoObj','var')
    arduinoObj = serialport(APort,9600);
end

configureTerminator(arduinoObj,"CR/LF"); % telling MATLAB when line is terminated

% Flush the serialport object to remove any old data.
flush(arduinoObj);

% make a data structure that includes the serial output data and a counter
% to keep track of how many times the data has been read out. 
arduinoObj.UserData = struct("Data",[],"Count",1);

%% Skip Sync test
Screen('Preference', 'SkipSyncTests', 1); 

screens      = Screen('Screens');
screenNumber = max(screens);
[ds.w, ds.windowRect] = Screen('OpenWindow', screenNumber, 0);

%screen dimensions
screenWidth_px  = ds.windowRect(3);
screenHeight_px = ds.windowRect(4);

%Calculate pixel/deg
ds.height_deg = 2* atand((ds.height_m./2) ./  ds.DistToScreen);
ds.width_deg  = 2* atand((ds.width_m./2) ./  ds.DistToScreen);
pixdeg        = ((screenHeight_px ./ ds.height_deg) + (screenHeight_px./ds.width_deg)) ./ 2;

%Alpha blending for dots
Screen('BlendFunction', ds.w,'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%% Variables for white square presentation

% Calculate dimensions of the stimulus
ppm =( (screenWidth_px ./ ds.width_m) + (screenHeight_px ./ ds.height_m) )./2; %pixels per meter

% Calculate the width of the square in pixels
wsquareWidth_m      = 0.01; 
wsquareDistFromEdge = 0.015;
wsquareFarEdge      = wsquareDistFromEdge + wsquareWidth_m;

% Define the square position at the bottom left of the screen in pixels
wsquareLeft   = round(wsquareDistFromEdge * ppm); % x coordinat of the left edge
wsquareTop    = screenHeight_px - round(wsquareFarEdge * ppm); % y coordinate of the top edge
wsquareRight  = round(wsquareFarEdge * ppm); % x coordinate of right edge
wsquareBottom = screenHeight_px - (wsquareDistFromEdge * ppm); % y coordinate of bottom edge

% Calculate larger black square around the white square.
ksquareWidth_m      = 0.037; 
ksquareDistFromEdge = 0;
ksquareFarEdge      = ksquareDistFromEdge + ksquareWidth_m;

% Define large black square that surrounds the white square.
ksquareLeft   = round(ksquareDistFromEdge * ppm); % x coordinat of the left edge
ksquareTop    = screenHeight_px - round(ksquareFarEdge * ppm); % y coordinate of the top edge
ksquareRight  = round(ksquareFarEdge * ppm); % x coordinate of right edge
ksquareBottom = screenHeight_px - (ksquareDistFromEdge * ppm); % y coordinate of bottom edge


%% Set up eyetracking

v = ArumeHardware.VOG();
v.Connect();

% set the session name (affects the name of the files being recorded)
v.SetSessionName(session_name); 

v.StartRecording(); % begins the recording.

%% Dot specifications

% Dot size
dotSize_deg = 1;
dotSize_px  = round(dotSize_deg .* pixdeg); 

%Dot speed
dot_speed_deg_sec   = 30;
dot_speed_pix_sec   = dot_speed_deg_sec .* pixdeg; 
dot_speed_pix_frame = round(dot_speed_pix_sec ./ ds.frame_rate_Hz); %pixel movement per flip

%dot number
dot_num = 57;

% create a vector of dot positions
jitter_amount = 100;
dot_col       = round(sqrt(dot_num)); %number of columns and rows of dot grid
x_dots        = linspace(0,ds.windowRect(3)-200,dot_col); %dots to the edge of the screen
y_dots        = linspace(0,ds.windowRect(4)-200,dot_col);
[X,Y]         = meshgrid(x_dots,y_dots);

x_dots_jit    = round(X + jitter_amount * randn(size(X)));
y_dots_jit    = round(Y + jitter_amount * randn(size(Y)));
dots          = [reshape(x_dots_jit,1,[]); reshape(y_dots_jit,1,[])];



%% Start arduino serial recording

configureCallback(arduinoObj,"terminator",@readData); % after next terminator read the data in arduinoObj
% @ puts the arduino object into readData

%% Stimulus presentation

stimTime_sec = 3;

for trial = 1:data.trials

    %Duration between trials
    Fix_dur_sec = 1;
    StartTime   = GetSecs;
    TimeNow     = GetSecs;

    % start with a black screen
    while TimeNow <= StartTime + Fix_dur_sec
        % black screen
        Screen('FillRect',ds.w,[0,0,0]) 
        % flip screen
        Screen('DrawingFinished', ds.w);
        [StartFlip_s, OnsetTime,EndFlip_s, Missed, Beampos] = Screen('Flip', ds.w,[],[],[]);
        TimeNow = GetSecs;
    end

    StartTime   = GetSecs;
    TimeNow     = GetSecs;
    f_lastflag  = 0;  %flag that indicates the last frame of the trial will be drawn
    f_counter   = 0; %frame counter

    %stim presentation loop
    while TimeNow <= StartTime + stimTime_sec || f_lastflag == 1

        f_counter = f_counter + 1; %keep track of frame flips
    
        Screen('DrawDots',ds.w,dots,dotSize_px,[],[],1);

        %Draw black square that is behind the white square
        Screen('FillRect', ds.w, [0,0,0], [ksquareLeft, ksquareTop, ksquareRight, ksquareBottom]);

        %if first or last frame the white square will be drawn and the
        % OpenIris event flags will be drawn. 
        if f_counter == 1 || f_lastflag == 1

            %white square calibration
            Screen('FillRect', ds.w, [255,255,255], [wsquareLeft, wsquareTop, wsquareRight, wsquareBottom]);

            Screen('DrawingFinished', ds.w);
         
            v.RecordEvent('BeforeStimON'); %eye tracking event flag
            Screen('Flip', ds.w,[],[],[]);
            v.RecordEvent('AfterStimON'); %eye tracking flag

        else

            Screen('DrawingFinished', ds.w);
            Screen('Flip', ds.w,[],[],[]);

        end

        % Move dots (change the x coordinate)
        dots(1,:) = dots(1,:) + dot_speed_pix_frame;

        % If the dots go off the screen, put them back on the other side
        if find(dots(1,:)>ds.windowRect(3))

            idx         = find(dots(1,:)>ds.windowRect(3)); % positions where dots are off the screen
            dots(1,idx) = 5; % start the position at this many pixels on the other side of thes screen
        end

        % Break out of animation loop if any key on keyboard or any button
        % on mouse is pressed:
        [mx, my, buttons] = GetMouse(screenNumber);
        if any(buttons)
            break;
        end
        if KbCheck
            break;
        end

        TimeNow = GetSecs;
        if ~(TimeNow <= StartTime + stimTime_sec)
            if f_lastflag  == 1
                f_lastflag = 0;
            else
                f_lastflag = 1;
            end
        end

    end

    % Break out of animation loop if any key on keyboard or any button
    % on mouse is pressed:
    [mx, my, buttons] = GetMouse(screenNumber);
    if any(buttons)
        break;
    end
    if KbCheck
        break;
    end

end

v.StopRecording(); %stops eye movement recordings


%% Plot serial output of the photo transistor
framerate_Hz = 60;
UserData_idx = ~isnan(arduinoObj.UserData.Data);
UserData = arduinoObj.UserData.Data(UserData_idx);
x = [0:length(UserData)-1];
x_sec = x * (1/framerate_Hz);
figure,
title('Serial output from phototransistor')
plot(x_sec,UserData); hold on;
xlabel('Number of samples from Arduino');
ylabel('Arbitrary unit of light intensity');

% resets keyboard control and close windows 
ListenChar(1);
sca;


%% Function 
% Collect serial output of phototransistor during the experiment. 

function readData(src, ~)

% Read the ASCII data from the serialport object.
data = readline(src);

% Convert the string data to numeric type and save it in the UserData
% property of the serialport object.
src.UserData.Data(end+1) = str2double(data);

% Update the Count value of the serialport object.
src.UserData.Count = src.UserData.Count + 1;

% If a certain number data points have been collected from the Arduino, switch off the
% callbacks and plot the data.
 if src.UserData.Count > 8000 % number of data points collected.
   configureCallback(src, "off");
  end
end

