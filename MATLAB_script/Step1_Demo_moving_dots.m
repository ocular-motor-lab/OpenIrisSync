% This demo simulates an experiment that you could use to measure
% the ocular following response and incorporate hardware syncing. Horizontally 
% moving dots are presented and a white square is presented at the bottom
% of the screen for the duration of the trial for multiple trials.

% To run the demo you need to...
% (1) Plug the Arduino to the experimental computer. 
% (2) Place the phototransistor with respective cover on to the bottom left 
%     corner of the screen. The phototransistor should be aligned such that 
%     it is directly over the flashing white square.
% (3) Change the hardcoded values below to match your setup. 
% (4) Identify the serial port of the arduino IDE to rename port below. To
%     identify the serial port, open arduino IDE app click on "tools" ->
%     "Boards" choose your arduino board. Then, click "tools" -> "ports"
%     and select the port that has the name of your board next to it.
%     Change the port number in this script to the approapriate port.
%     **Close artduino IDE** (if the serial monitor is on this script will
%     not run)
% (5) Make sure that you have followed the instructions on the Wiki to
%     upload the necessary script to the Arduino Uno. 
% (6) Open OpenIris and set up as usual and choose the data file path.

%% Basic set up
clear all;
AssertOpenGL;

% Screen width and height
ds.height_m        = 0.2975;
ds.width_m         = 0.5345;
screenNumber       = 1; %screen to present on

% Screen distance, needed for calculating pixel/deg
ds.DistToScreen_m  = 0.4; 
ds.frame_rate_Hz   = Screen('NominalFrameRate',screenNumber);

% Arduino seral port
APort = "COM4"; %change this to change the port

% Demo experiment variables
ThisFileName         = 'TEST';
data.trials          = 50; % number of trials to run

%% Set up Arduino serial port

% Specify serial port for Matlab and initializing a structure to store data
if ~exist('arduinoObj','var')  
    arduinoObj = serialport(APort,57600); %57600
end

configureTerminator(arduinoObj,"CR/LF"); % telling MATLAB when line is terminated

% Flush the serialport object to remove any old data.
flush(arduinoObj);

% Make a data structure that includes the serial output data and a counter
% to keep track of how many times the data has been read out. 
arduinoObj.UserData = struct("Data",[],"Count",1);

%% Set up screen

% sync test and open window
Screen('Preference', 'SkipSyncTests', 1); % sync test if you can, if not change this to 0
[ds.w, ds.windowRect] = Screen('OpenWindow', screenNumber, 0); 

% Screen dimensions in pixels
screenWidth_px  = ds.windowRect(3);
screenHeight_px = ds.windowRect(4);

% Calculate pixel/deg
ds.height_deg = 2* atand((ds.height_m/2) /  ds.DistToScreen_m);
ds.width_deg  = 2* atand((ds.width_m/2) /  ds.DistToScreen_m);
pixdeg        = ((screenHeight_px / ds.height_deg) + (screenHeight_px/ds.width_deg)) / 2;

