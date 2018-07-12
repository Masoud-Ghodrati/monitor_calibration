% This code uses PsychImaging with I1 colorimeter to measure the 
% luminance for different levels (nMeas). Then gamma is calculated 
% based on the measurements

% Calibrate_PsycIm
% Calibrate monitor with I1
% PTB takes over monitor and gives instructions to:
% - calibrate I1 colorimeter
% - place colorimeter against monitor and press button after luminance
%   changes
% This function then fits the measured luminance data and can also plot the
% colour data
%
% INPUT
% nMeas - number of luminance samples
% modifiled by Masoud  11/4/2014
clc
Screen('Preference', 'SkipSyncTests', 1); 
nMeas = 5; % the number of luminance steps from dark to light (unifrom screen)
lambda = 380:10:730; % wavelengths (nm)
TimForLeaving = 3; % (sec) this time will allow you to go out the room and close the doors

KbName('UnifyKeyNames')

AssertOpenGL;   % We use PTB-3

screenNumber = max(Screen('Screens'));

% if you use ViewPixx/DataPixx for the first time run these to lines for
% setting,
% BitsPlusImagingPipelineTest(screenNumber);
% BitsPlusIdentityClutTest([],1)
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask','General','FloatingPoint32Bit');
% PsychImaging('AddTask','General','EnableDataPixxM16Output');
PsychImaging('AddTask','FinalFormatting','DisplayColorCorrection','SimpleGamma');

o=Screen('Preference','Verbosity',1);
[w,wind] = PsychImaging('OpenWindow',screenNumber);
Screen('Preference','Verbosity',o);

% gamma1=2.198; % measured on 10 April
% gamma1=2.3949; % measured on 11 April
% gamma1=2.3996; % measured on 11 April

% set the gamma to 1 at first
gamma1=1;
% use this command for gamma correction in your codes
PsychColorCorrection('SetEncodingGamma',w,1/gamma1)

% Confirm that there is an i1 detected in the system
if I1('IsConnected') == 0
    Screen('CloseAll');
    fprintf('\n             ** No i1 detected **\n');
        return;
end

% i1 needs to be calibrated after plugging it in, and before doing any measurements.
% fprintf('\nPlace i1 onto its white calibration tile, then press i1 button to continue: \n');

Message='Place i1 onto its white calibration tile, then press i1 button to continue';
while I1('KeyPressed') == 0
   
    DrawFormattedText(w,Message,'center','center');
    Screen('Flip',w);
    WaitSecs(0.01);
    
end

fprintf('Calibrating...');
I1('Calibrate');

% Now we can take any number of measurements, and collect CIE Lxy and raw spectral data for each measurement.
% For demo purposes, we'll just collect a single datum, print the Lxy coordinates, and plot the spectral data.
Message=['Place i1 sensor against monitor, then press i1 button to measure. \n Luminance will automatically incrementn' ...
    '\n \n You have  ** ' num2str(TimForLeaving) '  **  seconds to go out and close the door(s) aftre pressing i1 button'];
while I1('KeyPressed') == 0
    
    DrawFormattedText(w,Message,'center','center');
    Screen('Flip',w);
    WaitSecs(0.01);

end



try

    maxLevel = Screen('ColorRange', w);   
    Lxy = nan(nMeas,3); % luminance data
    spec = nan(nMeas,36); % spectral data
    
    in = linspace(0,maxLevel,nMeas);
    
    for a = 1:length(in),
        
        I=in(a)*ones(wind(4),wind(3));
        
        Tex=Screen('MakeTexture',w,I,[],[],2);
        Screen('DrawTexture',w,Tex,[],[],0)
        Screen('Flip',w);
        
        if a==1, 
            WaitSecs(TimForLeaving) 
        end
        
        pause(0.3)
        I1('TriggerMeasurement');
        Lxy(a,:) = I1('GetTriStimulus');
        spec(a,:) = I1('GetSpectrum');
    end
    
    % Restore normal gamma table and close down:
    RestoreCluts;
    Screen('CloseAll');
catch %#ok<*CTCH>
    RestoreCluts;
    Screen('CloseAll');
    psychrethrow(psychlasterror);
end

%
%     displayRange = range(vals);
%     displayBaseline = min(vals);
%
if ~exist('fittype'); %#ok<EXIST>
    fprintf('This function needs fittype() for automatic fitting. This function is missing on your setup.\n');
    fprintf('Therefore i can''t proceed, but the input values for a curve fit are available to you by\n');
    fprintf('defining "global vals;" and "global inputV" on the command prompt, with "vals" being the displayed\n');
    fprintf('values and "inputV" being user input from the measurement. Both are normalized to 0-1 range.\n\n');
    error('Required function fittype() unsupported. You need the curve-fitting toolbox for this to work.\n');
end

%% Fit Gamma functions

% normalise the measured / input values to range [0 1]
inNorm = in';
lumNorm = (Lxy(:,1)-min(Lxy(:,1))) / range(Lxy(:,1));

%         vals = (vals - displayBaseline) / displayRange;
%     inputV = inputV/maxLevel;

xFit = in';
%Gamma function fitting

g = fittype('x^g');
model1 = fit(inNorm,lumNorm,g);
displayGamma = model1.g;
gTab1 = xFit.^(1/model1.g); % Gamma Table
yFit1 = model1(xFit);

%Spline interp fitting
model2 = fit(inNorm,lumNorm,'splineinterp');
yFit2 = model2(xFit);
% gTab2 = fittedmodel(xFit);


%% PLOTTING
figure
subplot 221
plot(in,Lxy(:,1),'k.')
hold on
plot(in,sum(spec,2),'ro')
xlabel('input drive')
ylabel('luminance')

subplot 222
plot(inNorm,lumNorm,'k.')
hold on
plot(xFit,yFit1,'r-')
plot(xFit,yFit2,'b:')
xlabel('normalised input drive')
ylabel('normalised luminance')

subplot 212
plot(lambda,spec)
xlabel('wavelength')
ylabel('something')

