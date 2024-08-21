% To run this script, you will need to have run Step1 and have NOT cleared your workspace.

% In Step 1 the serial output of the Arduino is recorded while the script
% is running so the recording will begin and end  before and after the 
% stimulus is presented. Therefore, this figure shows the serial
% output for a larger time than the stimulus presentation.

% Plot serial output of the photo transistor
UserData_idx = ~isnan(arduinoObj.UserData.Data);
UserData     = arduinoObj.UserData.Data(UserData_idx);
samples      = [0:length(UserData)-1];

figure;
title('Serial output from phototransistor')
plot(samples,UserData); hold on;
xlabel('Samples');
ylabel('Light intensity (arbitrary unit)');
