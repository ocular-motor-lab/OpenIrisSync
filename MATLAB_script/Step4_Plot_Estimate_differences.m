% This script plots the estimates for hardware and software stimulus onset
% and determines the average difference of these estimates. It also plots
% the average eye positions across the trials with the onset specified by
% the hardware or software stimulus onset estimate. 

% Calculate the sample rate of the camera
bw_frames_sec  = mean(diff(Events_camera.LeftSeconds)); %average time between frames
cameraRate_hz  = 1./bw_frames_sec;

%% Hardware and software stimulus onset estimates in terms of camera samples

% Index for start and end trial for hardware and software synching 
% Software 
indstart = Events.Flag == "BeforeStimON"; % Event before flip
indend   = Events.Flag == "AfterStimON";  % Event after flip
% Hardware
TriggerInd_h = find(Events_camera.Int1==1); % All camera samples where there was a 1

% The camera sample number that corresponds to the OpenIris software events.
% Note: we have the camera sample for before and after the first and last
% flip of the trial. 
beforeflip  = Events.FrameNumber(indstart);
afterflip   = Events.FrameNumber(indend); 
% Collect the camera sample number that occured *before* the screen flip at 
% the start of each trial for every trial. 
SoftwareStartEst = beforeflip(1:2:end);
% Collect the camera sample number that occured *after* the Screen flip at
% the end of each trial. 
SoftwareEndEst   = afterflip(2:2:end);  

% The camera sample numbers that corresponds to the phototransistor being
% triggered. But, they are not separated based on trial. 
AllSamples_h  = Events_camera.LeftFrameNumberRaw(TriggerInd_h);

% Difference to find division of each trial.
di = find(diff(AllSamples_h) > 1); % Greater than 1 to indicates between trials

% Plot the camera sample numbers that corresponds to the software OpenIris 
% events and the phototransistor being triggered.
figure, hold on;
title('Triggers and OpenIris start and end event flags');
scatter(AllSamples_h,ones(1,numel(AllSamples_h)),'|','r');         % Phototransistor
scatter(SoftwareStartEst,ones(1,numel(SoftwareStartEst)),'g','|'); % Openiris events start trial
scatter(SoftwareEndEst,ones(1,numel(SoftwareStartEst)),'k','|');   % OpenIris events end trial
legend({'Phototransistor triggers','OpenIris Start Event','OpenIris End Events'});
xlabel('Camera samples');
set(gca,'yticklabel',{[]});

%% Identify which hardware triggers belong to each trial 
% Do this for the software and hardware syching.

for trial = 1:(length(beforeflip)/2)
    
    % For the software events, identify which camera sample frames are 
    % within each trial. 
    a = Events_camera.LeftFrameNumberRaw >= SoftwareStartEst(trial); % greater than start frame
    b = Events_camera.LeftFrameNumberRaw <= SoftwareEndEst(trial);   % frames less than end frame
    % Logical array that can be used to index the camera sample frames that
    % correspond to each trial (row=sample, col=trials)
    TrialInd_s(:,trial) = a == b;  

    % We have a list of the camera samples numbers for when the phototransistor
    % was triggered, however we don't know which samples belong to which
    % trials. Using the difference between the sample numbers we can
    % identify which triggers belong to which trial. 
    if trial == 1
        a1 = Events_camera.LeftFrameNumberRaw >= AllSamples_h(1);
    else
        a1 = Events_camera.LeftFrameNumberRaw >= AllSamples_h(di(trial-1)+1);
    end

    if trial == length(beforeflip)/2
        b1 = Events_camera.LeftFrameNumberRaw <= AllSamples_h(end);
    else
        b1 = Events_camera.LeftFrameNumberRaw <= AllSamples_h(di(trial));
    end
    % Index for hardware estimated start and stop for each trial. 
    TrialInd_h(:,trial) = a1 == b1;

end


%% Identify eye position in correspondence with hardware and software onset and offset

trialdur_sec = 0.25; % Desired trial duration in seconds to plot
trialSamples = round(cameraRate_hz .* trialdur_sec); % Number of samples in desired trial duration

