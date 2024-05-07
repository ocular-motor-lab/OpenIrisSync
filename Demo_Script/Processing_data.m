%Turn files from OpenIris output into matlab files
%It should not matter which text file you select first. Just select a text
%file from the location that the data is saved. 

 clear all; close all;

%Add path to data directory or make a new folder
expDir  = fileparts(which('Processing_data')); %find current directory
dataDir = [expDir, '\Data\']; %expDir devfined at beginning
%check if data folder exits
if exist(dataDir, 'dir') == 0 %if the directory with the folder "data" exists
    mkdir Data
end
addpath(dataDir); 


 %Gui to identify the location of the data from OpenIris
 %The location of your data will be determined by the path you chose before
 %you ran the experiment in the OpenIris GUI.
 [file,path] = uigetfile('*.txt');
 addpath(path);
 if isequal(file,0)
     warning('No file selected');
     return;
 else
     disp(['User selected ', fullfile(path,file)]);
 end

%Identify the names of the two relevant data files 
%this allows the user to click on either text file in the folder.
if ~contains(file,'event')
    %identify the event file 
    [first,second] = strtok( file, '.' );
    file_events    = strcat(first,'-events',second);
    %the string of the data file
    file_camera    = file;

%Name of file for camera events
elseif contains(file,'event')
    %identfy the name of the camera event file
    file_camera = strrep(file,'-events',''); %removes '-events' fromthe file name
    %string of the other data file
    file_events = file;
end

%New names for new tables
if contains(file,'event')
    thisfile       = strrep(file,'-events',''); %removes '-events' fromthe file name
else
    thisfile       = file;
end
thisfile           = strrep(thisfile,'.txt','');
fname_event_camera = strcat('Events_camera-',thisfile);
fname_event        = strcat('Events-',thisfile);


%% PROCESS OPIN IRIS EVENTS
%This data file holds the events that were in the demo script.

% open the text file for reading
fid = fopen(file_events);

% initialize vectors for the file contents
Time        = [];
FrameNumber = [];
Message     = [];
Flag        = [];
Data        = [];


% and read it out line by line
while( 1 )

    % get a line
    myline = fgetl( fid );

    % if no lines are left, break out of while loop
    if( myline == -1 )
        break;
    end

    % parse myline
    [mytime,r]          = strtok( myline, ' ' );    %file name
    [myframenumber,r]   = strtok( r, ' ' );         % actual tilt angle
    [mymessage,r]       = strtok( r, ' ' );         % button press
    [myflag,r]          = strtok( r, ' ' );         % response time
    mydata              = r(2:end);              % convert response time to number

    % parse out the frame number into a number
    [~,myframenumberonly]   = strtok( myframenumber, '=' );
    myframenumbernum        = str2num(myframenumberonly(2:end));

    % add to vectors
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


%% PROCESS CAMERA EVENTS
%This data file holds the eye positions, the corresponding frames, and the
%trigger from the phototransistor.
 
% Read data from text file into a table
Events_camera = readtable(file_camera);

% Save the table as a MAT-file
thisfile = [dataDir, fname_event_camera, '.mat']; %data location and name
save(thisfile, 'Events_camera');
