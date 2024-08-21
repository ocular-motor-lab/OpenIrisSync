% Turn files from OpenIris output in the saved folder you selected into matlab
% files that can be manipulated later. Select just one of the files in the
% folder and it will process all of the data.

clear all; close all;

% Add path to data directory or make a new folder
expDir  = fileparts(which('Step3_Processing_data')); % Find current directory
dataDir = [expDir, '\Data\']; % ExpDir defined at beginning
% Check if data folder exits
if exist(dataDir, 'dir') == 0 % If the directory with the folder "data" exists
    mkdir Data
end
addpath(dataDir);


% Opens library identify the location of the data from OpenIris
% The location of your data will be determined by the path you chose before
% you ran the experiment in the OpenIris GUI.
[file,path] = uigetfile('*.txt');
addpath(path);
if isequal(file,0)
    warning('No file selected');
    return;
else
    disp(['User selected ', fullfile(path,file)]);
end

% Identify the names of the two relevant data files in the folder
if ~contains(file,'event')

    % Identify the event file
    [first,second] = strtok( file, '.' );
    file_events    = strcat(first,'-events',second);

    % The string of the data file
    file_camera    = file;

    % Name of file for camera events
elseif contains(file,'event')

    % Identfy the name of the camera event file
    file_camera = strrep(file,'-events',''); %removes '-events' fromthe file name

    % String of the other data file
    file_events = file;
end

% New names for new tables
if contains(file,'event')
    thisfile       = strrep(file,'-events',''); %removes '-events' fromthe file name
else
    thisfile       = file;
end
thisfile           = strrep(thisfile,'.txt','');
fname_event_camera = strcat('Events_camera-',thisfile);
fname_event        = strcat('Events-',thisfile);


%% Process open iris events into a usable data vectors

% Open the text file for reading
fid = fopen(file_events);

% Initialize vectors for the file contents
Time        = [];
FrameNumber = [];
Message     = [];
Flag        = [];
Data        = [];


% Read it out line by line
while( 1 )

    % Get a line
    myline = fgetl( fid );

    % If no lines are left, break out of while loop
    if( myline == -1 )
        break;
    end

    % Parse myline
    [mytime,r]          = strtok( myline, ' ' );    % File name
    [myframenumber,r]   = strtok( r, ' ' );         % Actual tilt angle
    [mymessage,r]       = strtok( r, ' ' );         % Button press
    [myflag,r]          = strtok( r, ' ' );         % Response time
    mydata              = r(2:end);                 % Convert response time to number

    % Parse out the frame number into a number
    [~,myframenumberonly]   = strtok( myframenumber, '=' );
    myframenumbernum        = str2num(myframenumberonly(2:end));

    % Add to vectors
    Time        = [Time ; {mytime}];
    FrameNumber = [FrameNumber ; myframenumbernum];
    Message     = [Message; {mymessage}];
    Flag        = [Flag ; {myflag}];
    Data        = [Data ; {mydata}];

end

% put into a table
Events   = table(Time, FrameNumber, Message, Flag, Data, 'VariableNames',{'Time','FrameNumber','Message','Flag','Data'});
thisfile = [dataDir, fname_event, '.mat']; %data location and name
save(thisfile, 'Events');


%% Process camera events
% This data file holds the eye positions, the corresponding frames, and the
% trigger from the phototransistor.

% Read data from text file into a table
Events_camera = readtable(file_camera);

% Save the table as a MAT-file
thisfile = [dataDir, fname_event_camera, '.mat']; %data location and name
save(thisfile, 'Events_camera');