TraceRight_s_X = NaN(trialSamples, length(beforeflip)/2);
TraceLeft_s_X  = NaN(trialSamples, length(beforeflip)/2);
TraceRight_h_X = NaN(trialSamples, length(beforeflip)/2);
TraceLeft_h_X  = NaN(trialSamples, length(beforeflip)/2);
Samples_s_X    = NaN(trialSamples, length(beforeflip)/2);
Samples_h_X    = NaN(trialSamples, length(beforeflip)/2);

% Loop through trials 
for trial  = 1:(length(beforeflip)/2)

    % Eye x position traces onset is estimated by software synching
    % Grab the traces that correspond to each trial.
    TraceRight_s = Events_camera.RightPupilX(TrialInd_s(:,trial));
    TraceLeft_s  = Events_camera.LeftPupilX(TrialInd_s(:,trial));
    
    % Store traces of only the first few ms for plotting
    TraceRight_s_X(:,trial) = TraceRight_s(1:trialSamples);
    TraceLeft_s_X(:,trial)  = TraceLeft_s(1:trialSamples);

    % Eye X position traces onset is estimated by hardware synching
    TraceRight_h = Events_camera.RightPupilX(TrialInd_h(:,trial));
    TraceLeft_h  = Events_camera.LeftPupilX(TrialInd_h(:,trial));

    % Store traces of only the first few ms for plotting
    TraceRight_h_X(:,trial) = TraceRight_h(1:trialSamples);
    TraceLeft_h_X(:,trial)  = TraceLeft_h(1:trialSamples);

    % Camera samples that correspond to the duration of the trial
    Samples_s = Events_camera.LeftFrameNumber(TrialInd_s(:,trial)); % Software
    Samples_h = Events_camera.LeftFrameNumber(TrialInd_h(:,trial)); % Hardware

    % Grab only a select trial duration
    Samples_s_X(:,trial) = Samples_s(1:trialSamples); % Software
    Samples_h_X(:,trial) = Samples_h(1:trialSamples); % Hardware

    % Calculate difference between hardware and software synching stimulus
    % onset estimate
    StartDiff_samples(trial) = Samples_s(1) - Samples_h(1);
    StartDiff_ms(trial)      = (bw_frames_sec .* StartDiff_samples(trial)).*1000;

end

% Print average difference between hardware and software estimated stimulus
% onset and offset times.
disp(['Difference in hardware and software synching (ms) =',num2str(mean([StartDiff_ms])),'+/- ',num2str(std([StartDiff_ms]))]);

% Plot a histogram of the differences in estimated onset time based on the
% hradware and the software. 
figure, hold on;
title('Difference in hardware and software synching')
hist(StartDiff_ms);
xlabel('Difference (ms)');
ylabel('Frequency');

%% Plot eye position and velocity based on hardware or software stimulus onset
% I first plot position and then velocity of the eye movements to obesrve
% the ocular following response. 
% In both plots, 0 represents the hardware and software estimated stimulus 
% onset. You can see the offset of the eye positions depending on which 
% method you are using. 

% Determine x axis of plot based on the number of sample taken
% 0 represents estimate of onset based on software and hardware synchronization.
Samples_s_X_fromzero = Samples_s_X(:,1) - Samples_s_X(1);
Samples_h_X_fromzero = Samples_h_X(:,1) - Samples_h_X(1);

% Convert camera samples of estimated start and stop in to seconds. 
Time_sec_s = Samples_s_X_fromzero ./ cameraRate_hz;
Time_sec_h = Samples_h_X_fromzero ./ cameraRate_hz;

% Average position over the eyes and over the trials for software synching
SoftwareTraceX_avg  = nanmean([TraceRight_s_X,TraceLeft_s_X],2);
SoftwareTraceX_sd   = nanstd([TraceRight_s_X,TraceLeft_s_X],0,2);
SoftwareTraceX_95CI = 1.96 .* SoftwareTraceX_sd ./ sqrt((length(beforeflip)));

% Average velocity for x position over the trials for software synching
is = medfilt1(diff([TraceRight_s_X,TraceLeft_s_X]),1,15) .* cameraRate_hz; 
VX_filt_s_avg  = nanmean(is,2); % Average
VX_filt_s_sd   = nanstd(is,0,2); % Standard deviation
VX_filt_s_95CI = 1.96 .* VX_filt_s_sd ./ sqrt((length(beforeflip)));