% Alpha blending for dots
Screen('BlendFunction', ds.w,'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%% Variables for white square presentation

% Calculate dimensions of the stimulus
ppm =( (screenWidth_px ./ ds.width_m) + (screenHeight_px ./ ds.height_m) )./2; %pixels per meter

% Calculate the width of the square in pixels
wsquareWidth_m      = 0.01; 
wsquareDistFromEdge = 0.015;
wsquareFarEdge      = wsquareDistFromEdge + wsquareWidth_m;

% Define the square position at the bottom of the screen in pixels
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

%% Dot specifications

% Dot size
dotSize_deg = 1;
dotSize_px  = round(dotSize_deg .* pixdeg); 

% Dot speed
dot_speed_deg_sec   = 30;
dot_speed_pix_sec   = dot_speed_deg_sec .* pixdeg; 
dot_speed_pix_frame = round(dot_speed_pix_sec ./ ds.frame_rate_Hz); %pixel movement per flip

% Dot number
dot_num = 100;

% Create a vector of dot positions
jitter_amount = 100;
dot_col       = round(sqrt(dot_num)); %number of columns and rows of dot grid
x_dots        = linspace(0,ds.windowRect(3)-200,dot_col); %dots to the edge of the screen
y_dots        = linspace(0,ds.windowRect(4)-200,dot_col);
[X,Y]         = meshgrid(x_dots,y_dots);

x_dots_jit    = round(X + jitter_amount * randn(size(X)));
y_dots_jit    = round(Y + jitter_amount * randn(size(Y)));
dots          = [reshape(x_dots_jit,1,[]); reshape(y_dots_jit,1,[])];

%% Set up eyetracking

% Connect to OpenIris
v = ArumeHardware.VOG();
v.Connect();

% Set the session name (affects the name of the files being recorded)
v.SetSessionName(ThisFileName); % name the session

v.StartRecording(); % begins the recording.

%% Start Arduino serial recording

configureCallback(arduinoObj,"terminator",@readData); % after next terminator read the data in arduinoObj
% @ puts the arduino object into readData

%% Stimulus presentation
% there is a black screen presented at the beginning and end of the
% experimental proceedure. The proceedure is composed of multiple trials. 

% One second of black screen at the beginning and inbetween trials. 
preStimulation_dur_sec     = 1;
preStimuluation_dur_frames = preStimulation_dur_sec*ds.frame_rate_Hz; % number of frames pre presentation

% Stimulus duration (duration of dot moving)
stimTime_sec    = 2; % duration of each trial
stimTime_frames = stimTime_sec*ds.frame_rate_Hz; % number of frames for presentation

% For each trial...
for trial = 1:data.trials

    tfc = 0; % counter for number of frames in each trial

    StartTime   = GetSecs; % time trial started

    % First, just black screen
    for x = 1:preStimuluation_dur_frames
        %black screen
        Screen('FillRect',ds.w,[0,0,0])
        %flip screen
        Screen('DrawingFinished', ds.w);
        [StartFlip_s, OnsetTime,EndFlip_s, Missed, Beampos] = Screen('Flip', ds.w,[],[],[]);
        tfc = tfc + 1; % increment frame counter

    end

    % Record timing
    PreStimCompleteTime = GetSecs;
    PreStimTime         = PreStimCompleteTime - StartTime;
    PreStimFrames       = tfc - 1;

    % Now present moving dots and the white square.
    for x = 1: stimTime_frames

        % Draw the dots
        Screen('DrawDots',ds.w,dots,dotSize_px,[],[],1);
          
        % Draw black square that is behind the white square
        Screen('FillRect', ds.w, [0,0,0], [ksquareLeft, ksquareTop, ksquareRight, ksquareBottom]);
        % White square calibration
        Screen('FillRect', ds.w, [255,255,255], [wsquareLeft, wsquareTop, wsquareRight, wsquareBottom]);

        % First and last frame of the trial record event flags from OpenIris
        if x == 1 || x == stimTime_frames  

            v.RecordEvent('BeforeStimON'); %OpenIris event flag
            Screen('Flip', ds.w,[],[],[]);
            v.RecordEvent('AfterStimON');  %OpenIris event flag

        else
            Screen('Flip', ds.w,[],[],[]);
        end

        % Move dots
        dots(1,:) = dots(1,:) + dot_speed_pix_frame; % change the x coordinate

        % If the dots go off the screen, put them back on the other side
        if find(dots(1,:)>ds.windowRect(3))

            idx         = find(dots(1,:)>ds.windowRect(3)); %positions where dots are off the screen
            dots(1,idx) = 5; %start the position at this many pixels on the other side of thes screen

        end

        tfc = tfc + 1; % increment frame counter

    end

    % Record timing
    StimCompleteTime = GetSecs;
    StimTime = StimCompleteTime - PreStimCompleteTime;
    StimFrames = tfc - 1 - PreStimFrames ;

    % Last, just black screen again
    for x = 1:preStimuluation_dur_frames
        % Black screen
        Screen('FillRect',ds.w,[0,0,0])
        % Flip screen
        Screen('DrawingFinished', ds.w);
        [StartFlip_s, OnsetTime,EndFlip_s, Missed, Beampos] = Screen('Flip', ds.w,[],[],[]);
        tfc = tfc + 1; % increment frame counter

    end
end

v.StopRecording(); %stops eye movement recordings

% Resets keyboard and contrles listening. 
ListenChar(1);
sca;

%% Function 
% Collect serial output from arduino during the experiment. 
% It only collects a set number of data points. Increasing the samples
% collected makes the code run more slowely. 

function readData(src, ~)

% Read the ASCII data from the serialport object.
data = readline(src);

% Convert the string data to numeric type and save it in the UserData
% property of the serialport object.
src.UserData.Data(end+1) = data;

% Update the Count value of the serialport object.
src.UserData.Count = src.UserData.Count + 1;

% If a certain number data points have been collected from the Arduino, switch off the
% callbacks and plot the data.
 if src.UserData.Count > 12000 % number of data points collected.
   configureCallback(src, "off");
  end

end


