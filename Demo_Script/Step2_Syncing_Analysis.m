%This script will load the data from the screen event and camera events to create
%plots that evaluate hardware syncing. The script assumes that the OpenIris events determine the start and end of each trial

%% Processing data
% Ths step turns the files from OpenIris output into matlab files. It will prompt you to
% identify the location of the eye tracking data collected.
% Click on any text file in the eye tracking data folder to continue.
Processing_OpenIris_data; 

if isequal(file,0)
    return;
end

%% Load and manipulate data

%Load the data
load([fname_event_camera '.mat']);
load([fname_event '.mat']);

% RELEVANT INDEXES
%Index for all of the start and end of the first and last frame defined by
%OpenIris events that were in the demo script before and after each trial.
indstart = Events.Flag == "BeforeStimON"; %event before flip
indend   = Events.Flag == "AfterStimON"; %event after flip
%index for the phototransistor being triggered
idxPhoto = find(Events_camera.Int1==1); % a 1 indicates a trigger

% FRAMES THAT CORRESPOND TO EVENTS
% frames that correspond to the OpenIris events
beforeflip  = Events.FrameNumber(indstart);
afterflip   = Events.FrameNumber(indend); 
% the frames that correspond to the phototransistor being triggered
photoframe  = Events_camera.LeftFrameNumberRaw(idxPhoto);


% IDENTIFY THE FRAMES FOR EACH TRIAL USING OPENIRIS EVENTS
% Because the events are exicuted before and after the first and last flip 
% of a trial, to determine the duration of the trial we want the
% frames between the first before and the second openiris event.
% NOTE: right now we are using frames from the left camera.
FlipStartTrial = beforeflip(1:2:end); 
FlipEndTrial   = afterflip(2:2:end);  

for trial = 1:(length(beforeflip)/2)
    
    a = Events_camera.LeftFrameNumberRaw >= FlipStartTrial(trial); %greater than start frame
    b = Events_camera.LeftFrameNumberRaw <= FlipEndTrial(trial); %frames less than end frame
    trialInd(:,trial) = a == b; %logical array with 1s indicating the frames during the stimulus presentation

    % IDENTIFY WHICH PHOTRANSISTOR FRAMES CORRESPOND TO WHICH TRIALS
    % 10 frames are added to provide some buffer room just in case the
    % trigger does not align within the OpenIris start and end events. 
    a1 = photoframe >= FlipStartTrial(trial)-10;
    b1 = photoframe <= FlipEndTrial(trial)+10;
    photoInd(:,trial) = a1 == b1; 

end


% GRAB THE EYE MOVEMENT TRACES
% Make the data tables a large size out of NaNs. This is because each trial
% has a slightly different number of frames. 
TraceRightX = NaN(length(trialInd), (length(beforeflip)/2)); 
TraceLeftX  = NaN(length(trialInd), (length(beforeflip)/2)); 
TraceRightY = NaN(length(trialInd), (length(beforeflip)/2)); 
TraceLeftY  = NaN(length(trialInd), (length(beforeflip)/2)); 

%variables used for trial duration calculation
Framevector         = NaN(length(TraceLeftY),(length(beforeflip)/2));
Framevecor_fromzero = NaN(length(TraceLeftY),(length(beforeflip)/2)); %make NaN vector same length as data
%variable used for phototransistor frames
photoTrialFrames    = NaN(length(photoInd),(length(beforeflip)/2));

for trial  = 1:(length(beforeflip)/2)

    % X trace
    TraceRightX(1:length(Events_camera.RightPupilX(trialInd(:,trial))),trial)...
        = Events_camera.RightPupilX(trialInd(:,trial));
    TraceLeftX(1:length(Events_camera.LeftPupilX(trialInd(:,trial))),trial) ...
        = Events_camera.LeftPupilX(trialInd(:,trial));

    % Y trace
    TraceRightY(1:length(Events_camera.RightPupilY(trialInd(:,trial))),trial)...
        = Events_camera.RightPupilY(trialInd(:,trial));
    TraceLeftY(1:length(Events_camera.LeftPupilY(trialInd(:,trial))),trial)...
        = Events_camera.LeftPupilY(trialInd(:,trial));

    %FRAMES FROM ZERO FOR PLOTING
    %frames for trials
    Framevector(1:length(Events_camera.LeftFrameNumber(trialInd(:,trial))),trial) =...
        Events_camera.LeftFrameNumber(trialInd(:,trial));
    Framevecor_fromzero(:,trial) = Framevector(:,trial) - Framevector(1,trial); %subtract the time onset from all of the values so that the starting value is 0

    % frames of phototransistor trigger
    photoTrialFrames(1:length(photoframe(photoInd(:,trial),1)),trial) = photoframe(photoInd(:,trial),1); %grab the frames that were triggered for each trial
    photoFramevector_fromzero(1:length(photoTrialFrames(:,trial)),trial) =  photoTrialFrames(:,trial) - Framevector(1,trial);
end

% DURATION OF TRIALS & TRIGGERS IN SECONDS FOR PLOTTING
% identify the correct time for each trial
% Here will will do a quick estimate of time.
cameraRate_hz         = 100;
Time_fromzero_sec     = Framevecor_fromzero ./ cameraRate_hz; %time of each trial in sec
Time_phototrigger_sec = photoFramevector_fromzero ./ cameraRate_hz; %time of photo triggers

% PLOT THE EYE POSITION 
% plot eye position and the flag from the phototransister
% Note: if there is no calibration, than the eye movements cannot be
% plotted in pixels or in degrees.
subcounter = 0;
figure, hold on;
for trial = 1:(length(beforeflip)/2) %loop over trials

    for cord = 1:2 %x or y trace

        subcounter = subcounter + 1;
        subplot((length(beforeflip)/2),2,subcounter); hold on;

        if cord == 1
            title('X position');
        else
            title('Y position')
        end

        if cord == 1
            TraceRight = TraceRightX(:,trial);
            TraceLeft  = TraceLeftX(:,trial);
        else
            TraceRight = TraceRightY(:,trial);
            TraceLeft  = TraceLeftY(:,trial);
        end

        %eye trace
        plot(Time_fromzero_sec(:,trial),TraceRight) %right eye
        plot(Time_fromzero_sec(:,trial),TraceLeft) %left eye

        % phototransistor trigger line
        xline(Time_phototrigger_sec(:,trial),'r');

        if trial == 1
            legend('Right eye','Left eye');
            xlabel('seconds');
            ylabel('Position');
        end
    end
end
