% This script needs to be run after step 3 and 4. It creates a plot the
% the hardware estimate for onset and offset with the x position eye 
% movements. 


figure, hold on;

for trial  = 1:(length(beforeflip)/2)

    subplot((length(beforeflip)/2),2,trial); hold on;
    title(strcat('Trial ',num2str(trial)));

    % When selecting the eye positions, I want to grab more eye position
    % frames after the offset to plot a longer duration of eye movements.
    % replace zeros with 1s to extend the eye movement data that gets
    % plotted.
    TrialInd_s_extended = TrialInd_s(:,trial);
    startpos            = max(find(TrialInd_s_extended == 1));
    TrialInd_s_extended(startpos:startpos+150) = 1; % add ones

    % Used for indexing
    tlengths_s = sum(TrialInd_s_extended);

    % Eye x position traces for software
    TraceRight = Events_camera.RightPupilX(TrialInd_s_extended);
    TraceLeft  = Events_camera.LeftPupilX(TrialInd_s_extended);
    
    % Camera samples that correspond to the duration of the trial
    Samples_eye          = Events_camera.LeftFrameNumber(TrialInd_s_extended); % Software
    Samples_eye_fromzero = Samples_eye - Samples_eye(1);
    Time_sec             = Samples_eye_fromzero ./ cameraRate_hz;

    % Time of phototransistor first and last sample the square is presented
    Samples_h_photo              = Events_camera.LeftFrameNumber(TrialInd_h(:,trial)); % Hardware
    % Time relative to the eye position time.
    Samples_h_photo_fromzero     = Samples_h_photo(:,1) - Samples_eye(1);
    Samples_h_photo_fromzero_sec = Samples_h_photo_fromzero ./ cameraRate_hz;

    % Eye trace
    hold on;
    plot(Time_sec,TraceRight) 
    plot(Time_sec,TraceLeft) 

    % Phototransistor triggers for first and last frame the white square is
    % presented. 
    y1 = Samples_h_photo_fromzero_sec(1);
    xline(y1,'r');
    y2 = Samples_h_photo_fromzero_sec(end);
    xline(y2,'r');

    if trial == 1
        legend('Right eye','Left eye');
        xlabel('Seconds');
        ylabel('Position');
    end

end