% Average position over the eyes and over the trials for hardware synching
HardwareTraceX_avg = nanmean([TraceRight_h_X,TraceLeft_h_X],2);
HardwareTraceX_sd  = nanstd([TraceRight_h_X,TraceLeft_h_X],0,2);
HardwareTraceX_95CI = 1.96 .* HardwareTraceX_sd ./ sqrt((length(beforeflip)));

% Average velocity for x position over the trials for software synching
ih = medfilt1(diff([TraceRight_h_X,TraceLeft_h_X]),1,15) .* cameraRate_hz; 
VX_filt_h_avg = nanmean(ih,2); % Average
VX_filt_h_sd = nanstd(ih,0,2); % Standard deviation
VX_filt_h_95CI = 1.96 .* VX_filt_h_sd ./ sqrt((length(beforeflip)));

% Plot eye position 
figure, hold on;

% Caluclate fill areas which will represent the 95% Confidence interval.
x_fill_s = [Time_sec_s; flipud(Time_sec_s)]; % Software
x_fill_h = [Time_sec_h; flipud(Time_sec_h)]; % Hardware

% Create a polygon that will be the filled region around the average that
% represents the standard deviation.
y_fill_s = [SoftwareTraceX_avg + SoftwareTraceX_95CI;...
    flipud(SoftwareTraceX_avg - SoftwareTraceX_95CI)];

y_fill_h = [HardwareTraceX_avg + HardwareTraceX_95CI;...
    flipud(HardwareTraceX_avg - HardwareTraceX_95CI)];

% Identify NaNs in eye traces that are a result of errors in eye tracking. 
% The fill script will not work if there are NaNs in the eye tracking data.
if find(isnan(y_fill_s))

    y_fill_s(isnan(y_fill_s)) = 0;

elseif find(isnan(y_fill_h))

    y_fill_h(isnan(y_fill_h)) = 0;

end
    
%Fill the region that represents the 95 percent confidence interval
fill(x_fill_s, y_fill_s, 'g', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
fill(x_fill_h, y_fill_h, 'b', 'FaceAlpha', 0.3, 'EdgeColor', 'none');

% Plot mean lines
s = plot(Time_sec_s,SoftwareTraceX_avg,'g');
h = plot(Time_sec_h,HardwareTraceX_avg,'b');

xlabel('Seconds');
ylabel('X Position');
title('Onset estimate changes time frame of response');
legend([h,s],'Hardware','Software');



% Plot Velocity 
figure; hold on;

% Caluclate fill areas which will represent the 95% Confidence interval.
% We are removing a few data points because we loose data points when we
% calculate velocity. 
x_fill_s = [Time_sec_s(1:end-1); flipud(Time_sec_s(1:end-1))]; % Software
x_fill_h = [Time_sec_h(1:end-1); flipud(Time_sec_h(1:end-1))]; % Hardware

% Filled regions to represents the 95 percent confidence interval.
y_fill_v_s = [VX_filt_s_avg + VX_filt_s_95CI;...
    flipud(VX_filt_s_avg - VX_filt_s_95CI)];

y_fill_v_h = [VX_filt_h_avg + VX_filt_h_95CI;...
    flipud(VX_filt_h_avg - VX_filt_h_95CI)];

% Identify NaNs in eye velocites that are a result of errors in eye tracking. 
% The fill script will not work if there are NaNs in the eye tracking data.
if find(isnan(y_fill_v_s))

    y_fill_v_s(isnan(y_fill_v_s)) = 0;

elseif find(isnan(y_fill_v_h))

    y_fill_v_h(isnan(y_fill_v_h)) = 0;

end

% Fill the region that represents the 95 percent confidence interval
fill(x_fill_s, y_fill_v_s, 'g', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
fill(x_fill_h, y_fill_v_h, 'b', 'FaceAlpha', 0.3, 'EdgeColor', 'none');

% Mean velocity
s = plot(Time_sec_s(1:end-1),VX_filt_s_avg,'g');
h = plot(Time_sec_h(1:end-1),VX_filt_h_avg,'b');

xlabel('Seconds');
ylabel('Velocity');
title('Onset estimate changes time frame of response');
legend([h,s],'Hardware','Software');
