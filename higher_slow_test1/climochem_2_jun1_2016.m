function climochem_2(runPath,runCode,MIF)
% Version CliMoChem 2.0 31.03.2009
% CLIMOCHEM: A Global Multicompartment Model for POPs
% contact Linus Becker in case of problems, linus.becker@chem.ethz.ch
% or Urs Schenker, urs.schenker@chem.ethz.ch, 
% 
% use CCcontrol.m (in the input folder) to set parameters for CliMoChem
%
% code construction sites are marked with xxx, beware!
% most important construction sites:
% - alpine modeling (contact Fabio Wegmann - Urs Schenker)
%   IT IS NOT RECOMMENDED TO RUN CLIMOCHEM WITH ALPINE REGIONS:
%   THIS FEATURE HAS NOT YET BEEN FULLY TESTED AND MAY NOT BE WORKING
%   PROPERLY...
%
% for a version history, see separate excel-file Bereinigung.xls
%
% planned or evaluated for future versions:
% - transport efficency indicator (MMacLeod): ongoing
% - grouped mass fluxes (fluxes with changed vs. unchanged rate constants)
% - incorporate mass balance check for vgross and m matrixes
% - various smaller changes as marked in the ToDoList in Bereinigung.xls
% - ...
% - (your proposal here  :)
%
%
% - VERSION HISTORY
%       2.0.1   BUGFIX
%
%       --> Calculation of Media Volumes (Snow and Ice) corrected
%
%       --> inconsistant program flow:
%           end of season adaption of media volumes (snow, ice, vegetation)
%           is now carried out after the calculation of masses for the old
%           season
%
%       2.0 relesead 31.03.2009
%
%           official Version  
%           CLIMOCHEM: A Global Multicompartment Model for POPs
%           in case of problems contact Linus Becker, 
%           linus.becker@chem.ethz.ch or Urs Schenker, 
%           urs.schenker@chem.ethz.ch, 


%%%%%%%%%%%%%%%%%%% PART 1 : GLOBAL PROGRAM INITIALIZATION %%%%%%%%%%%%%%%%

% delete all previously defined global vars
globvars = evalin('base','whos(''global'')');
fprintf('\n\n');
warning('clearing %d global variables with a total size of %d bytes.',...
    length(globvars), sum([globvars(:).bytes]));
for i = 1:length(globvars)
    if ~ isequal(globvars(i).name,'doNotDelete')
        evalin('base',['clear global ' globvars(i).name ';']);
    end
end
clear globvars;

tic     % used for analysis of duration of the runs in about.txt file

% global variables needed inside the climochem function are defined here;
% some of those functions are needed in CCcontrol.m only, but need to be
% defined here...
global year firstRun n nseasons nyears season listind firstRun3;
global nameSub nphases outPath screMsg screRes inPath c0 runCode MIF;
global exposure exposmax exposmaxt expNorm ctmaxc ctmaxd cendmaxc cendmaxt;
global elist lrlist OPmasflu fluxInd fluxCTab fluxtMTab nsubs subs nFluxes;
global fluxPTab fluxVTab fluxMTab fluxETab calcFluxFlag aboutFile nGZ maxM;
global OPvegvol OPconexp OPcolcon OPmobfra OPlogfil noTrans;

% the global variables initialized below are called in CCcontrol.m and have
% to be defined here (although the seem not to be used in climochem)...
global iceandsnow atmHeightTemp OPGGWcqu OPLRTDeg OPsnoice AeroMod nAlps;
global cOHvariable interRainFall solveMode OPmasdis vegseasons snowseasons;
global vegmod timeSteps fluxInTab OPZones screCal deepSeaWater SizeDif ice;
global OPIndi startyear;

% dealing with paths of climochem...
if exist('runPath','var')==0
    fprintf(1,'\n\nno path to execute CliMoChem was given\n');
    fprintf(1,'CliMoChem tries to run in the program directory\n\n');
    runPath= [cd filesep];
end
inPath = [runPath 'inputs' filesep];
outPath = [runPath 'outputs' filesep];

%runCodes are used to identify files from different runs
if isempty(runCode)
    a=clock;
    rand('twister',a(6));
    runCode=round(rand*100000);
    clear('a');
    runCode = num2str(runCode);
    runCode = ['0000' runCode];runCode=runCode(end-4:end);
    fprintf(1,'\n\nrunCode was generated: %s\n',runCode);
end

% store the "code" folder, then switch folder to read some files from
% "inputs" / write to the "outputs" folders
temp=cd;
eval(['cd ' '''' inPath '''']);



% read CliMoChem Control file CCcontrol
% this file defines overall parameters for the run(s) and must be located
% in the input folder. alternatively, it can be read from the
% MasterInputFolder MIF

if exist([inPath 'CCcontrol.m'],'file') == 2
    CCcontrol;
elseif exist('MIF','var')
    eval(['cd ' '''' MIF '''']);
    CCcontrol;
    eval(['cd ' '''' inPath '''']);
else
    diary off;
    fclose all;
    error('no CCcontrol.m file found in the input path - no MIF given');
end

% % whole "if" loop above has to be replaced by the following statement if
% % climochem should be run from excel (during compilation)
% global snowice saveVars zeitstamp logvars klok zipzap OPlogfile;
% global backupOpt backupPath;
% xlsCliMoChem

if aboutFile
    % about.txt file
    % this file stores information about the run and will be printed
    % directly into the runPath
    aboutID=fopen([runPath 'about(' runCode ').txt'],'wt');
    if aboutID == -1
        diary off;
        fclose all;        
        error('climochem: cannot create about.txt file.');
    end

    fprintf(aboutID,'CliMoChem version 2.0\n');
    fprintf(1,'\nWrite one sentence to describe your run ');
    fprintf(1,'(written in about.txt file)\n\n');
    description = input('','s');
    fprintf(aboutID,'%s \n',description);

    fprintf(aboutID,'This run has runCode %s\n',runCode);
    fprintf(aboutID,'CliMoChem is run in %s folder \n',runPath);
end

% initialize program with basic parameters
if exist('parameters.m','file') == 0
    if screMsg
        disp(' ');
        disp('no parameters.m file found in input directory');
        disp('checking in the MIF directory');
    end
    if exist('MIF','var')
        eval(['cd ' '''' MIF '''']);
        if exist('parameters.m','file')
            if screMsg
                disp(' ');
                disp('parameters.m file found in MIF directory');
                disp('using specific parameters from this file');
            end
            parameters;
            eval(['cd ' '''' inPath '''']);
        else
            if screMsg
                disp(' ');
                disp('retrieving standard parameter values');
            end
            setParameters;
            eval(['cd ' '''' inPath '''']);
        end
    else
        if screMsg
            disp('retrieving standard parameter values');
        end
        setParameters;
    end
else
    if screMsg
        disp('parameters.m file found in input directory');
        disp('using specific parameters from this file');
    end
    parameters;
end


% return to the initial ("code") folder
eval(['cd ' '''' temp '''']);

% copy program files into the log-directory
if OPlogfil
    copyProgFiles;
end


% mysterious, mysterious...
format short g
if exist([inPath 'mysterious.dat'],'file') == 2
    firstRun3 = [inPath 'mysterious.dat'];
else
    firstRun3 = [MIF 'mysterious.dat'];
end

fileID = fopen(firstRun3);
if fileID == -1
    diary off;
    fclose all;    
    error('Cannot open file mysterious.dat');
else
    fclose(fileID);
end

elist = {};  % to store the nseasons EigenVecs and -Values (solveMode = 0)
             % or XtinvX0 and invMinusA matrizes (solveMode = 1)
lrlist = {}; % to store the LU.decomposed EigenVecs matrix



%%%%%%%%%%%%%%%%%%% PART 2 : PREFLIGHT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

readsubpar;             % reads substance parameters
readvegpar;             % reads vegetation parameters for different 
                            % vegetation types

readaerosolpar;         % reads advanced (2-type) aerosol parameters 
readsnowpar;            % reads snow parameters
readalps2;              % read some alps stuff...

maketmptab;             % creates zonal / seasonal temperature table

makeaerosolpar;         % calculates aerosol properties for ppLFER module
makeaerosolppLFER;      % calculates ppLFER-based aerosol partitioning

makevegzonen;           % creates zonal vegetation & snow/ice table
readsnowdepths;         % reads zonal specific snow heights
calcvegpartab;          % calculates veg-parameters for zonal veg-table
makesolarrad;           % creates a table with solar radiatino intensities

makesnowpartab;         % calculates snow-parameters for zonal s/i table
makesnowvolfactor;      % calculates seasonal snow volume factor table
makeicevolfactor;       % calculates seasonal ice volume factor table

makenewvoltab;          % create volume table 
makestabvec;            % creates seasonal atmos. stability vectors 
makevegvolfactab;       % calculates seasonal veg volume factor table
makevraintab;           % creates table with zonal / seasonal rain rates
makedeepseaparttab;     % creates table with deep sea part. concentrations
makedeepseavelocitab;   % creates table with deep sea particle deposition
                            % fluxes
readOH;                 % creates OH radical concentration table
makeDeepSeaWaterTab;    % creates the deepseawater formation table

readEmis;               % reads emissions

fluxInd = 1; % index, wandering thru fluxInTab
if calcFluxFlag == true
    fluxCTab = zeros(OPmasflu,nFluxes,nsubs);
    fluxETab = zeros(OPmasflu,nFluxes,nsubs);
end;

calcc0;                 % the initial pollutant concentration calculated 
                            % based on the initial peak emission data
if noTrans              % CCcontrol specifies no transport accross zones 
    makededdytabnull;
else
    makededdytabj;      % defines transport accross zones in atmos and air
end

exposure = zeros(nphases*(n+nGZ),nsubs);
exposmax = zeros(nphases*(n+nGZ),nsubs);
exposmaxt = zeros(nphases*(n+nGZ),nsubs);
expNorm = zeros(nphases+1,n,nsubs);
ctmaxc = zeros(nphases*(n+nGZ),nsubs);
ctmaxd = zeros(nphases*(n+nGZ),nsubs);
cendmaxc = zeros(nphases*(n+nGZ),nsubs);
cendmaxt = zeros(nphases*(n+nGZ),nsubs);
maxM=zeros(nsubs,1);
fluxPTab = zeros(OPmasflu, nFluxes, nseasons,nsubs);
fluxVTab = repmat(0,OPmasflu,nFluxes);
fluxMTab = repmat(0,OPmasflu,nFluxes);
fluxtMTab = repmat(0,OPmasflu,nFluxes);

if screMsg
    disp('prepare result files...');
end

makeggw;                % generates equilibrium constants (kow, kaw...)

createFiles;            % generates a series of output files

listind = 0; % counts the simulation seasons from 0 to nseasons * nyears
season = 1; % sets starting season

%%%%%%%%%%%%%%%%%%% PART 3 : MAINFLIGHT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
atime=toc;  % used for runtime analysis in about.txt

format long g

while year <= nyears
    listind = listind + 1;
    if screMsg
        disp2('Starting calculations for year',year,...
            'and season',listind-nseasons*year+nseasons);
    end
    if listind <= nseasons
        fluxInd = 1; % walks from 1...OPmasflu in each season of 1st year
        for subs=1:nsubs
            makevgross;     % creates the vgross matrix that deals with 
                                % exchanges between phases of the same zone
            fluxInd = 1;
            makem;          % creates the m matrix that deals with 
                                % degradation and transport between zones
        end
    else
        firstRun = false;
        if screMsg
            disp2('basis of',nseasons,'Eigensystems solved');
        end
    end


    if listind == nseasons+1;
        btime=toc-atime;    % used for runtime analysis in about.txt
    end

    dynamike;               % solution of the differential equation, 
                                % calculation of concentration & exposition
    if calcFluxFlag == true % creates mass flux tables
        makefluxvtab;
        for subs=1:nsubs
            makefluxetab;
            calcflux;
        end
    end
    
    for subs=1:nsubs

        writemasses;% writes the masses into file
        if vegmod ~= 0
            adjustvegec0;   % necessary since vegetation volume changes between seasons
        end
        if iceandsnow
            adjustsnow;
            adjustice;
        end

        if screRes
            disp2('maximal exposure summand in current season for substance',char(nameSub(subs,:)) ,listind,':',maxExpos);
            disp2('in compartment:',maxbox);
        end
    end
    
    calcconcratio;          % calculates conc. ratios between phases
    if listind == nseasons || listind == 10*nseasons
        arcticcontamination;    % calculates arctic contamination potential
    end
    copyctc0;                   % copies concentrations for flux files
    if OPcolcon
        cccalc;                 % cold concentrations
    end

    season = mod(season,nseasons)+1;
    if season == 1
        year = year + 1;
    end
end

if screMsg
    disp('    ');
    disp('Cycle thru all seasons completed. Enlightment achieved.');
    disp('    ');
end

ctime=toc-atime-btime;      % used for runtime analysis in about.txt

%%%%%%%%%%%%%%%%%%% PART 4 : POSTFLIGHT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if screRes
    for subs=1:nsubs
        disp2('Concentrations.end for substance',char(nameSub(subs,:)));
        for i = 1:nphases*n
            disp2(i,': ',c0(i,subs));
        end
    end
end
eval1;

for subs=1:nsubs
    quantil;            % calculates spatial range
    persistence;        % calculates persistence
    if OPvegvol
        makenewemdat;   % creates new emission table with end concs
    end
    if OPmobfra
        calcmobilfrac;  % mobile fraction output file
    end
    if OPconexp
        writecendmax;   % calculates maximal end concentrations
    end

    fileclose;          % output files are closed
end

if OPcolcon
    ccexpcalc;          % cold condensation output file
end
jpersist;               % joint persistence output file
jquantil;               % joint spatial range output file
cockpitReport;          % cockpitReport output file

mysterious;             % mysterious, mysterious...

if saveVars && OPlogfil
    % save all global variables in file similar to diarylog
    globvars = evalin('base','whos(''global'')');
    for i = 1:length(globvars)
        evalin('base',['global ' globvars(i).name ';']);
        tmp15851816 = evalin('base', ['eval(''' globvars(i).name ''');']);
        eval(['vars.' globvars(i).name ' = tmp15851816;']);
        evalin('base',['clear ' globvars(i).name ';']);
    end
    clear tmp15851816;
    assignin('base',['vars_' zeitstamp],vars);
    clear vars;
    evalin('base',['save(''' [logvars filesep 'vars_' zeitstamp ...
        '.mat'] ''', ''' ['vars_' zeitstamp] ''');']);
end

format short g;
if OPlogfil
    time = etime(clock,klok);   % used for runtime analysis in about.txt

    disp2('Program runtime is',time,'s');

    diary off;
end
disp('program.end');
fprintf(1,'\n\n');
errno = 0;

% zip the logvar directory if needed
if zipzap && OPlogfil
    zipname = ['logs&vars&m(' runCode ').zip'];
    zip(zipname,logvars);
    rmdir(logvars,'s');
    movefile(zipname, [outPath filesep zipname]);
end

% copy logfile to backup folder
if backupOpt
    mkdir(backupPath,runCode);
    copyfile([outPath zipname],[backupPath filesep runCode ...
        filesep zipname]);
end

dtime=toc-atime-btime-ctime;  % used for runtime analysis in about.txt

if aboutFile
    % runtime analysis in the about.txt file
    fprintf(aboutID,'Preflight time:      %1.2f ',atime);
    fprintf(aboutID,'\n1st year time:       %1.2f \n',btime);
    fprintf(aboutID,'rest of years time:  %1.2f ',ctime);
    fprintf(aboutID,'\npostflight time:     %1.2f \n',dtime);
    fprintf(aboutID,'TOTAL TIME:          %1.2f',toc);
    fclose(aboutID);
end


%%%%%%%%%%%%%%%%%%% THIS IS THE END OF THE CLIMOCHEM MAIN FUNCTION %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readsubpar
% READSUBPAR reads the substance parameters from the 'subs_prop.txt' file

global nameSub ksoil ksoilphoto kwat kwatphoto kair kairphoto kveg kice
global ksnow Easoil Eawat Eaair Eaveg;
global logKaw dUaw logKow dUow alpha beta logKha Vx molmass;
global nsubs subs inPath screMsg screCal MIF;

nameSub=zeros(nsubs,10);
ksoil=zeros(nsubs,1);
ksoilphoto=zeros(nsubs,1);
kwat=zeros(nsubs,1);
kwatphoto=zeros(nsubs,1);
kair=zeros(nsubs,1);
kairphoto=zeros(nsubs,1);
kveg=zeros(nsubs,1);
kice=zeros(nsubs,1);
ksnow=zeros(nsubs,1);
Easoil=zeros(nsubs,1);
Eawat=zeros(nsubs,1);
Eaair=zeros(nsubs,1);
Eaveg=zeros(nsubs,1);
logKaw=zeros(nsubs,1);
dUaw=zeros(nsubs,1);
logKow=zeros(nsubs,1);
dUow=zeros(nsubs,1);
alpha=zeros(nsubs,1);
beta=zeros(nsubs,1);
logKha=zeros(nsubs,1);
Vx=zeros(nsubs,1);
molmass=zeros(nsubs,1);

if screMsg
    disp(' ');
    disp('function readsubpar: reads substance parameters from file');
end
datanum = 22; % number of substance properties to be read, updated to 22 on June 1, 2016 (JB)
if exist([inPath 'subs_prop.txt'],'file') == 2
    fileID = fopen([inPath 'subs_prop.txt'], 'rt');
else
    fileID = fopen([MIF 'subs_prop.txt'],'rt');
end
if fileID ~= -1
    fgetl(fileID);
    fgetl(fileID);
    for subs=1:nsubs
        temp_str = fscanf(fileID, '%s', 1);
        if isempty(temp_str)
            diary off;
            fclose all;            
            error('readsubpar: not enough substances in subs_prop.txt');
        end
        nameSub(subs,1:length(temp_str)) = temp_str;
        subdata(:,subs) = fscanf(fileID, '%f', datanum);
        if length(subdata(:,subs)) ~= datanum
            diary off;
            fclose all;            
            error('readsubpar: wrong number of substance data');
        end
    end
    fclose(fileID); % close 'subs_prop.txt'
else
    diary off;
    fclose all;    
    error('Cannot open file subs_prop.txt');
end

% Adjusted kice and ksnow to be defined manually in the input text file [before both were just set equal to kwater] - June 1, 2016 (JB)
for subs=1:nsubs
    ksoil(subs)     = subdata(1,subs);
    ksoilphoto(subs)= subdata(2,subs);
    kwat(subs)      = subdata(3,subs);
    kwatphoto(subs) = subdata(4,subs);
    kair(subs)      = subdata(5,subs);
    kairphoto(subs) = subdata(6,subs);
    kveg(subs)      = subdata(7,subs);
    kice(subs)      = subdata(8,subs);
    ksnow(subs)     = subdata(9,subs);
    Easoil(subs)    = subdata(10,subs);
    Eawat(subs)     = subdata(11,subs);
    Eaair(subs)     = subdata(12,subs);
    Eaveg(subs)     = subdata(13,subs);
    logKaw(subs)    = subdata(14,subs);
    dUaw(subs)      = subdata(15,subs);
    logKow(subs)    = subdata(16,subs);
    dUow(subs)      = subdata(17,subs);
    alpha(subs)     = subdata(18,subs);
    beta(subs)      = subdata(19,subs);
    logKha(subs)    = subdata(20,subs);
    Vx(subs)        = subdata(21,subs);
    molmass(subs)   = subdata(22,subs);

    if screCal
        disp2('Substanz:',char(nameSub(subs,:)),' ksoil:',ksoil(subs),...
            ' ksoilphoto:',ksoilphoto(subs),' kwat:',kwat(subs),...
            ' kwatphoto:',kwatphoto(subs),' kair:',kair(subs),...
            ' kairphoto:',kairphoto(subs),' kveg:',kveg(subs));
        disp2(' kice:',kice(subs),' ksnow:',ksnow(subs),' Easoil:',...
            Easoil(subs),' Eawat:',Eawat(subs),' Eaair:',Eaair(subs));
        disp2(' Eaveg:',Eaveg(subs),' logKaw:',logKaw(subs),' dUaw:',...
            dUaw(subs),' logKow:',logKow(subs),' dUow:',dUow(subs));
        disp2(' alpha:',alpha(subs),' beta:',beta(subs),' logKha:',...
            logKha(subs),' Vx:',Vx(subs),' molmass:',molmass(subs));
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function openfluxfiles
% OPENFLUXFILES opens all mass fluxes storage files
% Writes Header lines and stores the FID in the fluxFileIDs matrix
% First row of fluxFileIDs contains k initial massflux fileIDs
% Second row is for t-integrated massflux fileIDs
% Third row for DIE REISE massflux fileIDs

global fluxInTab OPmasflu calcFluxFlag fluxFileIDs nFluxes;
global n nyears nseasons nameSub subs runCode screMsg outPath;

if screMsg
    disp(' ');
    disp2('function openfluxfiles: initialises mass flux files for ',...
        char(nameSub(subs,:)));
end
if calcFluxFlag == true
    for k = 1:OPmasflu
        % header lines strings
        sourcestr = {'source', 'soil', 'water', 'air',...
            'veg-soil', 'vegetation', 'ice', 'snow', 'all', ...
            'Mass-Bal', 'overall-Bal'};
        deststr = {'destination', 'soil', 'water', 'air',...
            'veg-soil', 'vegetation', 'ice', 'snow', 'none'};
        procstr = {'Year', 'Season', 'listind', 'leaching', 'runoff', ...
            'diffusion','uptake', 'wet-dep', 'dry-dep', 'rain-dep', ...
            'degrad','lrt-rechtshin', 'lrt-linkshin', 'lrt-rechtsher', ...
            'lrt-linksher', 'input deg', 'leaffall', 'phi', 'mass',...
            'depos','photo.deg','deepwatform'};
        % source header line
        writesrcstr = sourcestr([1 2 2 2 2 4 4 4 4 2 2 3 4 4 4 4 2 2 3 ...
            4 4 4 4 4 4 4 4 2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 5 5 4 4 4 4 ...
            4 4 4 4 5 5 6 4 4 4 4 5 5 5 5 6 4 4 4 4 6 6 5 6 4 10 10 10 ...
            10 10 10 10]); % sources until 80 (inclusive)
        writesrcstr = [writesrcstr sourcestr([4 4 4 4 4 4 4 4 7 7 4 4 4 ...
            4 4 4 4 4 8 8 8 8 8 8 8 8 7 8 7 4 2 3 5 3])]; 
                % sources until 114 (incl.)
        writesrcstr = [writesrcstr sourcestr([2 3 4 5 6 7 8])];
        writesrcstr = char(writesrcstr');

        % destination header line
        writedeststr = deststr([1 3 3 4 4 2 2 2 2 3 3 4 3 3 3 3 4 4 4 ...
            2 2 3 3 2 2 3 3 9 2 2 2 2 9 9 3 3 3 3 9 4 4 4 4 3 3 5 5 6 ...
            6 5 5 6 6 4 4 4 5 5 5 5 3 3 4 4 5 6 6 6 6 4 5 9 9 9 2 3 4 ...
            5 6 7 8]); % destinations until 80 (inclusive)
        writedeststr = [writedeststr deststr([7 7 7 7 7 7 7 7 4 4 8 8 ...
            8 8 8 8 8 8 4 4 2 3 5 2 3 5 9 9 9 9 9 9 9 9])]; 
                % dests until 114 (incl.)
        writedeststr = [writedeststr deststr([2 3 4 5 6 7 8])];
        writedeststr = char(writedeststr');

        % proccesses header line
        writeprocstr = procstr([1 2 3 4 5 6 7 8 9 6 10 4 5 6 8 9 6 10 6 ...
            7 6 8 9 8 9 6 10 6 10 11 12 13 14 15 11 20 12 13 14 15 11 ...
            12 13 14 15 4 5 8 9 8 9 6 10 6 10 6 7 6 8 8 6 10 4 5 6 7 17 ...
            8 9 6 10 6 17 11 11 18 19 19 19 19 19 19 19]); 
                % procs until 80 (inclusive)

        writeprocstr = [writeprocstr procstr([6 9 10 8 6 9 10 8 6 6 6 9 ...
            10 8 6 9 10 8 6 6 5 5 5 5 5 5 11 11 20 21 21 21 21 22])]; 
                % dests until 114 (incl.)
        writeprocstr = [writeprocstr procstr([16 16 16 16 16 16 16])];
        writeprocstr = char(writeprocstr');

        % files 4 initial mass.fluxes
        name = [outPath 'Massfluxes.j=' num2str(fluxInTab(k)) '_' ...
            deblank(char(nameSub(subs,:))) '(' runCode ').xls'];
        fileID = fopen(name, 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file %s', name);
        end
        fprintf(fileID, 'Substance: %s  n = %i ',char(nameSub(subs,:)), n);
        fprintf(fileID, ' nyears = %i  nseasons = %i  emseason = %i\n', ...
            nyears, nseasons, 1);
        fprintf(fileID, 'Initial massfluxes for zone %i in kg/d; ', ...
            fluxInTab(k));
        fprintf(fileID, 'ATTENTION: LEAFFALL at the end of season is ');
        fprintf(fileID, 'treated in file leaffall.massflux.xls! \n\t\t\t');

        for i = 1 : nFluxes+7       % this is the total number of fluxes
            fprintf(fileID, '%d \t',i);
        end
        fprintf(fileID, '\n \t \t');

        for i = 1 : max(size(writesrcstr))
            fprintf(fileID, '%s \t', writesrcstr(i,:));
        end
        fprintf(fileID, '\n \t \t');
        for i = 1 : max(size(writedeststr))
            fprintf(fileID, '%s \t', writedeststr(i,:));
        end
        fprintf(fileID, '\n');
        for i = 1 : max(size(writeprocstr))
            fprintf(fileID, '%s \t', writeprocstr(i,:));
        end
        fprintf(fileID, '\n');
        %%% the lines below do not work somehow.... why???
        % --> must be because they are commented...
        % fprintf(fileID, '%s \t', writesrcstr'); fprintf(fileID, '\n');
        % fprintf(fileID, '%s \t', writedeststr'); fprintf(fileID, '\n');
        % fprintf(fileID, '%s \t', writeprocstr'); fprintf(fileID, '\n');

        fluxFileIDs(1,k,subs) = fileID;
        %
        % files 4 t-integrated mass.fluxes
        name = [outPath 'IntMassfluxes.j=' num2str(fluxInTab(k)) '_' ...
            deblank(char(nameSub(subs,:))) '(' runCode ').xls'];
        fileID = fopen(name, 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file %s', name);
        end
        fprintf(fileID, 'Substance: %s  n = %i ',char(nameSub(subs,:)), n);
        fprintf(fileID, ' nyears = %i  nseasons = %i  emseason = %i\n', ...
            nyears, nseasons, 1);
        fprintf(fileID, 't-integrated massfluxes for zone %i in kg/d; ',...
            fluxInTab(k));
        fprintf(fileID, 'ATTENTION: LEAFFALL at the end of season is ');
        fprintf(fileID, 'treated in file leaffall.massflux.xls! \n\t\t\t');
        
        
        for i = 1 : nFluxes+7       % this is the total number of fluxes
            fprintf(fileID, '%d \t',i);
        end
        fprintf(fileID, '\n \t \t');

        for i = 1 : max(size(writesrcstr))
            fprintf(fileID, '%s \t', writesrcstr(i,:));
        end
        fprintf(fileID, '\n \t \t');
        for i = 1 : max(size(writedeststr))
            fprintf(fileID, '%s \t', writedeststr(i,:));
        end
        fprintf(fileID, '\n');
        for i = 1 : max(size(writeprocstr))
            fprintf(fileID, '%s \t', writeprocstr(i,:));
        end
        fprintf(fileID, '\n');
        fluxFileIDs(2,k,subs) = fileID;
        %
        % files 4 DieReise.fluxes
        name = [outPath 'DieReise.zone=' num2str(fluxInTab(k)) '_' ...
            deblank(char(nameSub(subs,:))) '(' runCode ').xls'];
        fileID = fopen(name, 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file %s', name);
        end
        fprintf(fileID, 'Substance: %s  n = %i ',char(nameSub(subs,:)), n);
        fprintf(fileID, ' nyears = %i  nseasons = %i  emseason = %i\n', ...
            nyears, nseasons, 1);
        fprintf(fileID, 'Summarised t-Integrated Mass fluxes (DIE_REISE)');
        fprintf(fileID, 'for zone %i in kg \n',fluxInTab(k));
        fprintf(fileID, 'Negative Fluxes are losses\n');
        fprintf(fileID, 'Year \tSeason \tlistind \tm.BS \tm.SEA \tm.AIR');
        fprintf(fileID, '\tm.VS \tm.VEG \tm.Ice \tm.Snow \texp.add.BS ');
        fprintf(fileID, '\texp.add.SEA \texp.add.AIR \texp.add.VS \t');
        fprintf(fileID, 'exp.add.VEG \texp.add.Ice \texp.add.Snow \t');
        fprintf(fileID, 'deg.BS \tdeg.Sea \tdep.Sea \tdeg.Air \tdeg.VS ');
        fprintf(fileID, '\tdeg.VEG \tdeg.Ice \tdep.Ice \tdeg.Snow \t');
        fprintf(fileID, 'deg.photo.AIR \tdeg.photoBS \tdeg.photo.SEA \t');
        fprintf(fileID, 'deg.photoVS \tdeepwatform \tSA.net \tSW.net \t');
        fprintf(fileID, 'S.net \tNA.net \tNW.net \tN.net \tS+N.totIN \t');
        fprintf(fileID, 'S+N.totOUT \tnetFlow \tDeg.tot \tDepl.tot \t');
        fprintf(fileID, 'AccInZone\n');

        fluxFileIDs(3,k,subs) = fileID;

    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readalps
% READALPS reads the model parameters for the Alps
% xxx the alpine module has not been finalized/tested and should not be
% used without considerable care! xxx

global nAlps dTAlps vrainAlps vrain MIF screMsg screCal inPath;

if screMsg
    disp(' ');
    disp('function readalps: read alpine model parameter');
end
if exist([inPath 'Alpsdata.txt'],'file') == 2
    fileID = fopen([inPath 'Alpsdata.txt'], 'rt');
else
    fileID = fopen([MIF 'Alpsdata.txt'], 'rt');
end
if fileID ~= -1
    nAlps = fscanf(fileID, '%f', 1); 
        % relative position of alpine zone: nAlps*n
    dTAlps = fscanf(fileID, '%f', 1);
    vrainAlps = fscanf(fileID, '%f', 1);
else
    diary off;
    fclose all;    
    error('Cannot open file Alpsdata.txt');
end
if screCal
    disp2('nAlps:', nAlps, ' dTAlps:', dTAlps, ' vrainAlps:', ...
        vrainAlps, ' vrain (global mean):', vrain);
end
fclose(fileID);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readalps2
% READALPS2 reads additional model parameters for the Alps
% This inputfile is for the new, separated alpine zone ('GZ') within a 
% normal climatic zone. It contains the following data:
% - # of regional alpine zones
% - location of alpine zone(s): fraction of n (in analogy to nAlps in
% readAlps)
%
% and then, for each alpine zone: (from bigger to smaller)
% - size of GZ (length and width) (to be compared with 'breiten' of 
%   motherzone) in [m]
% - dT compared to normal course in motherzone
% - prec.rate in that GZ
% - surface fractions BS, Sea, GrasVS, ConVS, DecVS (no water in GZs?)
% xxx the alpine module has not been finalized/tested and should not be
% used without considerable care! xxx

global nGZ AlpsDat MIF nAlps screMsg inPath;

if nGZ == 0 && nAlps == 0       % if there are no alpine zones...
    if screMsg
        disp('function readalps2: no Alpine region(s) in this calc');
    end
else                            % read parameters of alpine regions/zones
    if screMsg
        disp(' ');
        disp('function readalps2: read additional alpine model parameter');
    end
    if exist([inPath 'Alpsdata2.txt'],'file') == 2
        fileID = fopen([inPath 'Alpsdata2.txt'], 'rt');
    else
        fileID = fopen([MIF 'Alpsdata2.txt'], 'rt');
    end
    if fileID ~= -1
        if screMsg
            disp('function readalps2: special Alpine region(s) included');
        end
        numDat = 9; % read 9 values
        AlpsDat = zeros(nGZ, numDat);
        for i = 1:nGZ
            % read data for each GZ
            for j = 1:numDat
                AlpsDat(i,j) = fscanf(fileID, '%f ',1);
            end

            % AlpsDat(i,1:numDat) = fscanf(fileID, '%f ', numDat);
            if abs(sum(AlpsDat(i,5:9))-1)>eps
                diary off;
                fclose all;                
                error('readalps2: surface fraction for GZ %d don''t sum up to 1 but %f',i,sum(AlpsDat(i,5:9)));
            end
        end

        if screMsg
            disp2('number of alpine regions:',nGZ,...
                ' relative location of motherzone:',nAlps);
            disp2(numDat,'parameter for the',nGZ,'alpine regions:');
            disp('(length x width, dT, prec.rate, surface fractions(BS, Sea, Gras, Con, Dec))');
            disp(AlpsDat);
        end
        fclose(fileID);
    else
        diary off;
        fclose all;        
        error('Cannot open file readalps2.txt');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readsnowpar
% READSNOWPAR reads the fraction of old snow from a file
% (snowparameters_indi.txt) and calculates rho_S and ssa_S for 12 seasons

global screMsg inPath MIF rho_S ssa_S;
global ssa_newS ssa_oldS rho_oldS rho_newS snowseasons;

if screMsg
    disp(' ');
    disp('function readsnowpar: reads & averages snow model parameters');
end

% reading fraction of old snow (for snowseasons)
if exist([inPath 'snowparameters_indi.txt'],'file') == 2
    fileID = fopen([inPath 'snowparameters_indi.txt'], 'rt');
else
    fileID = fopen([MIF 'snowparameters_indi.txt'], 'rt');
end
if fileID ~= -1
    % the number of seasons in the file are compared to snowseasons
    fileseasons = fscanf(fileID,'%d',1);
    if fileseasons ~= snowseasons
        diary off;
        fclose all;        
        error('readsnowpar: number of seasons in snowparameters_indi.txt ~= 12');
    end
    snowparameters_indi = fscanf (fileID, '%f', snowseasons);
    fclose(fileID);
else
    diary off;
    fclose all;    
    error('Cannot open file snowparameters_indi.txt');
end

frac_oldsnow      = snowparameters_indi(1:snowseasons);

% calculates the total snow density and totals SSA (spec. surf. area) for
% each season
rho_S = zeros(1,snowseasons);
for k = 1 : snowseasons
    rho_S(1,k) = frac_oldsnow(k)*rho_oldS + (1-frac_oldsnow(k))*rho_newS;
end

ssa_S = zeros(1,snowseasons);
for k = 1 : snowseasons
    ssa_S(1,k) = frac_oldsnow(k)*ssa_oldS + (1-frac_oldsnow(k))*ssa_newS;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makesnowpartab
% MAKESNOWPARTAB calculates (some) and averages snow parameters to
% nseasons, and to n (zones) and writes them into snowpartabweighted.
% snowpartabweighted(n,6,nseasons) has the six snow parameters rho_S,
% ssa_S, fom_S, fw_S, fa_S, & frf_S. frf_S will actually not be used in the
% program...

global screMsg screCal snowparTabweighted tmp_0 rhoW_268 nseasons;
global iceandsnow rho_S ssa_S foc_S frf_S n breiten runCode snowseasons;
global equabelt seas_snowonlyNord seas_snowonlyEquabelt;
global seas_snowonlySued seas_surftype outPath OPsnoice;

if screMsg
    disp(' ');
    disp('function makesnowpartab: reads & averages snow parameters');
end

% tmp_0 is an matrix of 12*360 cells containing temperature in °C.
% Here, the zonal averaging of this variable is done. the resulting
% variable is called tmp_180
tmp_180 = zeros(12,180);
for i = 1 : 12
    for k = 1 : 180
        temp = 0;
        for m = (k-1)*2 +1 : k*2
            temp = temp + tmp_0(i,m);
        end
        tmp_180(i,k) = temp/2;
    end
end
tmp_180 = (tmp_180 + 273.15)';

% fw_S (fraction of wet snow) is calculated / averaged  here, depending on
% the temperature of the corresponding zone
fw_S = zeros(180,snowseasons);
for k = 1 : snowseasons
    for i = 1 : 180
        if tmp_180(i, k)  >= 273.15
            fw_S(i,k) = 0.1;
        elseif tmp_180(i, k) <= 248.15
            fw_S(i, k) = 0.0001;
        else
            fw_S(i, k) = 0.1 - (273.15 - tmp_180(i, k)) * ...
                ((0.1-0.0001)/(273.15 - 248.15));    
                    % between 273.15 K and 248.15 K fracwsnow decreases 
                    % linearly from 0.1 to 0.0001
        end
    end
end

% fw_S is averaged here from snowseasons to nseasons
seas_fw_S = zeros(180,nseasons);
for i = 1 : 180
    for k = 1 : nseasons
        temp = 0;
        for m = (k-1)*12/nseasons+1 : k*12/nseasons
            temp = temp + fw_S(i,m);
        end
        seas_fw_S(i,k) = temp/(12/nseasons);
    end
end

% the porosity is calculated here for 180° * snwoseasons
porosity_S = zeros(180,snowseasons);
for i = 1 : 90
    for k = 1 : snowseasons
        porosity_S(i, k) = (rhoW_268 - rho_S(1, k))/rhoW_268;
    end
end
for i = 91 : 180
    for k = 1 : snowseasons/2
        porosity_S(i, k) = (rhoW_268 - rho_S(1, k+6))/rhoW_268;
    end
end
for i = 91 : 180
    for k = snowseasons/2+1 : snowseasons
        porosity_S(i, k) = (rhoW_268 - rho_S(1,k-6))/rhoW_268;
    end
end

% fa_S (fraction of air in snow) is calculated base on porosity and fw_S
fa_S = porosity_S - fw_S;

% seas_fa_S is averaged to 180° * nseasons
seas_fa_S = zeros(180,nseasons);
for i = 1 : 180
    for k = 1 : nseasons
        temp = 0;
        for m = (k-1)*12/nseasons+1 : k*12/nseasons
            temp = temp + fa_S(i,m);
        end
        seas_fa_S(i,k) = temp/(12/nseasons);
    end
end


% rho_S, ssa_S, frf_S and foc_S are written into snowtype_parameter.
% snowtype_parameter is the snow parameters for the different snow types
% (over bare soil, over coni-forest...). currently, all snowtypes have the
% same parameter settings...
% snowtype_parameter is later on used to calculate the bulk-zonal specific
% snow properties (snowparTabweighted)

snowtype_parameter = zeros(5,4,snowseasons);
seas_snowtype_parameter = zeros(5,4,nseasons);
for k = 1 : snowseasons
    for i = 1 : 5       % 5 different snowtypes
        snowtype_parameter(i,:,k) = [rho_S(1,k) ssa_S(1,k) frf_S foc_S];
        % frf_S will never be used
        % for all snowtypes, the parameters are the same now!!!
    end
end

% here, snowtype_parameter is averaged to nseasons
for i = 1 : 5
    for j = 1 : 4
        for k = 1 : nseasons
            temp = 0;
            for m = (k-1)*snowseasons/nseasons +1 : k*snowseasons/nseasons
                temp = temp + snowtype_parameter(i,j,m);
            end
            seas_snowtype_parameter(i,j,k) = temp/(12/nseasons);
        end
    end
end

% snowparTabweighted is calculated in the next paragraph. this is the
% matrix that contains bulk-zonal specific snow parameters, averaged over
% nseasons...

snowparTabweighted = zeros(n,6,nseasons);
if iceandsnow
    season = 1;
    for k = 1 : nseasons
        % here, the seasonal snow-type distribution is multiplied
        % with the properties of the snowtypes, resulting in a zonal /
        % seasonal snowparameter distribution

        % first, the parameter table is multiplied with the snow-type table
        bulk_snowparameter_Nord = seas_snowonlyNord(:, :, season) * ...
            seas_snowtype_parameter(:,:,season);
        bulk_snowparameter_Equabelt = ...
            seas_snowonlyEquabelt(:, :, season) * ...
            seas_snowtype_parameter(:,:,season);
        bulk_snowparameter_Sued = seas_snowonlySued(:, :, season) * ...
            seas_snowtype_parameter(:,:,mod(season+1,nseasons)+1);

        if equabelt ~= 0
            bulk_snowparameter_0 = [bulk_snowparameter_Nord; ...
                bulk_snowparameter_Equabelt; bulk_snowparameter_Sued];
            for i = 1 : 180
                if sum(bulk_snowparameter_0(i,:),2) == 0
                    seas_fw_S(i, season) = 0;
                    seas_fa_S(i, season) = 0;
                end
            end
        else
            bulk_snowparameter_0 = [bulk_snowparameter_Nord; ...
                bulk_snowparameter_Sued];
            for i = 1 : 180
                if sum(bulk_snowparameter_0(i,:),2) == 0
                    seas_fw_S(i, season) = 0;
                    seas_fa_S(i, season) = 0;
                end
            end
        end

        % two more parameters (not zonally dependent) are added to the
        % bulk_snowparameter matrix
        % bulk_snowparameter: rho_S, ssa_S, frf_S, foc_S, fw_S, fa_S
        bulk_snowparameter = [bulk_snowparameter_0 seas_fw_S(:,season) ...
            seas_fa_S(:,season)];

        if sum(bulk_snowparameter(5:7)) > 1
            warning('warning: sum  of volume fractions bigger than one');
            keyboard;
        end
        if screCal && iceandsnow
            disp('snow parameters for each latitudinal degree: (180 x 6)');
            disp(bulk_snowparameter);
        end

        % the averaging from 180° to n zones is done
        zonal_bulk_snowparameter = zeros(n, size(bulk_snowparameter,2));
        for i = 1:n
            zonal_snowfrac = 0;
            for m = (i-1)*180/n+1 : i*180/n
                zonal_bulk_snowparameter(i,:) = ...
                    zonal_bulk_snowparameter(i,:) + ...
                    bulk_snowparameter(m,:)*breiten(m)*...
                    sum(seas_surftype(m,7:11,season));
                zonal_snowfrac = zonal_snowfrac + breiten(m)*...
                    sum(seas_surftype(m,7:11,season));
            end
            if zonal_snowfrac == 0
                zonal_bulk_snowparameter(i,:) = 0;
            else
                zonal_bulk_snowparameter(i,:) = ...
                    zonal_bulk_snowparameter(i,:)/zonal_snowfrac;
            end
        end

        snowparTabweighted(:,:,season) = zonal_bulk_snowparameter;
        season = mod(season, nseasons)+1; 
            % increase season in the cycle ... -> 1 -> 2 -> 3 -> 4 -> 1 ...
    end
else
    snowparTabweighted = zeros(n,6,nseasons);
end

% ice and snow parameters are printed into output file
if iceandsnow && OPsnoice
    fileID = fopen([outPath 'AveragedSnowPara(' runCode ').xls'], 'wt');
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file AveragedSnowPara.xls');
    else
        fprintf(fileID, 'Averaged Snow Parameters');
        fprintf(fileID, '\nSeason \tBoxNo \trho_S \tssa_S \tfrf_S ');
        fprintf(fileID, '\tfoc_S \tfw_S \tfa_S \n[-] \t[-] \t');
        fprintf(fileID, '[kg/m3] \t[m2/kg] \t[-] \t[-] \t[-] \t[-] \n');
        for k = 1 : nseasons
            for i = 1 : n
                fprintf(fileID, '%d \t%d \t',k,i);    % write box no
                for j = 1:size(snowparTabweighted,2)  % loop over snowpars
                    fprintf(fileID, '%1.3g \t', snowparTabweighted(i,j,k));
                end
                fprintf(fileID, '\n');
            end
        end
        fclose(fileID);
    end
end

if screMsg &&  iceandsnow == false
    disp(' ');
    disp('makesnowpartab: no snow in climochem.');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readsnowdepths
% READSNOWHEIGHTS reads the seasonal varying snow depths from file &
% averages to n (zones) and nseasons

global screMsg inPath n breiten outPath runCode MIF OPsnoice;
global iceandsnow snowseasons nseasons seas_zonal_snowheight;

if screMsg
    disp(' ');
    disp('function readsnowdepths: reads seasonal snow depths');
end

breiten_allmonth = [breiten breiten breiten breiten breiten breiten ...
    breiten breiten breiten breiten breiten breiten]';

if iceandsnow
    % latitudinal snow heights are read from file
    if exist([inPath 'av_lat_snowheight.txt'],'file') == 2
        fileID = fopen([inPath 'av_lat_snowheight.txt'], 'rt');
    else
        fileID = fopen([MIF 'av_lat_snowheight.txt'], 'rt');
    end
    if fileID ~= -1
        snowheight = fscanf (fileID, '%f', 2160);
    else
        diary off;
        fclose all;        
        error('Cannot open file av_lat_snowheight.txt');
    end
    fclose(fileID);

    if length(snowheight) == 2160 && screMsg
        disp('all 2160 data point are read');
    end

    % the averaging to n (zones) is done here
    zonal_snowheight = zeros(snowseasons*n,1);
    for i = 1 : snowseasons*n
        temp = 0;
        for z = (i-1)*180/n+1 : i*180/n
            temp = temp + snowheight(z,1) * breiten_allmonth(z);
        end
        zonal_snowheight(i,1) = temp/sum(breiten_allmonth...
            ((i-1)*180/n+1 : i*180/n));
    end

    % the averaging to nseasons is done here
    seaszonalsnowheight = zeros(n * nseasons, 1);
    for i = 1 : n
        for k = 1 : nseasons
            temp = 0;
            for z = (k-1)*snowseasons/nseasons + 1 : (k*snowseasons)...
                    /nseasons
                for w = (k - 1)*n + i
                    for v = (z-1)*n + i
                        temp = temp + zonal_snowheight(v,1);
                    end
                end
            end
            seaszonalsnowheight(w,1) = temp/(snowseasons/nseasons);
        end
    end

    % this is just a reshaping, could be made directly...
    seas_zonal_snowheight = zeros(n,nseasons);
    for k = 1 : nseasons
        seas_zonal_snowheight(:,k) = seaszonalsnowheight((k-1)*n+1 : k*n);
    end

    if OPsnoice
        fileID = fopen([outPath 'zonal_seasonal_snowheight('...
            runCode ').xls'], 'wt');
        if fileID ~= -1
            fprintf(fileID,'Zonal/seasonal snow height in m \n Zone \t');
            for j=1:nseasons
                fprintf(fileID,'Season %d \t',j);
            end
            for i=1:n
                fprintf(fileID,'\n%d \t',i);
                for j=1:nseasons
                    fprintf(fileID,'%1.3g \t',seas_zonal_snowheight(i,j));
                end
            end
            fclose(fileID);
        else
            diary off;
            fclose all;            
            error('Cant open file zonal_seasonal_snowheight.xls');
        end
    end
else
    seas_zonal_snowheight = zeros(n,nseasons);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readaerosolpar
% Readaerosolpar reads parameter for the advanced aerosol module, such as
% OC concentration, BC concentration, Mineral Dust concentration, Sea salt
% concentration, relative humidity
% Maps are read in as 180 x 12 (lat. mean x month) matrizes
% Files have the unit kg/m2, which means the burden over the whole air
% column. Depending on the atmospheric height, the concentration and the
% surface concentration are calculated

global AeroMod screMsg inPath MIF;
global OCburden BCburden DUburden SEAburden SO4burden RelHum

if AeroMod

    OCburden  = zeros(180,12);
    BCburden  = zeros(180,12);
    DUburden  = zeros(180,12);
    SEAburden = zeros(180,12);
    SO4burden = zeros(180,12);

    if screMsg
        disp('');
        disp('function readaerosolpar: reads aerosol module parameters');
    end

    % Read Aerosol related input prameters
    if exist([inPath 'OCkgm2.txt'],'file') == 2
        fileID = fopen([inPath 'OCkgm2.txt'], 'rt');
    else
        fileID = fopen([MIF 'OCkgm2.txt'], 'rt');
    end
    if fileID ~= -1
        OCburden = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

    if exist([inPath 'BCkgm2.txt'],'file') == 2
        fileID = fopen([inPath 'BCkgm2.txt'], 'rt');
    else
        fileID = fopen([MIF 'BCkgm2.txt'], 'rt');
    end
    if fileID ~= -1
        BCburden = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

    if exist([inPath 'DUkgm2.txt'],'file') == 2
        fileID = fopen([inPath 'DUkgm2.txt'], 'rt');
    else
        fileID = fopen([MIF 'DUkgm2.txt'], 'rt');
    end
    if fileID ~= -1
        DUburden = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

    if exist([inPath 'SEAkgm2.txt'],'file') == 2
        fileID = fopen([inPath 'SEAkgm2.txt'], 'rt');
    else
        fileID = fopen([MIF 'SEAkgm2.txt'], 'rt');
    end
    if fileID ~= -1
        SEAburden = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

    if exist([inPath 'SO4kgm2.txt'],'file') == 2
        fileID = fopen([inPath 'SO4kgm2.txt'], 'rt');
    else
        fileID = fopen([MIF 'SO4kgm2.txt'], 'rt');
    end
    if fileID ~= -1
        SO4burden = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

    if exist([inPath 'RelHum.txt'],'file') == 2
        fileID = fopen([inPath 'RelHum.txt'], 'rt');
    else
        fileID = fopen([MIF 'RelHum.txt'], 'rt');
    end
    if fileID ~= -1
        RelHum = fscanf(fileID, '%f',[180 12]);
    end
    fclose(fileID);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeaerosolpar
% Calculate surface / bulk phase concentrations for the advanced aerosol
% module. Parameter depend on the atmospheric height;
% Average monthly resolution into 4 seasons

global AeroMod screMsg;
global n nseasons;
global OCburden BCburden DUburden SEAburden SO4burden RelHum;
global AerosolParameter AerosolParameterMonthlyR AerosolParameterMonthlyRZ;
global AerosolParameterMonthly;

if AeroMod

    if screMsg
        disp('');
        disp('function makeaerosolpar: creates aerosol parameters');
    end

    % Calculate kg / m3 for a given atmospheric height

    height = 1000; % Height of the atmosphere compartment

    BCconcentration  = BCburden  ./ height; % kg / m3
    OCconcentration  = OCburden  ./ height; % kg / m3
    DUconcentration  = DUburden  ./ height; % kg / m3
    SEAconcentration = SEAburden ./ height; % kg / m3
    SO4concentration = SO4burden ./ height; % kg / m3
    TSPKgM3 =            BCconcentration +      OCconcentration +     ...
        DUconcentration +      SEAconcentration +     SO4concentration;
    TSPKgM3fine   = 0.66*BCconcentration + 0.85*OCconcentration + ...
        0.2*DUconcentration + 0.14*SEAconcentration + 0.9*SO4concentration;
            % percentages based on Puteaud et al
    TSPKgM3coarse = 0.33*BCconcentration + 0.15*OCconcentration + ...
        0.8*DUconcentration + 0.86*SEAconcentration + 0.1*SO4concentration;
            % percentages based on Puteaud et al


    % Calculate bulk phase and surface concentrations out of the kg/m2
    % burdens and merge in an AerosolParameter 3D matrix

    % Calculation of volume -> surface
    radius = 5*10^-6 ; 
        % coarse particles have about 5 um radius (10 um diameter), (m)
    Surf = (4*3.14159) * radius^2;   % Surface of one 5um particle, (m2)
    Vol  = (4*3.14159/3) * radius^3; % Volume of one 5um particle, (m3)
    f = Surf/Vol;  % Volume to Surface convertion factor, (1/m)

    DenBC  = 2   / 0.000001; % Density of BC, (g/m3)
    DenDU  = 2.5 / 0.000001; % Density of DU, (g/m3)
    DenSEA = 1.1 / 0.000001; % Density of SEA,(g/m3)
    DenSO4 = 1.0 / 0.000001; % Density of SO4,(g/m3)

    % AerosolParameter 3D Matrix:
    % AerosolParameter(n,m,1) : OM Fine fraction   (g/m3)
    % AerosolParameter(n,m,2) : OM Coarse fraction (g/m3)
    % AerosolParameter(n,m,3) : EC Coarse fraction (m2/m3)
    % AerosolParameter(n,m,4) : seasalt Coarse fraction (m2/m3)
    % AerosolParameter(n,m,5) : silica Coarse fraction (m2/m3)
    % AerosolParameter(n,m,6) : SO4 Fine fraction (m2/m3)
    % AerosolParameter(n,m,7) : TSP Fine fraction (g/m3)
    % AerosolParameter(n,m,8) : TSP Coarse fraction (g/m3)
    % AerosolParameter(n,m,9) : OM fraction of total aerosol with the
    % assumption of complete availability
    % AerosolParameter(n,m,10) : Relative Humidity

    AerosolParameterMonthly(:,:,1) = 0.85 .* OCconcentration  .* ...
        1000; % g / m3 finef
    AerosolParameterMonthly(:,:,2) = 0.15 .* OCconcentration  .* ...
        1000; % g / m3 coarsef
    AerosolParameterMonthly(:,:,3) = 0.33 .* BCconcentration  .* ...
        1000.*f./DenBC ; % m2 / m3 coarsef
    AerosolParameterMonthly(:,:,4) = 0.86 .* SEAconcentration .* ...
        1000.*f./DenDU ; % m2 / m3 coarsef
    AerosolParameterMonthly(:,:,5) = 0.80 .* DUconcentration  .* ...
        1000.*f./DenSEA; % m2 / m3 coarsef
    AerosolParameterMonthly(:,:,6) = 0.90 .* SO4concentration .* ...
        1000.*f./DenSO4; % m2 / m3 finef
    AerosolParameterMonthly(:,:,7) =         TSPKgM3fine      .* ...
        1000; % g / m3 finef
    AerosolParameterMonthly(:,:,8) =         TSPKgM3coarse    .* ...
        1000; % g / m3 coarsef
    AerosolParameterMonthly(:,:,9) =         OCconcentration./...
        TSPKgM3; % g / m3 general
    AerosolParameterMonthly(:,:,10)=         RelHum         ; % unitless

    % Reshape AerosolparameterMonthly and average monthly resolution into
    % nseasons and n zones
    AerosolParameterMonthlyR  = zeros(12,180,10);
    AerosolParameterMonthlyRZ = zeros(12,n  ,10);
    AerosolParameter          = zeros(nseasons,n,10);

    for i = 1:12
        AerosolParameterMonthlyR(i,:,:) = AerosolParameterMonthly(:,i,:);
    end

    for i = 1:n
        AerosolParameterMonthlyRZ(:,i,:) = mean(AerosolParameterMonthlyR...
            (:,i:(i*180/n),:),2);
    end

    for j = 1:nseasons
        AerosolParameter(j,:,:) = mean(AerosolParameterMonthlyRZ...
            (j:(j*12/nseasons),:,:),1);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeaerosolppLFER
% Calculate gas-particle partitioning based on AerosolParameter (Aerosol
% bulk phase and surface concentrations, relative humidity) and ppLFER

global AerosolParameter AeroMod screMsg t0 tmp tdry
global nseasons n nsubs dUow alpha beta logKha Vx
global Kom Kec Kseasalt Ksilica KSO4 KpTotal KpFine KpCoarse
global phiTotal phiFine phiCoarse

maketdry; % reads tdry values

if AeroMod

    if screMsg
        disp('');
        disp('function makeaerosolppLFER: Calculate Kp and phi');
    end

    % initialise parameter matrices
    logKomRef      = zeros(nseasons, n, nsubs);
    logKecRef      = zeros(nseasons, n, nsubs);
    logKseasaltRef = zeros(nseasons, n, nsubs);
    logKsilicaRef  = zeros(nseasons, n, nsubs);
    logKSO4Ref     = zeros(nseasons, n, nsubs);
    Kom            = zeros(nseasons, n, nsubs);
    Kec            = zeros(nseasons, n, nsubs);
    Kseasalt       = zeros(nseasons, n, nsubs);
    Ksilica        = zeros(nseasons, n, nsubs);
    KSO4           = zeros(nseasons, n, nsubs);
    KpTotal        = zeros(nseasons, n, nsubs);
    KpFine         = zeros(nseasons, n, nsubs);
    KpCoarse       = zeros(nseasons, n, nsubs);
    phiTotal       = zeros(nseasons, n, nsubs);
    phiFine        = zeros(nseasons, n, nsubs);
    phiCoarse      = zeros(nseasons, n, nsubs);
    logKecRefDry   = zeros(nseasons, n, nsubs);
    logKseasaltRefDry = zeros(nseasons, n, nsubs);
    logKsilicaRefDry  = zeros(nseasons, n, nsubs);
    logKSO4RefDry  = zeros(nseasons, n, nsubs);
    logKecRefWet   = zeros(nseasons, n, nsubs);
    deltaHEC       = zeros(nseasons, n, nsubs);
    deltaHsea      = zeros(nseasons, n, nsubs);
    deltaHSiO2     = zeros(nseasons, n, nsubs);
    deltaHSO4      = zeros(nseasons, n, nsubs);
    logKseasaltRefWet = zeros(nseasons, n, nsubs);
    logKsilicaRefWet  = zeros(nseasons, n, nsubs);
    logKSO4RefWet     = zeros(nseasons, n, nsubs);
    tRef           = zeros(nseasons, n);

    % Definition of Reference temperature
    tRef(:,:) = t0;

    % Definition of universal gas constant
    R = 8.314; % J/molK

    % Definition of Aerosol Bulk Phase Parameters
    % Data from Goetz et al. 2007, ES&T
    % Data for urban aerosols / OC
    abulKom      =   1.20 ;
    bbulKom      =   0.77 ;
    cbulKom      =   2.36 ;
    dbulKom      =  -1.14 ;
    constbulKom  =  -6.26 ;

    % Definition of Aerosol Surface Parameters
    % Data from Goetz et al. 2007, ES&T
    % Elemental Carbon
    SqrGammaIntEC = 11.496;
    SqrGammaSlpEC = -0.0682;
    EAsurfIntEC   =  0.48;
    EAsurfSlpEC   =  0;
    EDsurfIntEC   =  0.75;
    EDsurfSlpEC   =  0;
    % Seasalt
    SqrGammaIntSeasalt =  7.114;
    SqrGammaSlpSeasalt = -0.0222;
    EAsurfIntSeasalt   =  0.88;
    EAsurfSlpSeasalt   = -0.0017;
    EDsurfIntSeasalt   =  0.94;
    EDsurfSlpSeasalt   =  0;
    % SiO2
    SqrGammaIntSilica =  8.543;
    SqrGammaSlpSilica = -0.0372;
    EAsurfIntSilica   =  1.27;
    EAsurfSlpSilica   = -0.0046;
    EDsurfIntSilica   =  0.88;
    EDsurfSlpSilica   =  0;
    % SO4
    SqrGammaIntSO4 =  7.459;
    SqrGammaSlpSO4 = -0.0251;
    EAsurfIntSO4   =  0.73;
    EAsurfSlpSO4   = -0.0022;
    EDsurfIntSO4   =  1.02;
    EDsurfSlpSO4   =  0;
    % Equation constants for surface polyparameter LFER
    a = 0.136 ;
    b = 5.31  ;
    c = 3.67  ;
    d = -8.47 ;




    for subs = 1 : nsubs


        % Calculation of Partitioning coefficients (logK's of reference
        % temperature) for RH-INDEPENDENT om-absorption
        logKomRef(:,:,subs)      = abulKom  * logKha(subs) + bbulKom  *...
            beta(subs)  +  cbulKom  * alpha(subs) + dbulKom * Vx(subs)...
            + constbulKom ;  % m3/gOC

        % Calculation of Partitioning coefficients (logK's of reference
        % temperature) for DRY period
        RH = AerosolParameter(:,:,10)*100; % relative humidity in %!!!! 
                % ACHTUNG x 100 rechnen!!!!
        logKecRefDry(:,:,subs)      = ...
            a * (SqrGammaIntEC + SqrGammaSlpEC * RH)* logKha(subs) + ...
            b * (EAsurfIntEC + EAsurfSlpEC * RH) * beta(subs)  +  ...
            c * (EDsurfIntEC + EDsurfSlpEC * RH) * alpha(subs) + d; % m3/m2
        logKseasaltRefDry(:,:,subs) = ...
            a*(SqrGammaIntSeasalt+SqrGammaSlpSeasalt*RH)*logKha(subs)+...
            b*(EAsurfIntSeasalt+EAsurfSlpSeasalt*RH)*beta(subs)  +  ...
            c*(EDsurfIntSeasalt+EDsurfSlpSeasalt*RH)*alpha(subs)+d; % m3/m2
        logKsilicaRefDry(:,:,subs)  = ...
            a*(SqrGammaIntSilica+SqrGammaSlpSilica*RH)*logKha(subs)+...
            b*(EAsurfIntSilica+EAsurfSlpSilica*RH)*beta(subs)+...
            c*(EDsurfIntSilica+EDsurfSlpSilica*RH)*alpha(subs)+d ; % m3/m2
        logKSO4RefDry(:,:,subs)     = ...
            a*(SqrGammaIntSO4+SqrGammaSlpSO4*RH)*logKha(subs)+...
            b*(EAsurfIntSO4+EAsurfSlpSO4*RH)*beta(subs)+...
            c*(EDsurfIntSO4+EDsurfSlpSO4*RH)* alpha(subs) + d ; % m3/m2

        % Calculation of Partitioning coefficients (logK's of reference
        % temperature) for WET period
        RH = 95; % relative humidity
        logKecRefWet(:,:,subs)      = ...
            a * (SqrGammaIntEC + SqrGammaSlpEC * RH)* logKha(subs) + ...
            b * (EAsurfIntEC + EAsurfSlpEC * RH)* beta(subs)  +  ...
            c * (EDsurfIntEC + EDsurfSlpEC * RH)* alpha(subs) + d ; % m3/m2
        logKseasaltRefWet(:,:,subs) = ...
            a*(SqrGammaIntSeasalt+SqrGammaSlpSeasalt*RH)*logKha(subs)+ ...
            b*(EAsurfIntSeasalt+EAsurfSlpSeasalt*RH)*beta(subs)+...
            c*(EDsurfIntSeasalt+EDsurfSlpSeasalt*RH)*alpha(subs)+d; % m3/m2
        logKsilicaRefWet(:,:,subs)  = ...
            a*(SqrGammaIntSilica+SqrGammaSlpSilica*RH)* logKha(subs) + ...
            b*(EAsurfIntSilica+EAsurfSlpSilica*RH)*beta(subs)  +  ...
            c*(EDsurfIntSilica+EDsurfSlpSilica*RH)*alpha(subs)+d ; % m3/m2
        logKSO4RefWet(:,:,subs)     = ...
            a*(SqrGammaIntSO4 + SqrGammaSlpSO4 * RH)* logKha(subs) + ...
            b*(EAsurfIntSO4 + EAsurfSlpSO4 * RH)* beta(subs)  +  ...
            c*(EDsurfIntSO4 + EDsurfSlpSO4 * RH)* alpha(subs) + d ; % m3/m2


        % Fractions of wet and dry periods
        fwet = (31-tdry') / 31;
        fdry = tdry' / 31;

        % Calculation of Partitioning coefficients (logK's of reference
        % temperature) for both periods (weighted with duration of tdry)
        logKecRef(:,:,subs) = fdry .* logKecRefDry(:,:,subs) + fwet .*...
            logKecRefWet(:,:,subs);
        logKseasaltRef(:,:,subs) = fdry .* logKseasaltRefDry(:,:,subs) +...
            fwet .* logKseasaltRefWet(:,:,subs);
        logKsilicaRef(:,:,subs) = fdry .* logKsilicaRefDry(:,:,subs) +...
            fwet .* logKsilicaRefWet(:,:,subs);
        logKSO4Ref(:,:,subs) = fdry .* logKSO4RefDry(:,:,subs) + fwet .*...
            logKSO4RefWet(:,:,subs);

        % Calculation of "Enthalpy of adsorption" 
        % (Goss and Schwarzenbach, 1999, ES&T)
        deltaHEC(:,:,subs)   = -4.17 * log(10.^logKecRef(:,:,subs))     ...
            - 88.1; % kJ/mol
        deltaHsea(:,:,subs)  = -4.17 * log(10.^logKseasaltRef(:,:,subs))...
            - 88.1; % kJ/mol
        deltaHSiO2(:,:,subs) = -4.17 * log(10.^logKsilicaRef(:,:,subs)) ...
            - 88.1; % kJ/mol
        deltaHSO4(:,:,subs)  = -4.17 * log(10.^logKSO4Ref(:,:,subs))    ...
            - 88.1; % kJ/mol

        % Calculation of Temperature corrected logK's
        Kom(:,:,subs)      =   10.^(logKomRef(:,:,subs)     + ...
            (dUow(subs)                           /2.303/R) .* ...
            (1./tRef - 1./tmp));
        Kec(:,:,subs)      =   10.^(logKecRef(:,:,subs)     + ...
            ((deltaHEC(:,:,subs)  *1000 + R*tRef) /2.303/R) .* ...
            (1./tRef - 1./tmp));
        Kseasalt(:,:,subs) =   10.^(logKseasaltRef(:,:,subs)+ ...
            ((deltaHsea(:,:,subs) *1000 + R*tRef) /2.303/R) .* ...
            (1./tRef - 1./tmp));
        Ksilica(:,:,subs)  =   10.^(logKsilicaRef(:,:,subs) + ...
            ((deltaHSiO2(:,:,subs)*1000 + R*tRef) /2.303/R) .* ...
            (1./tRef - 1./tmp));
        KSO4(:,:,subs)     =   10.^(logKSO4Ref(:,:,subs)    + ...
            ((deltaHSO4(:,:,subs) *1000 + R*tRef) /2.303/R) .* ...
            (1./tRef - 1./tmp));

        % Calculation of Kp Total (ppLFER)
        KpTotal(:,:,subs)  = (Kom(:,:,subs) .* AerosolParameter(:,:,1) ...
            + Kom(:,:,subs) .* AerosolParameter(:,:,2) + Kec(:,:,subs) ...
            .* AerosolParameter(:,:,3) + Kseasalt(:,:,subs) .* ...
            AerosolParameter(:,:,4) + Ksilica(:,:,subs) .* ...
            AerosolParameter(:,:,5) + KSO4(:,:,subs) .* ...
            AerosolParameter(:,:,6));% (dimensionless)
        KpFine(:,:,subs)   = (Kom(:,:,subs) .* AerosolParameter(:,:,1) ...
            + KSO4(:,:,subs).* AerosolParameter(:,:,6)); % (dimensionless)
        KpCoarse(:,:,subs) = (Kom(:,:,subs) .* AerosolParameter(:,:,2) ...
            + Kec(:,:,subs) .* AerosolParameter(:,:,3) + ...
            Kseasalt(:,:,subs) .* AerosolParameter(:,:,4) + ...
            Ksilica(:,:,subs) .* AerosolParameter(:,:,5));% (dimensionless)

        % Phi
        phiTotal(:,:,subs)  = KpTotal(:,:,subs) ./(KpTotal(:,:,subs) +1);
        phiFine(:,:,subs)   = KpFine(:,:,subs)  ./(KpFine(:,:,subs)  +1);
        phiCoarse(:,:,subs) = KpCoarse(:,:,subs)./(KpCoarse(:,:,subs)+1);
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readvegpar
% READVEGPAR reads the vegetation model parameters from file
% 'VegParaSeasonal'

global vegparTab vegseasons vegpars MIF;
global screMsg screCal inPath;

if screMsg
    disp(' ');
    disp('function readvegpar: reads vegetation model parameters');
end
if exist([inPath 'VegParaSeasonal.txt'],'file') == 2
    fileID = fopen([inPath 'VegParaSeasonal.txt'], 'rt');
else
    fileID = fopen([MIF 'VegParaSeasonal.txt'], 'rt');
end
if fileID ~= -1
    vegtypes = fscanf(fileID, '%f', 1); % total number of lines in the file
    vegpars = fscanf(fileID, '%f', 1); % number of vegetation parameters
    fileseasons = fscanf(fileID, '%f', 1); % number of vegetation seasons
    if vegtypes~=floor(vegtypes) || vegpars~=floor(vegpars) ...
        || vegseasons~=floor(vegseasons)
        diary off;
        fclose all;    
        error('readvegpar: vegetation parameters must be integer');
    end
    if fileseasons ~= vegseasons
        diary off;
        fclose all;        
        error('readvegpar: vegseasons must be 12, is: %d', fileseasons);
    end
    vegparTab = zeros(vegtypes/vegseasons, vegpars, vegseasons); % 3D-Array
    for k = 1:vegseasons
        for l = 1:vegtypes/vegseasons
            for m = 1:vegpars
                vegparTab(l,m,k) = fscanf(fileID, '%f', 1);
                [message, errnum] = ferror(fileID); % Error message
                if errnum ~= 0
                    diary off;
                    fclose all;                    
                    error('readvegpar: error reading VegParaSeasonal.txt');
                end
            end
        end
    end
    fclose(fileID);
    if screCal
        disp2('Parameters read for', vegtypes/vegseasons, ...
            'vegetation types and');
        disp2(vegseasons, 'vegetation seasons:');
        disp(vegparTab);
    end
else
    diary off;
    fclose all;    
    error('Cannot open file VegParaSeasonal.txt');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makevegzonen
% MAKEEVEGZONEN3 reads and averages zonal surface types (soil, water,
% vegetation type, ice, snow(type). The output variables resulting from
% this function are:
% - surftype (180 * 12 * 12), the fraction of each surface type (1 - 12)
%   over 180° and 12 seasons
% - seas_zonal_surftype (n * 12 * nseasons), the above variable, averaged
%   over n (zones) and nseasons
% - landmix (n * 10 * nseasons), giving the proportions of the different
%   land surfaces as part of all land surfaces
% - vegeonly (n * 10 * nseasons), giving the proportions of the different
%   vegetation types as part of all vegetation types (including
%   snow-covered vegetation), used for stability vectors calculation
% - vegeonlyXXX (XXX * 10 * 12), giving the proportions of the different
%   vegetation types as part of all vegetation types (including
%   snow-covered vegetation), used for vegparTabweighted calculations
% - snowonly (n * 5 * nseasons), giving the proportions of the different
%   snow-types as part of all snow-types, used for snowmass transfer 
%   calculations
% - snowonlyXXX (XXX * 5 * 12), giving the proportions of the different
%   snow-types as part of all snow-types, used for snowparTabweighted 
%   calculations

% where XXX stands for Nord, Equabelt, or Sued...
% landmix, vegeonly, & vegeonlyXXX are independent on season, but need to
% have the season dimension, too

% The function is built up in three parts:
% A: reading input files and constructing the surftype variable
% B: extracting the other variables from surftype through averaging
% C: printing results into various output files

%%%%%%%%%
% Part A:
%%%%%%%%%
global screMsg screCal MIF inPath outPath runCode iceandsnow ice vegmod;
global OPvegvol n breiten equabelt snowseasons vegseasons seas_surftype;
global surftype seas_zonal_surftype landmix snowonly vegeonly nseasons;
global vegeonlyNord vegeonlyEquabelt vegeonlySued seas_snowonlyNord;
global seas_snowonlyEquabelt seas_snowonlySued OPsnoice OPGGWcqu;

if screMsg
    disp(' ');
    disp('function makevegzonen: creates surface type distributions');
end

% open & read the correct input file
if iceandsnow == 0 && ice == 0          % no ice, no snow => read 
                                        % only vegetation distribution file
    if exist([inPath 'VegTypesEarth.txt'],'file') == 2
        fileID = fopen([inPath 'VegTypesEarth.txt'], 'rt');
    else
        fileID = fopen([MIF 'VegTypesEarth.txt'], 'rt');
    end
    numDataPoints = 64800;
elseif iceandsnow == 0 && ice == 1      % just permanent ice => read perm-
                                        % ice surface distribution file
    if exist([inPath 'av_lat_surfractionPI.txt'],'file') == 2
        fileID = fopen([inPath 'av_lat_surfractionPI.txt'], 'rt');
    else
        fileID = fopen([MIF 'av_lat_surfractionPI.txt'], 'rt');
    end
    numDataPoints = 2340;
elseif iceandsnow == 1                  % ice & snow => read ice / snow 
                                        % surface distribution file
    if exist([inPath 'av_lat_surfraction_SSI.txt'],'file') == 2
        fileID = fopen([inPath 'av_lat_surfraction_SSI.txt'], 'rt');
    else
        fileID = fopen([MIF 'av_lat_surfraction_SSI.txt'], 'rt');
    end
    numDataPoints = 38880;
end

% read the data, verify that the correct number of data points is read
if fileID ~= -1
    dataArray=zeros(1,numDataPoints);   % stores the surface distribution
    nums=0;                             % counts the numbers read from file
    while ~feof(fileID)
        line=fgetl(fileID);
        temp=sscanf(line,'%f ');
        for k=1:length(temp)
            dataArray(nums+k)=temp(k);
        end
        nums=nums+length(temp);
    end
    if nums ~= numDataPoints
        diary off;
        fclose all;        
        error('makevegzonen: wrong number of surface distribution points');
    else
        if screMsg
            disp2(nums, 'elements of surface distribution points loaded.');
        end
    end
    fclose(fileID);
else
    diary off;
    fclose all;    
    error('makevegzonen: unable to open surface distribution file');
end

% reshape and remove 0 values from surface distribution, makegroups
% this is currently done differently for each type of surface distribution.
z = 180; % number of lines in vegetation matrix
dalpha = 180/z; % degrees per zone of the n-segmented half meridian (=180°)
lfirst = abs(sin(0.5*dalpha/180*pi));
breiten = 1:z;
breiten = abs(sin((breiten-0.5)*dalpha/180*pi))/lfirst;
if screCal
    disp('relative zone lengths:');
    disp(breiten);
end

if iceandsnow == 0 && ice == 0
    surfraction = zeros (180,13);
    dataArray2 = reshape(dataArray, 360,180)';
    for m = 1:180
        for k = 0:12
            surfraction(m,k+1)=length(find(dataArray2(m,:)==k))/360;
        end
    end

    if screCal
        disp('Vegetation Matrix (NoData points included): (180 x 13)');
        disp(surfraction);
    end

    % The following code eliminates NoData points by assigning the zonal
    % average to these points
    surfraction = surfraction(:,1:12)./repmat((1-surfraction(:,13)),1,12);
    if screCal
        disp('Vegetation Matrix (NoData points elimimated): (180 x 12)');
        disp(surfraction);
    end

    % now construct groups of 'similar' vegetation types
    % legend to input variable surfraction
    %  8: bare soil
    %  0: water and ice
    %  9: bushes and bare soil
    %  4: tundra
    %  7: grassland
    % 10: agricultural soil
    %  6: wooded grassland
    %  2: evergreen conifer forest and woodland
    %  5: mixed conifer forest and woodland
    %  1: evergreen deciduous forest
    %  3: deciduous forest and woodland at high latitudes
    % 11: broadleaf forest and woodland

    % legend to output variable surftype
    % 1: bare soil (8)
    % 2: water (& ice) (0)
    % 3: grassland (4,6,7,9,10)
    % 4: conif-forest (2,5)
    % 5: decid-forest (1,3,11)
    % 6-12 : empty placeholders...

    makegroups = {[8],[0],[4,6,7,9,10],[2,5],[1,3,11]};

    surftype = zeros(180,12);

    for j = 1:length(makegroups)
        sumclasses = length(makegroups{j});
        for i = 1:180
            for k = 1:sumclasses
                surftype(i,j) = surftype(i,j) + ...
                    surfraction(i, makegroups{j}(k)+1);
            end
        end
    end
    if screCal
        disp('grouped vegetation types (standard scenario): (180 x 12)');
        disp(surftype);
    end

    zc = zeros(180,1); % zero column to fill overwritten surftype manually
    switch vegmod
        case 0      % no veg, only bare soil
            surftype = [1-surftype(:,2) surftype(:,2) zc zc zc zc zc zc zc zc zc zc];
        case 1      % zonal average
            % do nothing, surftype averaged as above
        case 2      % only grassland
            surftype = [zc surftype(:,2) 1-surftype(:,2) zc zc zc zc zc zc zc zc zc];
        case 3      % only dec. forest
            surftype = [zc surftype(:,2) zc zc 1-surftype(:,2) zc zc zc zc zc zc zc];
        case 4      % only con. forest
            surftype = [zc surftype(:,2) zc 1-surftype(:,2) zc zc zc zc zc zc zc zc];
        case 5      % global average in all zones
            surftype = [0.0345 0.7162 0.1588 0.0418 0.0488 0 0 0 0 0 0 0];
            surftype = repmat(surftype, 180, 1);
        otherwise
            diary off;
            fclose all;            
            error('unknown vegmod parameter value found in function makevegzonen');
    end

    if screCal
        disp('grouped vegetation types (choosen scenario): (180 x 12)');
        disp(surftype);
    end

    % increase size of surftype to 12 seasons (for compatibility issues
    % with the ice/snow versions)
    for i= 1:12
        surftype(:,:,i) = surftype(:,:,1);
    end

elseif ice
    surfraction = reshape(dataArray,13,180)';

    % additional legend to input variable surfraction:
    % 12: permanent ice

    % additional legend to output variable surftype
    % 6: permanent ice (12)
    makegroups = {[8],[0],[4,6,7,9,10],[2,5],[1,3,11],[12]};

    surftype0 = zeros(180,12);
    for j = 1 : length(makegroups)
        sumclasses = length(makegroups{j});
        for i = 1 : 180
            for k = 1:sumclasses
                surftype0(i,j) = surftype0(i,j) + surfraction(i, makegroups{j}(k)+1);
            end
        end
    end

    surftype = zeros(180,12,12);
    for k = 1 : 12
        surftype(:,:,k) = surftype0;
    end

elseif iceandsnow
    surfraction = reshape(dataArray,18,snowseasons*180)';

    % additional legend to input variable surfraction:
    % 13: snow over bare soil
    % 14: snow over water
    % 15: snow over grassland
    % 16: snow over coniferous forest
    % 17: snow over decidous forst

    % additional legend to output variable surftype
    % 7: snow over water (14)
    % 8: snow over bare soil (13)
    % 9: snow over grassland (15)
    % 10: snow over coniferous forest (16)
    % 11: snow over decidous forst (17)
    % 12: empty placeholder...
    makegroups = {[8],[0],[4,6,7,9,10],[2,5],[1,3,11],[12],[14],[13],[15],[16],[17]};

    [x,y] = size(surfraction);

    surftype0 = zeros(x,y);
    for j = 1 : length(makegroups)
        sumclasses = length(makegroups{j});
        for i = 1 : x
            for k = 1:sumclasses
                surftype0(i,j) = surftype0(i,j) + surfraction(i, makegroups{j}(k)+1);
            end
        end
    end

    surftype = zeros(180,12,12);
    for k = 1 : 12
        surftype(:,:,k) = surftype0((k-1)*180 + 1: k*180,1:12);
    end
    % average to nseasons (used later on)
    seas_surftype = zeros(180,12,nseasons);
    for i = 1 : 180
        for j = 1 : 12
            for k = 1 : nseasons
                temp = 0;
                for z = (k-1)*12/nseasons + 1 : k*12/nseasons
                    temp = temp + surftype(i, j, z);
                end
                seas_surftype(i, j, k) = temp/(12/nseasons);
            end
        end
    end
end

%%%%%%%%%
% Part B:
%%%%%%%%%
% arbitrary number of zones (of a total of 180), with no seasonal varying
% vegetation parameter values (18=10%, 60=1/3). Has to be an even number.
equabelt = 48;

% the surface fractions of the vegetation types in the Northern hemisphere
% are stored in a 66 x 10 x 12 matrix called vegeonlyNord
vegeonlyNord = zeros(180/2-equabelt/2, 10, vegseasons);
% the surface fractions of the vegetation types in the equabelt
% are stored in a 48 x 10 x 12 matrix called vegeonlyEquabelt
vegeonlyEquabelt = zeros(equabelt, 10, vegseasons);
% the surface fractions of the vegetation types in the Southern hemisphere
% are stored in a 66 x 10 x 12 matrix called vegeonlySued
vegeonlySued = zeros(180-(180/2+equabelt/2), 10, vegseasons);
% in the above 3 variables, only the first three elements (2nd dimension)
% are full, the rest (7) are placeholders...

for k = 1 : vegseasons
    for i = 1 : 180/2 - equabelt/2
        for j = 1:3
            if  (sum(surftype(i,3:5,k))+sum(surftype(i,9:11))) ~= 0   % no vegetation, just bs & wat
                % division of fraction of vegetation type by fraction of
                % total vegetation
                vegeonlyNord(i,j,k) = ...
                    (surftype(i,j+2,k)+surftype(i,j+8))/(sum(surftype(i,3:5,k))+sum(surftype(i,9:11)));
            end
        end
    end
    for i = 180/2 - equabelt/2 + 1 : 180/2 + equabelt/2
        for j = 1:3
            if (sum(surftype(i,3:5,k))+sum(surftype(i,9:11))) ~= 0   % no vegetation, just bs & wat
                % division of fraction of vegetation type by fraction of
                % total vegetation
                vegeonlyEquabelt(i-(180/2-equabelt/2),j,k) = ...
                    (surftype(i,j+2,k)+surftype(i,j+8))/(sum(surftype(i,3:5,k))+sum(surftype(i,9:11)));
            end
        end
    end
    for i = 180/2 + equabelt/2+1 : 180
        for j = 1:3
            if (sum(surftype(i,3:5,k))+sum(surftype(i,9:11))) ~= 0   % no vegetation, just bs & wat
                % division of fraction of vegetation type by fraction of
                % total vegetation
                vegeonlySued(i-(180/2+equabelt/2),j,k) = ...
                    (surftype(i,j+2,k)+surftype(i,j+8))/(sum(surftype(i,3:5,k))+sum(surftype(i,9:11)));
            end
        end
    end
end

if iceandsnow
    % the surface fractions of seasonal snow types in the Northern hemisphere
    % are stored in a 66 x 4 x 12 matrix called snowonlyNord
    snowonlyNord = zeros(180/2-equabelt/2, 5, 12);
    % the surface fractions of the snow types in the equabelt
    % are stored in a 48 x 4 x 12 matrix called snowonlyEquabelt
    if equabelt ~= 0
        snowonlyEquabelt = zeros(equabelt, 5, 12);
    end
    % the surface fractions of the snow types in the Southern hemisphere
    % re stored in a 66 x 5 x 12 matrix called snowonlySued
    snowonlySued = zeros(180-(180/2+equabelt/2), 5, 12);

    % for comments on these loops, see vegetation above...
    for k = 1 : 12
        for i = 1 : 180/2 - equabelt/2
            for j = 1 : 5
                if sum(surftype(i, 7:11, k)) ~= 0
                    snowonlyNord(i, j, k) = surftype(i, j+6, k)/sum(surftype(i, 7:11, k));
                end
            end
        end
        if equabelt ~= 0
            for i = 180/2 - equabelt/2 + 1 : 180/2 + equabelt/2
                for j = 1 : 5
                    if sum(surftype(i, 7:11, k)) ~= 0
                        snowonlyEquabelt(i-(180/2-equabelt/2), j, k) = surftype(i,j+6,k)/sum(surftype(i, 7:11, k));
                    end
                end
            end
        end
        for i = 180/2 + equabelt/2+1 : 180
            for j = 1 : 5
                if sum(surftype(i,7:11,k)) ~= 0
                    snowonlySued(i-(180/2+equabelt/2),j,k) = surftype(i,j+6,k)/sum(surftype(i, 7:11, k));
                end
            end
        end
    end

    % the snowonlyXXX matrixes are seasonally averaged
    seas_snowonlyNord = zeros(180/2-equabelt/2,5,nseasons);
    if equabelt ~= 0
        seas_snowonlyEquabelt = zeros(equabelt,5,nseasons);
    end
    seas_snowonlySued = zeros(180/2-equabelt/2,5,nseasons);
    for i = 1 : 180/2 - equabelt/2
        for j = 1 : 5
            for k = 1 : nseasons
                temp = 0;
                for z = (k-1)*12/nseasons + 1 : k*12/nseasons
                    temp = temp + snowonlyNord(i, j, z);
                end
                seas_snowonlyNord(i, j, k) = temp/(12/nseasons);
            end
        end
    end
    for i = 1 : equabelt
        for j = 1 : 5
            for k = 1 : nseasons
                temp = 0;
                for z = (k-1)*12/nseasons + 1 : k*12/nseasons
                    temp = temp + snowonlyEquabelt(i, j, z);
                end
                seas_snowonlyEquabelt(i, j, k) = temp/(12/nseasons);
            end
        end
    end
    for i = 1 : 180/2 - equabelt/2
        for j = 1 : 5
            for k = 1 : nseasons
                temp = 0;
                for z = (k-1)*12/nseasons + 1 : k*12/nseasons
                    temp = temp + snowonlySued(i, j, z);
                end
                seas_snowonlySued(i, j, k) = temp/(12/nseasons);
            end
        end
    end
end


% the surface type distribution for the 180 latitudes are summarized to the
% surface type distribution for n zones
% the result is stored in a n x 16 x 12 matrix called zonal_surftype
zonal_surftype = zeros(n,size(surftype,2),vegseasons);
for k = 1 : vegseasons
    for j = 1 : size(surftype,2)
        for z = 1 : n
            for i = (z-1)*180/n+1 : z*180/n
                zonal_surftype(z, j, k) = zonal_surftype(z, j, k) + surftype(i, j, k) * breiten(i);
            end
        end
    end
end

% from surface fraction per 1° * breiten, the normalization to fractions of
% zones is done here
for k = 1 : vegseasons
    zonal_surftype(:,:,k) = zonal_surftype(:,:,k) ./ repmat(sum(zonal_surftype(:,:,k),2),1,size(zonal_surftype,2));
end

% the zonal values are averaged for the different seasons
% the result is stored in a n x 12 x nseasons matrix called seas_zonal_surftype
seas_zonal_surftype = zeros(n,12,nseasons);
for i = 1 : n
    for j = 1 : 12
        for k = 1 : nseasons
            temp = 0;
            for z = (k-1)*12/nseasons + 1 : k*12/nseasons
                temp = temp + zonal_surftype(i, j, z);
            end
            seas_zonal_surftype(i, j, k) = temp/(12/nseasons);
        end
    end
end

if screCal
    disp2('seasonal zonal surface type distributions for n=', n, 'zones: (n x 12)');
    disp(seas_zonal_surftype);
end


% the vegetation type surface fraction distribution is stored in a
% n x 10 x nseasons matrix called vegemix
% for detailed comments, see vegeonlyXXX loops above...
vegeonly = zeros(n, 10, nseasons);
for k = 1 : nseasons
    for i = 1 : n
        for j = 1:3
            if sum(seas_zonal_surftype(i,3:5,k)) ~= 0
                vegeonly(i,j,k) = (seas_zonal_surftype(i, j+2, k)+seas_zonal_surftype(i,j+8,k))...
                    /(sum(seas_zonal_surftype(i,3:5,k))+sum(seas_zonal_surftype(i,9:11,k)));
            end
        end
    end
end

if screCal
    disp2('vegetation type distributions for n=', n, 'zones: (n x 10)');
    disp(vegeonly);
end


% the land surface distribution (bare soil, vegetation, snow) is stored in a
% n x 10 x nseasons matrix called landmix; in the second dimensions, the
% 1st element is bs, the 2nd - 4th elements are vegsoils, and the 5th - 9th
% elements are snows
landmix = zeros(n, size(seas_zonal_surftype,2)-2, nseasons);
% for detailed comments, see vegeonlyXXX loops above...
for k = 1 : nseasons
    for i = 1 : n
        for j= 1 : size(seas_zonal_surftype, 2)
            if j == 1 && (seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)) ~= 1            % bare soil
                landmix(i,j,k) = seas_zonal_surftype(i, j, k)/(1-(seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)));
            elseif j > 2 && j < 6 && (seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)) ~= 1  % veg-soils
                landmix(i,j-1,k) = seas_zonal_surftype(i, j, k)/(1-(seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)));
            elseif j > 6 && (seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)) ~= 1         % snows
                landmix(i,j-2,k) = seas_zonal_surftype(i, j, k)/(1-(seas_zonal_surftype(i,2,k)+seas_zonal_surftype(i,6,k)));
            end
        end
    end
end

if screCal
    disp2('land type distributions for n=', n, 'zones:');
    disp(landmix);
end

% the snow type surface fraction distribution  is stored in a
% n x 4 x nseasons matrix called snowonly
snowonly = zeros(n, 5, nseasons);
% for detailed comments, see vegeonlyXXX loops above...
for k = 1 : nseasons
    for i = 1 : n
        for j = 1 : 5
            if sum(seas_zonal_surftype(i, 7:11, k)) ~= 0
                snowonly(i,j,k) = seas_zonal_surftype(i,j+6,k)/(sum(seas_zonal_surftype(i,7:11,k)));
            end
        end
    end
end

if screCal
    disp2('snow type distributions for n=', n, 'zones:');
    disp(snowonly);
end

%%%%%%%%%
% Part C:
%%%%%%%%%

if OPGGWcqu
    fileID = fopen([outPath 'seas_zonal_surftype(' runCode ').xls'], 'wt');

    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file seas_zonal_surftype.xls');
    end

    fprintf(fileID,'seasonally and zonally averaged surface fractions, starting with season 1 \n');
    if ice
        fprintf(fileID,'zone nr \tbaresoil \twater \tgrassland \tconif-forest \tdeci-forest \tperm-ice \tplaceholders... \n');
    elseif iceandsnow
        fprintf(fileID,'zone nr \tbaresoil \twater \tgrassland \tconif-forest \tdeci-forest \tperm-ice \tsnow_over_wat \tsnow_over_bs \t snow_over_grassland \tsnow_over_conif-forest \tsnow_over_deci-forest \tplaceholders... \n');
    end

    for k = 1 : nseasons
        for i = 1 : n
            fprintf(fileID, '%d \t', i);

            for j = 1 : size(seas_zonal_surftype,2)
                fprintf(fileID,'%1.3g \t', seas_zonal_surftype(i,j,k));
            end
            fprintf(fileID, '\n');
        end
    end

    fclose(fileID);
end

if OPvegvol
    fileID=fopen([outPath 'Vegeonly(' runCode ').xls'],'wt');                                % writes the vegetation type distribution to a file...
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file Vegeonly.xls');
    end

    fprintf(fileID,'Fraction of each vegetation type compared to total vegetation\n');
    fprintf(fileID,'zone nr \tgrassland \tconif-forest \tdeci-forest \n');

    for k = 1 : nseasons
        for i = 1:n
            fprintf(fileID, '%d \t', i);
            for j = 1:size(vegeonly, 2)
                fprintf(fileID,'%1.3g \t', vegeonly(i, j, k));
            end
            fprintf(fileID, '\n');
        end
    end

    fclose(fileID);
end

if iceandsnow && OPsnoice
    fileID=fopen([outPath 'snowonly(' runCode ').xls'],'wt');                                % writes the snow type distribution to a file...
    if fileID == -1
        diary off;
        fclose all;        
        error('function makesurfacefraction: file open error');
    end
    fprintf(fileID,'Fraction of each snow type compared to total snow cover \n');
    fprintf(fileID,'zone nr \tsnow_over_water \tsnow_over_bs \tsnow_over_grassland \tsnow_over_conif-forest \tsnow_over_deci-forest \n');

    for k = 1 : nseasons
        for i = 1:n
            fprintf(fileID, '%d \t', i);
            for j = 1:size(snowonly, 2)
                fprintf(fileID,'%1.3g \t', snowonly(i, j, k));
            end
            fprintf(fileID, '\n');
        end
    end

    fclose(fileID);
end

if ice
    snowonly = zeros(n, 5, 4);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcvegpartab
% CALCVEGPARTAB calculates zonal bulk vegetation parameters, considering
% the zone-specific vege type distribution and the type-specific vegetation
% parameters

global n vegseasons vegeonlyNord vegeonlyEquabelt vegeonlySued equabelt;
global vegpars breiten vegparTab surftype;
global screMsg screCal outPath nseasons vegparTabweighted;
global vegmod runCode OPvegvol;

if screMsg
    disp(' ');
    disp('function calcvegpartab: calculates zonal bulk vegetation parameters');
end

vegseason = 1;
lifetime = 405.56; % xxx previously: vegseasons * 101.389/3 -  is also 
                   % given in VegParaSeasonal - what is the difference? xxx
tempvegparTabweighted = zeros(n,vegpars,vegseasons); % collects all the vegepars

% in the following function, a table containing vegparameters for
% 180*12 zones*seasons is generated. at the end of the loop, this table is
% averaged over n (zones), then over nseasons

for i = 1:vegseasons
    vegparTabNord = vegeonlyNord(:,:,vegseason) * vegparTab(:,:,vegseason);
    % Below: correction for equabelt: foliage falls 2 Earth during whole year
    if equabelt ~= 0
        meanequavpar = mean(vegparTab(:,:,7:9),3); % August parameter for equabelt; August = season 8
        meanequavpar(1,5) = lifetime; % assign equabelt-value for grass.land
        meanequavpar(3,5) = lifetime; % assign equabelt-value for dec.fOrests
        vegparTabEquabelt = vegeonlyEquabelt(:,:,vegseasons) * meanequavpar; % vege.P?rs shall not
        % change in the equaBelt...
    end
    vegparTabSued = vegeonlySued(:,:,vegseasons) * vegparTab(:,:,mod(vegseason+5,vegseasons)+1);

    % append the 2/3 matrices along first dimension
    if equabelt ~= 0
        vegparTabJoin = [vegparTabNord ; vegparTabEquabelt ; vegparTabSued];
    else
        vegparTabJoin = [vegparTabNord ; vegparTabSued];
    end
    if screCal
        disp('vegetation parameters for each latitudinal degree: (180 x 7)');
        disp(vegparTabJoin);
    end

    % here veg-pars are averaged from 180 to n zones: vegparTabJoin
    % => vegezonenkum
    vegezonenkum = zeros(n, vegpars);
    for k = 1:n
        zonalvegarea = 0;
        for ii = (k-1)*180/n+1 : k*180/n
            noveghere = 1-(sum(surftype(ii,1:2,vegseasons))+sum(surftype(ii,6:8,vegseasons)));
            vegezonenkum(k,:) = vegezonenkum(k,:) + vegparTabJoin(ii,:)*breiten(ii)*...
                noveghere;
            zonalvegarea = zonalvegarea + breiten(ii)*noveghere;
        end
        if zonalvegarea == 0
            vegezonenkum(k,:) = zeros(1,vegpars);
        else
            vegezonenkum(k,:) = vegezonenkum(k,:) / zonalvegarea;
        end
    end
    if screCal
        disp2('Saison No', vegseason, 'zone-specific vegetation parameter values:');
        disp(vegezonenkum);
    end

    tempvegparTabweighted(:,:,vegseason) = vegezonenkum;
    vegseason = mod(vegseason, vegseasons)+1; % increase vs in the cycle ... -> 1 -> 2 -> 3 -> 4 -> 1 -> ...
end

% here, tempvegparTabweighted is averaged to nseasons

% vegparTabweighted contains the zonally and seasonally averaged vegetation
% parameters
vegparTabweighted = zeros(n,vegpars,nseasons);
switch nseasons                 % extrapolate vegparTabweighted with the correct number of nseasons from tempvegparTabweighted
    case 1
        vegparTabweighted(:,:,1)=mean(tempvegparTabweighted(:,:,1:12),3);
    case 4
        for i=1:nseasons
            vegparTabweighted(:,:,i) = mean(tempvegparTabweighted(:,:,i*3-2:i*3),3);
        end
    case 12
        vegparTabweighted=tempvegparTabweighted;
end

% here, the zonally averaged vegetation parameters are written
if vegmod ~= 0 && OPvegvol
    % Write vegpars, sorted after season, box, vegpar
    fileID = fopen([outPath 'AveragedVegPara(' runCode ').xls'], 'wt');
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file AveragedVegPara.txt');
    end
    fprintf(fileID, 'VegSeason \tBoxNo \tvdiff \tvpdry \tflipid \tVol \ttLeaf \tfomsoil \tfrf\n');
    fprintf(fileID, '[-] \t[-] \t[m/d]  \t[m/d] \t[-] \t[m3/m2 Boden] \t[d] \t[-] \t[-]\n');
    for k = 1:nseasons
        for i = 1:n
            fprintf(fileID, '%d \t%d \t', k, i); % write vegseason & box no
            for j = 1:size(vegparTabweighted,2) % loop over vegpars
                % vegparTabweighted = zeros(n,vegpars,nseasons); % collects all the vegepars
                fprintf(fileID, '%1.3g \t', vegparTabweighted(i,j,k));
            end
            fprintf(fileID, '\n');
        end
    end
    fclose(fileID);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makesnowvolfactor
% MAKESNOWVOLFACTOR generates a matrix to account for the seasonal varying
% snow volume

global n lenghalfMer iceandsnow snowvolfactor snowMaxVolSeason area_zonal OPsnoice;
global nseasons seas_zonal_surftype seas_zonal_snowheight outPath runCode;

d = lenghalfMer/n/100; % zonal width (latitudinal direction) [m]
conv_factor = pi/180;
area_zonal = zeros (1, n)'; % zonal area
snowpart = zeros(n,nseasons);
for i = 1 : n
    l = 2 * pi * lenghalfMer/100/pi * abs(sin((i*180/(2*n) + (i-1)*180/(2*n)) * conv_factor));           % circumference of the zone n [m]
    area_zonal(i) = l * d;
end

if iceandsnow
    vol_S = zeros(n,nseasons);
    for season = 1 : nseasons
        for i = 1 : n
            snowpart(i,season)  = sum(seas_zonal_surftype(i,7:11,season));
            vol_S(i,season) = seas_zonal_snowheight(i,season) * area_zonal(i) * snowpart(i,season);
        end
    end

    snowMaxVolSeason = zeros(n,1);
    for i = 1 : n
        [x,z] = max(vol_S(i,:));
        if max(vol_S(i,:)) == 0
            snowMaxVolSeason(i) = 0;
        else snowMaxVolSeason(i) = z;
        end
    end

    snowvolfactor = zeros(n,nseasons);
    for season = 1 : nseasons
        for i = 1 : n
            if snowMaxVolSeason(i) ~= 0
                snowvolfactor(i,season) = vol_S(i,season)/vol_S(i,snowMaxVolSeason(i));
            else
                snowvolfactor(i,season) = 0;
            end
        end
    end

    if OPsnoice
        fileID = fopen([outPath 'Snowvolfactor(' runCode ').xls'], 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file Snowvolfactor.xls');
        end

        fprintf(fileID,'Seasonal Snow Volume Factors \nZoneNr \t');
        for j=1:nseasons
            fprintf(fileID,'Season %d \t',j);
        end
        for i = 1:n
            fprintf(fileID,'\n%d \t',i);
            for j=1:nseasons
                fprintf(fileID,'%1.3g \t',snowvolfactor(i,j));
            end
        end

        fclose(fileID);
    end
else
    snowvolfactor = zeros(n,nseasons);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeicevolfactor
% ICEVOLFACTOR generates a matrix to account for the seasonal varying
% ice volume. Icevolfactor is <= 1 and represents the fraction of ice
% volume as compared to the maximal ice volume in the zone

global n lenghalfMer icevolfactor iceMaxVolSeason area_zonal;
global iceandsnow nseasons seas_zonal_surftype hice OPsnoice;
global outPath runCode;

d = lenghalfMer/n/100; % zonal width (latitudinal direction) [m]
conv_factor = pi/180;
area_zonal = zeros (1, n)'; % zonal area
icepart = zeros(n,nseasons);

% xxx area_zonal could probably also be taken from elsewhere in the code,
% using a global variable - but not so important.. xxx
for i = 1 : n
    l = 2 * pi * lenghalfMer/100/pi * abs(sin((i*180/(2*n) + (i-1)*180/(2*n)) * conv_factor));           % circumference of the zone n [m]
    area_zonal(i) = l * d;
end

if iceandsnow
    vol_I = zeros(n,nseasons);
    for season = 1 : nseasons
        for i  = 1 : n
            icepart(i,season)  = seas_zonal_surftype(i,6,season);
            vol_I(i,season) = hice * area_zonal(i) * icepart(i,season);
        end
    end

    iceMaxVolSeason = zeros(n,1);
    for i = 1 : n
        [x,z] = max(vol_I(i,:));
        if max(vol_I(i,:)) == 0
            iceMaxVolSeason(i) = 0;
        else
            iceMaxVolSeason(i) = z;
        end
    end

    icevolfactor = zeros(n,nseasons);
    for season = 1 : nseasons
        for i = 1 : n
            if iceMaxVolSeason(i) ~= 0
                icevolfactor(i,season) = vol_I(i,season)/vol_I(i,iceMaxVolSeason(i));
            else
                icevolfactor(i,season) = 0;
            end
        end
    end

    if OPsnoice
        fileID = fopen([outPath 'Icevolfactor(' runCode ').xls'], 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file Icevolfactor.xls');
        end

        fprintf(fileID,'Seasonal Ice Volume Factors \nZoneNr \t');
        for j=1:nseasons
            fprintf(fileID,'Season %d \t',j);
        end
        for i = 1:n
            fprintf(fileID,'\n%d \t',i);
            for j=1:nseasons
                fprintf(fileID,'%1.3g \t',icevolfactor(i,j));
            end
        end
        fclose(fileID);
    end
else
    icevolfactor = zeros(n,nseasons);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makenewvoltab
% makenewvoltab creats an array with all compartment volumes. The vol array
% has dimensions of (compartment X zones+2), i.e. 5 x 22 for calculation
% with 20 latitudinal zones (why zones+2? See makem module). Compartments
% that do not exist have volume of zero (i.e. bare soil in N-Pole). Note
% that the vegetation, snow & ice compartments may change their volumes
% between vegseasons.
%
% This version includes special treatment for snow/ice
%
global n lenghalfMer nphases vol icevolfactor;
global hsoil hwater hgas hvegsoil vegparTabweighted;
global nGZ AlpsDat nAlps outPath ice iceandsnow nseasons;
global screMsg screCal seas_zonal_surftype area_zonal;
global snowMaxVolSeason diff_hI seas_zonal_snowheight;
global vegsoilpart snowvolfactor runCode OPvegvol OPsnoice iceMaxVolSeason;

if screMsg
    disp(' ');
    disp('function makenewvoltab: calculates compartment volumes');
end

dalpha = 180/n; % degrees per zone of the n-segmented half meridian (=180Á)
d = lenghalfMer/(100*n); % zone width (latitudinal direction), in m
vol = repmat(-1,nphases,n+2); % contains compartment volumina
lfirst = 2*pi*(2*lenghalfMer/(100*2*pi))*abs(sin(0.5*dalpha/180*pi));
baresoilpart = zeros(1,n);
waterpart = zeros(1,n);
icepart = zeros(1,n);
snowpart = zeros(1,n);

if screCal
    disp2('dalpha:',dalpha,' zone width d:',d,' lfirst:',lfirst);
end

for i = 1:n
    baresoilpart(i)       = seas_zonal_surftype(i,1,1) + seas_zonal_surftype(i,8,1);
    waterpart(i)          = seas_zonal_surftype(i,2,1) + seas_zonal_surftype(i,6,1) + seas_zonal_surftype(i,7,1);
    if ice || iceandsnow
        if iceMaxVolSeason(i) == 0
            icepart(i)            = 0;
        else
            icepart(i)            = seas_zonal_surftype(i,6,iceMaxVolSeason(i));
        end
    end
    vegsoilpart(i)        = sum(seas_zonal_surftype(i,3:5))+sum(seas_zonal_surftype(i,9:11));
    if iceandsnow
        if  snowMaxVolSeason(i) == 0
            snowpart(i)          = 0;
        else
            snowpart(i)          = sum(seas_zonal_surftype(i, 7:11, snowMaxVolSeason(i)));
        end
    end

    vol(1,i+1) = hsoil * area_zonal(i) * baresoilpart(i);                                 % volume of baresoil in zone i
    vol(2,i+1) = hwater * area_zonal(i) * waterpart(i);                                   % volume of oceanwater in zone i
    vol(3,i+1) = hgas * area_zonal(i) * 1;                                                % volume of troposphere in zone i
    vol(4,i+1) = hvegsoil * area_zonal(i) * vegsoilpart(i);                               % volume of vegsoil in zone i
    switch nseasons           % necessary to detect the correct "spring" season, in which veg-pars are on yearly average
        case 1
            spri_seas = 1;
        case 4
            spri_seas = 2;
        case 12
            spri_seas = 5;
    end
    vol(5,i+1) = vegparTabweighted(i,4,spri_seas) * area_zonal(i) * vegsoilpart(i);               % volume of veg in zone i and Mai (5th season, vegvol normalized to 1 in Mai)
    if ice || iceandsnow
        vol(6,i+1) = diff_hI * area_zonal(i) * icepart(i);
    else
        vol(6,i+1) = 0;
    end
    if iceandsnow ~= 0 && snowMaxVolSeason(i) ~= 0
        vol(7,i+1) = seas_zonal_snowheight(i,snowMaxVolSeason(i)) * area_zonal(i) * snowpart(i);
    else
        vol(7,i+1) = 0;
    end
end

% now enlargement of vol.matrix to include one alpine region
if nAlps ~= 0       % if there are alpine regions somewhere...
    if screCal
        disp('vol before Alps modification:');
        disp(vol);
    end
    switch nGZ
        case 0
            % there are no mountain zones
        case 1
            % vol has currently dimensions nphases x (n+2), with two
            % -1-columns at the left and right edge. Now attaching to the
            % right of the right -1 column (the (n+2)th column) the
            % volumes of the GZ
            %
            % currently, only bs and air are included, regardless of the
            % surface fraction entries in AlpsDat
            vol(1,n+3) = hsoil * AlpsDat(1,2) * AlpsDat(1,1) * 1; % replace
            % later by:
            % vol(1,n+3) = hsoil * AlpsDat(1,2) * AlpsDat(1,1) * AlpsDat(1,5);
            vol(3,n+3) = hgas * AlpsDat(1,2) * AlpsDat(1,1); % hgas OK? or 0.65*hgas? 0.5?

        case 2
            % not yet implemented

        otherwise
            diary off;
            fclose all;            
            error('makenewvoltab: illegal value for nGZ: %d',nGZ);
    end
end

if screCal
    disp('volume matrix (compartments x (1+zones+1)):');
    disp(vol);
end

% Write vol matrix to file
if OPvegvol
    fileID = fopen([outPath 'Volumina(' runCode ').xls'], 'wt');
    phasename=['b_soil';'water ';'atmos ';'v_soil';'vegeta';'ice   ';'snow  '];
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file Volumina.xls');
    end
    fprintf(fileID,'Volumes of all compartments in m3.\n');
    fprintf(fileID,'Beware: Volumes of bulk vegetation, snow, & ice change over seasons!\n');
    fprintf(fileID,'Zone \t');
    for i=1:nphases
        fprintf(fileID,'%s \t',phasename(i,:));
    end

    for i=1:n
        fprintf(fileID,'\n%d ',i);
        fprintf(fileID,'\t %1.3g',vol(1:nphases,i+1)');
    end

    if nAlps ~= 0
        fprintf(fileID,'\n\nSpecial alpine zone(s) included, with volumes:');

        for i = 1:nGZ
            fprintf(fileID,'\n %d ',i);
            fprintf(fileID,'%1.3g \t',vol(1:nphases,n+2+i));
        end
    end
    fclose(fileID);
end

if iceandsnow && OPsnoice
    fileID = fopen([outPath 'SnowVolumina(' runCode ').xls'], 'wt');
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file SnowVolumina.xls');
    end

    fprintf(fileID,'Seasonal Snow Volumes (in m3) \nZoneNr \t');
    for j=1:nseasons
        fprintf(fileID,'Season %d \t',j);
    end
    for i = 1:n
        fprintf(fileID,'\n%d \t',i);
        for j=1:nseasons
            fprintf(fileID,'%1.3g \t',snowvolfactor(i,j)*vol(7,i+1));
        end
    end
    fclose(fileID);
end

if (ice || iceandsnow) && OPsnoice
    fileID = fopen([outPath 'IceVolumina(' runCode ').xls'], 'wt');
    if fileID == -1
        diary off;
        fclose all;        
        error('Cannot open file IceVolumina.xls');
    end
    fprintf(fileID,'Seasonal Ice Volumes (in m3) \nZoneNr \t');
    for j=1:nseasons
        fprintf(fileID,'Season %d \t',j);
    end
    for i = 1:n
        fprintf(fileID,'\n%d \t',i);
        for j=1:nseasons
            fprintf(fileID,'%1.3g \t',icevolfactor(i,j)*vol(6,i+1));
        end
    end
    fclose(fileID);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makevegvolfactab
% MAKEVEGVOLFACTAB calculates the vegetation volume correction factors for
% the vegetation seasons. The factors are stored in an (n x vegseasons)
% array called vegvolfactor. The array contains zeros in zones where no
% vegetation is located. For the spring and fall season, factors of 1 are
% used, because the averaged vege volume of these seasons is stored in the
% vol array (see makenewvoltab)

global n vegvolfactor vegparTabweighted vol runCode;
global screMsg screCal outPath nseasons vegmod OPvegvol;

if screMsg
    disp(' ');
    disp('function makevegvolfactab: calculates vegetation volumes correction factors');
end

vegvolfactor = zeros(n,nseasons);

if vegmod ~= 0
    switch nseasons             % in which seasons is veg-pars at yeary average? (in spring / May)
        case 1
            spri_seas = 1;
        case 4
            spri_seas = 2;
        case 12
            spri_seas = 5;
    end
    for j = 1:n
        for i = 1:nseasons
            if vegparTabweighted(j,4,spri_seas) == 0 % no bulk vegetation in zone j (in May, thus also in all other seasons)
                vegvolfactor(j,i) = 0;
            else
                vegvolfactor(j,i) = vegparTabweighted(j,4,i) / vegparTabweighted(j,4,spri_seas);
            end
        end
    end
    if screCal
        disp(vegvolfactor);
    end

    % Write the vegetation volumina
    if OPvegvol
        fileID = fopen([outPath 'VegeVolumina(' runCode ').xls'], 'wt');
        if fileID == -1
            diary off;
            fclose all;            
            error('Cannot open file VegeVolumina.xls');
        end
        fprintf(fileID,'Volumes of Vegetation (in m3) \nZone \t');
        for i=1:nseasons
            fprintf(fileID,'Season %d \t',i);
        end

        for j = 1:n
            fprintf(fileID, '\n');
            fprintf(fileID, '%d \t', j);
            fprintf(fileID, '%1.3g \t', vegvolfactor(j,:).*repmat(vol(5,j+1),1,nseasons));
        end
        fclose(fileID);
    end

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makestabvec
% MAKESTABVEC generates atmospheric stability vectors for the bare and vege soils
% It is assumed that the atmospheric stability is increased (and therefore
% atmospheric deposition to the soil reduced) in winter. Different types of
% vegetation influence the stability to a specific degree.
% ATTENTION: The stability factors for air --> VS are not yet modified by
% the special equabelt conditions; this should be made consistent

global n vegeonly StabVecBS StabVecVS nseasons;
global maxStabilBS minStabilBS maxStabilGras minStabilGras;
global minStabilCon maxStabilCon minStabilDec maxStabilDec;
global screMsg screCal iceandsnow;

if screMsg
    disp(' ');
    disp('function makestabvec: determines atmospheric stability vectors');
end

StabVecBS = repmat(0,n,nseasons); % contains atmos. stability factors in bare soil
StabVecVS = repmat(0,n,nseasons); % contains atmos. stability factors in vege soil

avgStabilBS = mean([minStabilBS,maxStabilBS]);          % to be added to the sinus curve below
ampStabilBS = (maxStabilBS - minStabilBS) / 2;          % to be multiplied with the sinus curve below
avgStabilGras = mean([minStabilGras,maxStabilGras]);          % to be added to the sinus curve below
ampStabilGras = (maxStabilGras - minStabilGras) / 2;          % to be multiplied with the sinus curve below
avgStabilCon = mean([minStabilCon,maxStabilCon]);          % to be added to the sinus curve below
ampStabilCon = (maxStabilCon - minStabilCon) / 2;          % to be multiplied with the sinus curve below
avgStabilDec = mean([minStabilDec,maxStabilDec]);          % to be added to the sinus curve below
ampStabilDec = (maxStabilDec - minStabilDec) / 2;          % to be multiplied with the sinus curve below

switch nseasons              % dephige is the phase difference for sinus curve below
    case 1
        phase_diff = 0;      % no maximum / minimum, if only one season
    case 4
        phase_diff = 0;      % maximum in season 1 out of 4 (Northern heimsphere)
    case 12
        phase_diff = pi/6;   % maximum in season 2 out of 12 (Northern hemisphere)
end

for i=1:nseasons        % stabvecs are assumed to be sinus curves with min in summer (or August) and max in winter (or Feb)
    for j=1:n/2
        StabVecBS(j,i) = sin(i/nseasons*2*pi+phase_diff)*ampStabilBS+avgStabilBS;
        if iceandsnow
            StabVecVS(j,i) = vegeonly(j,1,nseasons)*sin(i/nseasons*2*pi+phase_diff)*ampStabilGras+avgStabilGras ...
                +vegeonly(j,2,nseasons)*sin(i/nseasons*2*pi+phase_diff)*ampStabilCon+avgStabilCon ...
                +vegeonly(j,3,nseasons)*sin(i/nseasons*2*pi+phase_diff)*ampStabilDec+avgStabilDec;
        else
            StabVecVS(j,i) = vegeonly(j,1)*sin(i/nseasons*2*pi+phase_diff)*ampStabilGras+avgStabilGras...
                +vegeonly(j,2)*sin(i/nseasons*2*pi+phase_diff)*ampStabilCon+avgStabilCon...
                +vegeonly(j,3)*sin(i/nseasons*2*pi+phase_diff)*ampStabilDec+avgStabilDec;
        end
    end
    for j=n/2+1:n
        StabVecBS(j,i) = sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilBS+avgStabilBS;
        if iceandsnow
            StabVecVS(j,i) = vegeonly(j,1,nseasons)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilGras+avgStabilGras ...
                +vegeonly(j,2,nseasons)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilCon+avgStabilCon ...
                +vegeonly(j,3,nseasons)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilDec+avgStabilDec;
        else
            StabVecVS(j,i) = vegeonly(j,1)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilGras+avgStabilGras ...
                +vegeonly(j,2)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilCon+avgStabilCon ...
                +vegeonly(j,3)*sin(i/nseasons*2*pi+phase_diff+pi)*ampStabilDec+avgStabilDec;
        end
    end
end

if screCal
    disp2('The zone-specific bare soil atmospheric stability factors for',nseasons,' seasons are:');
    disp(StabVecBS);
    disp2('The zone-specific vege soil atmospheric stability factors for',nseasons,' seasons are:');
    disp(StabVecVS);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readOH
global screMsg inPath OH_radicals n nseasons n0t breiten MIF;

if screMsg
    disp(' ');
    disp('function readOH: reads OH concentration from spivakovski');
end
if exist([inPath 'OH_spivakovski.txt'],'file') == 2
    fileID = fopen([inPath 'OH_spivakovski.txt'], 'rt');
else
    fileID = fopen([MIF 'OH_spivakovski.txt'], 'rt');
end

if fileID~=-1
    OH_radicals=fscanf(fileID,'%f',2160);
    if length(OH_radicals)~=2160
        disp('not all datapoints read');
        keyboard
    end
    OH_radicals=reshape(OH_radicals,180,12);
    fclose(fileID);
else
    diary off;
    fclose all;    
    error('Cannot open file OH_spivakovski.txt');
end
OH_radicals2=zeros(180,nseasons);       % averaging over seasons
for k = 1 : nseasons
    temp = 0;
    for i = (k-1)*12/nseasons + 1 : k*12/nseasons
        temp = temp + OH_radicals(:,i);
    end
    OH_radicals2(:,k) = temp/(12/nseasons);
end

OH_radicals3 = zeros(n,nseasons);
n0t=180;
dummy = n0t/n; % number of lines in TtableEarth to average per lat. zone
if dummy ~= fix(dummy)
    diary off;
    fclose all;    
    error('readOH: n0t (lines in OH concentration input file) is incompatible with n (number of zones)');
end

for j = 1:nseasons                      % averaging over zones
    for i = 0:n-1
        dummy2 = 0;
        sumbreiten = 0;
        for k = 1:dummy
            dummy2 = dummy2 + OH_radicals2(i*dummy+k,j)*breiten(i*dummy+k);
            sumbreiten = sumbreiten + breiten(i*dummy+k);
        end
        OH_radicals3(i+1,j) = dummy2/sumbreiten; % stores averaged, length-weighted temp
    end
end
OH_radicals=OH_radicals3;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function maketmptab
% MAKETMPTAB reads the monthly global temperature means from the file
% 'TtableEarth' and averages the values to nseasons seasons and n zones.

global n nseasons nAlps dTAlps tmp MIF;
global screMsg screCal inPath;
global tmp_0;

if screMsg
    disp(' ');
    disp('function maketmptab: reads and averages global temperature data');
end

if exist([inPath 'TtableEarth.txt'],'file') == 2
    fileID = fopen([inPath 'TtableEarth.txt'], 'rt');
else
    fileID = fopen([MIF 'TtableEarth.txt'], 'rt');
end
if fileID ~= -1
    n0t = fscanf(fileID, '%f', 1); % number of lines in 'TtableEarth'
    n0seasons = fscanf(fileID, '%f', 1); % number of seasons in 'TtableEarth'
    if n0t~=floor(n0t) || n0seasons~=floor(n0seasons)
        diary off;
        fclose all;        
        error('maketmptab: numb. seasons & lines must be integers');
    end
else
    diary off;
    fclose all;    
    error('Cannot open file TtableEarth.txt');
end

tmp_0 = zeros(n0seasons, n0t); % place to store the raw file data

% breiten is used as weight for lat. zones with different length
dalpha = 180/n0t; % degrees per zone of the n-segmented half meridian (=180?)
lfirst = abs(sin(0.5*dalpha/180*pi));
breiten = 1:n0t;
breiten = abs(sin((breiten-0.5)*dalpha/180*pi))/lfirst;

% read temperature data from file
for i = 1:n0t
    k = fscanf(fileID, '%f', 1); % reads number of zone, is replaced constantly
    for j = 1:n0seasons
        tmp_0(j,i) = fscanf(fileID, '%f', 1); % reads temperature
    end
end
fclose(fileID); % close 'TtableEarth.txt'

% average the n0t temperature zones to the n simulated zones
tmp1 = zeros(n0seasons, n);
dummy = n0t/n; % number of lines in TtableEarth to average per lat. zone
if dummy ~= fix(dummy)
    diary off;
    fclose all;    
    error('maketmptab: n0t (lines in temperature input file) is incompatible with n (number of zones)');
end

for j = 1:n0seasons
    for i = 0:n-1
        dummy2 = 0;
        sumbreiten = 0;
        for k = 1:dummy
            dummy2 = dummy2 + (tmp_0(j, i*dummy+k)+273.15)*breiten(i*dummy+k);
            sumbreiten = sumbreiten + breiten(i*dummy+k);
        end
        tmp1(j,i+1) = dummy2/sumbreiten; % stores averaged, length-weighted temp
    end
end

% averages the n0seasons T data to nseasons seasons
tmp = zeros(nseasons, n);
dummy = n0seasons/nseasons; % number of lines in TtableEarth to average per lat. zone
if dummy ~= fix(dummy)
    diary off;
    fclose all;    
    error('maketmptab: n0seasons (columns in temperature input file) is incompatible with nseasons (number of seasons)');
end

for i = 1:n
    for j = 0:nseasons-1
        dummy2 = 0;
        for k = 1:dummy
            dummy2 = dummy2 + tmp1(j*dummy+k,i);
        end
        tmp(j+1,i) = dummy2/dummy; % stores averaged temp
        if nAlps*n == i
            tmp(j+1,i) = tmp(j+1,i) + dTAlps;
        end
    end
end

atmostemp;

if screCal
    disp2('nAlps * n =', nAlps*n);
    disp('Temperature matrix (modified for mountainous zone): (nseasons x zones)');
    disp(tmp);

    disp('Temperature matrix for atmosphere modified');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function atmostemp
% ATMOSTEMP reduces the temperature for processes in the atmosphere, as
% those processes take place at lower temperatures than on the surface. dt
% depends on season and latitude; here, values are given for 4 seasons and
% 10 zones, but are interpolated if nseasons ~= 4 or n ~= 10

global n nseasons dTAtmos atmHeightTemp;

dTAtmos=zeros(nseasons,n);
dTAtms=zeros(4,n);

% xxx these inputs have been compiled by Tanja Mägeli, but the exact source
% is unclear. They represent temperature differences between the surface of
% the globe and the representative atmospheric hight xxx
% a better source for these data would be desireable, using a resolution of
% 12 seasons times 180 zones and to be stored in an input file
dt=[ 5,   5,    7.81, 9.06, 10.1, 10.1, 9.18, 7.32, 8.12, 7.88;
     2,   6.38, 7.62, 8.87, 10.4, 9.99, 9.22, 9.02, 8.22, 5;
     4.6, 8.33, 7.68, 9.25, 10.3, 9.25, 8.85, 9.49, 7.11, 5;
     5,   4.45, 8.32, 9.44, 10.3, 9.53, 8.64, 7.86, 7.78, 6.77];

if ~ atmHeightTemp
    dt=zeros(4,10);
end

% interpolation into any number of zones (based on data that is based on 10
% zones)
ori_zones=180/10/2:180/10:(180-180/10/2);
new_zones=180/ n/2:180/ n:(180-180/ n/2);

for i=1:4
    dTAtms(i,:)=interp1(ori_zones,dt(i,:),new_zones,'cubic');
end
% cubic interpolation is used to calculate values outside original domain

% interpolation into any number of seasons. 
% probably both interpolations (in zones and seasons) could also be done 
% in one step
for season = 1:nseasons
    dTAtmos(season,:)=dTAtms(ceil(season/3),:);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makevraintab
% MAKEVRAINTAB generates a list of (1 x n) precipitation rates

global n vrain MIF inPath outPath runCode precipitation;
global screMsg interRainFall seas_zonal_prec zonalprec;
global breiten nseasons OPGGWcqu;

if screMsg
    disp(' ');
    disp('function makevraintab: generates a list of (1 x n) precipitation rates');
end

if interRainFall == 1       % with intermittent rainfall
    breiten_allmonth = [breiten breiten breiten breiten breiten breiten breiten breiten breiten breiten breiten breiten]';
    if exist([inPath 'av_lat_prec.txt'],'file') == 2
        fileID = fopen([inPath 'av_lat_prec.txt'], 'rt');
    else
        fileID = fopen([MIF 'av_lat_prec.txt'], 'rt');
    end

    if fileID ~= -1
        precipitation = fscanf (fileID, '%f', 2160);
    else
        diary off;
        fclose all;        
        error('Cannot open file av_lat_prec.txt');
    end
    fclose(fileID);

    if screMsg && (length(precipitation) == 2160)
        disp('all 2160 data point are read');
    end

    zonalprec = zeros(12*n,1);
    for i = 1 : 12*n
        temp = 0;
        for z = (i-1)*180/n+1 : i*180/n
            temp = temp + precipitation(z) * breiten_allmonth(z);
        end
        zonalprec(i) = temp/sum(breiten_allmonth((i-1)*180/n+1 : i*180/n));
    end

    seaszonalprec = zeros(n * nseasons,1);
    for i = 1 : n
        for k = 1 : nseasons
            temp = 0;
            for z =  (k-1)*12/nseasons + 1 : (k*12)/nseasons
                for w = (k - 1)*n + i
                    for v = (z-1)*n + i
                        temp = temp + zonalprec(v);
                    end
                end
            end
            seaszonalprec(w) = temp/(12/nseasons);
        end
    end
    seas_zonal_prec = zeros(n,nseasons);
    for k = 1 : nseasons
        seas_zonal_prec(:,k) = seaszonalprec((k-1)*n+1 : k*n);
    end
elseif interRainFall == 0
    % To reproduce the results of previous versions of CliMoChem, the seasonal
    % rain table has to be replaced with one world-average rain table
    seas_zonal_prec=repmat(vrain,n,nseasons);
else
    diary off;
    fclose all;    
    error('makevraintab: unexpected interRainFall value');
end

if OPGGWcqu
    fileID = fopen([outPath 'zonal_seasonal_precipitation(' runCode ').xls'], 'wt');
    if fileID ~= -1
        fprintf(fileID,'Zonally and seasonally averaged precipitation rate in m/d \nZoneNr \t');
        for j=1:nseasons
            fprintf(fileID,'Season %d \t',j);
        end
        for i = 1:n
            fprintf(fileID,'\n%d \t',i);
            for j=1:nseasons
                fprintf(fileID,'%1.3g \t',seas_zonal_prec(i,j));
            end
        end
        fclose (fileID);
    else
        diary off;
        fclose all;        
        error('unable to open zonal_seasonal_precipitation.xls output file');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcc0
% CALCC0 calculates the initial concentrations in all compartments based on
% the initial pulse emissions and the temporal emission patterns

global n nphases vol peakEmis c0 exposLimit mfexpos;
global nGZ screMsg screCal subs nsubs;

if screMsg
    disp(' ');
    disp('function calcc0: calculates initial concentrations');
end
c0 = zeros(nphases*(n+nGZ),nsubs); % row vector of seasonal initial concentrations
mfexpos = zeros(nphases*(n+nGZ),nsubs); % row vector of seasonal exposure values

for subs=1:nsubs
    for j = 0:nphases-1
        for i = 1:n
            if vol(j+1,i+1) == 0
                c0(j*n+i,subs) = 0;
                if screMsg
                    disp2('calcc0: the compartment:',j+1,' in zone:',i,' has a volume of 0');
                end
            else
                c0(j*n+i,subs) = peakEmis(1,j*n+i,subs)/vol(j+1,i+1);
            end
        end
    end
end

if screCal
    disp2('calcc0: exposLimit x substance :', exposLimit);
    disp('calcc0: c0-Matrix (concentration x substance):');
    disp(c0);
end

for subs=1:nsubs
    makefluxctab; % calculate initial fluxctab
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y=jdefit2(x)
y=5.0228378492E9 + 4.9725972024E7*x + 6.5332616741E6*x^2 + 808744.90696*x^3 - ...
    19403.0874364*x^4 + 108.223448133*x^5;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makededdytabj
% MAKEDEDDYTABJ generates a vector with eddy diffusion coefficients based
% on Junge's values

global n DeddyTab dwater screMsg screCal dEddyWatScale dEddyAtmScale;

if screMsg
    disp(' ');
    disp('function makededdytabj: generates a vector with eddy diffusion coefficients');
    disp('based on the values of Junge');
end

DeddyTab = repmat(-1,1,n);
if mod(n,2) ~= 0
    diary off;
    fclose all;    
    error('makededdytabj: n (number of zones) is not even');
end

for i=1:n/2
    DeddyTab(i) = jdefit2(90-i*180/n);
end

% Mirroring DeddyTab at the equator
for i=n/2+1:n-1
    DeddyTab(i) = DeddyTab(n-i);
end

for i = 1:n
    if screCal
        disp2('Box:',i,'  DeddyJ: ',DeddyTab(i));
    end
end

DeddyTab=DeddyTab*dEddyAtmScale;
dwater=1e8*dEddyWatScale;         % later to be read from input file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makededdytabnull
% MAKEDEDDYTABNULL generates a vector with all eddy diffusion coefficients
% set to zero. dwater is also set to zero, so there is no long-range
% transport

global n DeddyTab dwater;

warning('makededdytabnull: deddy & dwater are set to zero, no LRT');

DeddyTab = repmat(0,1,n);

dwater = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makedeepseaparttab
% MAKEDEEPSEAPARTTAB initialises a vector containing the volume fraction of
% the particles in the ocean surface layer

global n DeepSeaPartTab SeaPartTemperate SeaPartPolar SeaPartBoreal screMsg;

if screMsg
    disp(' ');
    disp('function makedeepseaparttab: create a vector with sea particle volume fractions');
end

DeepSeaPartTab = repmat(SeaPartTemperate,1,n);

DeepSeaPartTab(1:floor(n/10)) = SeaPartPolar;
DeepSeaPartTab(floor(n/10)+1:floor(n/5)) = SeaPartBoreal;
DeepSeaPartTab(n-ceil(n/5)+1:n-ceil(n/10)) = SeaPartBoreal;
DeepSeaPartTab(n-ceil(n/10)+1:n) = SeaPartPolar;

% DeepSeaPartTab = repmat(fracsuspw, 1, n); % ChemRange value
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makedeepseavelocitab
% MAKEDEEPSEAVELOCITAB initialises a vector containing the settling velocity of
% the particles in the ocean surface layer

global n DeepSeaVelociTab SeaPartVelociTemperate SeaPartVelociPolar;
global SeaPartVelociBoreal screMsg;

if screMsg
    disp(' ');
    disp('function makedeepseavelocitab: create a vector containing the settling');
    disp('velocity of surface ocean layer particles.');
end

DeepSeaVelociTab = repmat(SeaPartVelociTemperate,1,n);

DeepSeaVelociTab(1:floor(n/10)) = SeaPartVelociPolar;
DeepSeaVelociTab(floor(n/10)+1:floor(n/5)) = SeaPartVelociBoreal;
DeepSeaVelociTab(n-ceil(n/5)+1:n-ceil(n/10)) = SeaPartVelociBoreal;
DeepSeaVelociTab(n-ceil(n/10)+1:n) = SeaPartVelociPolar;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeggw
% MAKEGGW calculates the numeric values of some zone- and seasonspecific
% substance parameters and parameters derived thereof.
% NOTE THAT THE SUBSTANCE EQUATIONS ARE ALSO STORED IN FUNCTIN MAKEGGWALPS

global logKha alpha beta ice iceandsnow t0_kia rho_I ssa_I fw_I fa_I fom_I;
global cOHvariable n nseasons TWaterLim tmp nameSub screMsg nsubs runCode;
global kow kowTw k12 k12pure k42pure k34pure k32pure k31pure k53pure k35pure;
global Zair ZPartAir ZairTot Zwater Zseapart ZwaterTot k53 k35 k42 k34 k32;
global Paw k31 koa cOH ksuspw phisuspw kpartair phi k27 k63puretI;
global logKow dUow R t0 foc vegparTabweighted fossusp DeepSeaPartTab;
global snowparTabweighted OH_radicals k73puretS k73puretS_dimless AeroMod;
global logKaw dUaw tsp fracpartair fracairsoil fracwsoil outPath nyears;
global rhopart sintpar nGZ ZsnowTs_total k36 k26 k37 dTAtmos OPGGWcqu;
global KpTotal phiTotal;

if screMsg
    disp(' ');
    disp2('function makeggw: calculates zone- & seasonspecific matrix parameters');
end

% initialise parameter matrices, not necessary in MatLab, but good practice
% for large and many matrices.

kow         = zeros(nseasons, n, nsubs);
kowTw       = zeros(nseasons, n, nsubs);
kowTi       = zeros(nseasons, n, nsubs);
kowTs       = zeros(nseasons, n, nsubs);
k12         = zeros(nseasons, n, nsubs);
k12pure     = zeros(nseasons, n, nsubs);
k42pure     = zeros(nseasons, n, nsubs);
k34pure     = zeros(nseasons, n, nsubs);
k32pure     = zeros(nseasons, n, nsubs);
k32pureTi   = zeros(nseasons, n, nsubs);
k32pureTs   = zeros(nseasons, n, nsubs);
k31pure     = zeros(nseasons, n, nsubs);
k53pure     = zeros(nseasons, n, nsubs);
k35pure     = zeros(nseasons, n, nsubs);
Zair        = zeros(nseasons, n, nsubs);
ZPartAir    = zeros(nseasons, n, nsubs);
ZairTot     = zeros(nseasons, n, nsubs);
ZairTi      = zeros(nseasons, n, nsubs);
ZairTs      = zeros(nseasons, n, nsubs);
Zwater      = zeros(nseasons, n, nsubs);
Zseapart    = zeros(nseasons, n, nsubs);
ZwaterTot   = zeros(nseasons, n, nsubs);
k53         = zeros(nseasons, n, nsubs);
k35         = zeros(nseasons, n, nsubs);
k42         = zeros(nseasons, n, nsubs);
k34         = zeros(nseasons, n, nsubs);
k32         = zeros(nseasons, n, nsubs);
Paw         = zeros(nseasons, n, nsubs);
k31         = zeros(nseasons, n, nsubs);
koa         = zeros(nseasons, n, nsubs);
koaTi       = zeros(nseasons, n, nsubs);
koaTs       = zeros(nseasons, n, nsubs);
ZomTi       = zeros(nseasons, n, nsubs);
ZomTs       = zeros(nseasons, n, nsubs);
cOH         = zeros(nseasons, n);
ksuspw      = zeros(nseasons, n, nsubs);
phisuspw    = zeros(nseasons, n, nsubs);
kpartair    = zeros(nseasons, n, nsubs);
phi         = zeros(nseasons, n, nsubs);

k63puretI              = zeros(nseasons, n, nsubs);
k63puretI_dimless      = zeros(nseasons, n, nsubs);
k36                    = zeros(nseasons, n, nsubs);
k26                    = zeros(nseasons, n, nsubs);
k73puretS              = zeros(nseasons, n, nsubs);
k73puretS_dimless      = zeros(nseasons, n, nsubs);
k37                    = zeros(nseasons, n, nsubs);
k27                    = zeros(nseasons, n, nsubs);
Zice                   = zeros(nseasons, n, nsubs);
Zwater_I               = zeros(nseasons, n, nsubs);
Zwater_S               = zeros(nseasons, n, nsubs);
ZicetI_total           = zeros(nseasons, n, nsubs);
ZsnowTs_total          = zeros(nseasons, n, nsubs);
Zsnow                  = zeros(nseasons, n, nsubs);

for subs=1:nsubs
    % create GGW Output File
    if OPGGWcqu
        sintpar(subs) = fopen([outPath 'GGWparameter_' deblank(char(nameSub(subs,:))) '(' runCode ').xls'], 'wt');

        fprintf(sintpar(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
        fprintf(sintpar(subs),'Saison \tZone \tTemp  \tKow \tKowTw \tk12 \tk12pure \tk32pure \tk31pure \t');
        fprintf(sintpar(subs),'Zair \tZPartAir \tfracpartair \tZairTot \tZwater \tZseapart \tDeepSeaPartTab \t');
        fprintf(sintpar(subs),'ZwaterTot \tK32 \tPaw \tK31 \tKoa \tcOH \tkpartair \tphi \tksuspw \tphisuspw \t');
        fprintf(sintpar(subs),'k34pure \tk34 \tk42pure \tk42 \tk53pure \tk53 \tk63puretI \tk73puretS \t');
        fprintf(sintpar(subs),'k36 \tk26 \tk37 \tk27 \n');
        fprintf(sintpar(subs),'\t \tK \t- \t- \t- \t- \t- \t- \tkg/m^3/Pa \tkg/m^3/Pa \t%% \tkg/m^3/Pa \tkg/m^3/Pa \tkg/m^3/Pa ');
        fprintf(sintpar(subs),'\t%% \tkg/m^3/Pa \t- \tPa \t- \t- \tcm^-3 \t- \t%% \t- \t%% \t- \t- \t- \t- \t- \t- \t- \t- \t- \t- \t- \t- \n');
    end
end

for season = 1:nseasons
    for i = 1:n
        Tact = tmp(season,i);
        if Tact < TWaterLim
            Twater = TWaterLim;
        else
            Twater = Tact;
        end
        if Tact > 273.15 && Tact - 10 <= 273.15     % xjudithx upgedated...
            tI = Tact - 10;
            tS = Tact - 10;
        elseif Tact > 273.15 && Tact - 10 > 273.15
            tI = 273.15;
            tS = 273.15;
        else
            tI = Tact - 2;
            tS = Tact - 2;
        end

        if cOHvariable == 1     % Beyer OH concentrations
            if Tact-dTAtmos(season,i) <= 273.15
                Tact = 273.15+dTAtmos(season,i); % 2 avoid negative cOH values
            end
            cOH(season,i) = (0.5 + (Tact-dTAtmos(season,i)-273.15)*.4)*1E5; % in [1/cm3], from ABeyer
            Tact = tmp(season,i); % restore original value
        elseif cOHvariable == 0 % constant OH concentrations
            cOH(season,i)=1.5e6/2;  % value used by aopWin in [1/cm3], devided by 2 because of 12h days
        elseif cOHvariable ==2  % Spivakovski OH concentrations
            cOH(season,i)=OH_radicals(i,season);
        end

        for subs=1:nsubs
            % new t-dependent relationships for kow and kaw
            kow(season,i,subs) = 10^(logKow(subs) + dUow(subs)/2.303/8.314*(1/t0-1/Tact));
            kowTw(season,i,subs)=10^(logKow(subs) + dUow(subs)/2.308/8.314*(1/t0-1/Twater));
            kowTi(season,i,subs)     = 10^(logKow(subs) + dUow(subs)/2.308/8.314*(1/t0-1/tI));
            kowTs(season,i,subs)     = 10^(logKow(subs) + dUow(subs)/2.308/8.314*(1/t0-1/tS));
            k32pure(season,i,subs) = 10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/(Tact-dTAtmos(season,i))));
            k32pureTi(season,i,subs) = 10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/tI));
            k32pureTs(season,i,subs) = 10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/tS));
            Zwater(season,i,subs)  = 1 / (10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/Twater))*R * Twater);
            Zwater_I(season,i,subs)= 1/ (10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/273.15))*R*273.15);
            Zwater_S(season,i,subs)= Zwater_I(season,i,subs);

            % 0.35 (L/kg)*Kow=Kom (L/kg), 2.5 = bulk density of organic matter
            k12pure(season,i,subs) = foc*0.35*kow(season,i,subs)*2.5;
            k42pure(season,i,subs) = vegparTabweighted(i,6,season)*0.5*0.35*kow(season,i,subs)*2.5;

            if i==1 && season == 1 && screMsg
                disp(squeeze(vegparTabweighted(:,6,:)));
            end

            ksuspw(season,i,subs) = fossusp*0.35*kow(season,i,subs)*2.5;
            phisuspw(season,i,subs) = ksuspw(season,i,subs)*DeepSeaPartTab(i)/(1+...
                ksuspw(season,i,subs)*DeepSeaPartTab(i));

            k31pure(season,i,subs) = k32pure(season,i,subs) / k12pure(season,i,subs); % Kas = Kaw / Ksw
            koa(season,i,subs) = kow(season,i,subs) / k32pure(season,i,subs);
            koaTi(season,i,subs) = kowTi(season,i,subs) / k32pureTi(season,i,subs);
            koaTs(season,i,subs) = kowTs(season,i,subs) / k32pureTs(season,i,subs);

            if k42pure(season,i,subs) == 0
                k34pure(season,i,subs) = 0;
            else
                k34pure(season,i,subs) = k32pure(season,i,subs) / k42pure(season,i,subs);
            end
            k53pure(season,i,subs) = vegparTabweighted(i,3,season) * koa(season,i,subs);
            if k53pure(season,i,subs) == 0
                k35pure(season,i,subs) = 0;
            else
                k35pure(season,i,subs) = 1 / k53pure(season,i,subs);
            end

            if AeroMod        % separate between ppLFER and Finizio approach
                logKpartair = log10(KpTotal(season,i,subs));    % ppLFER
                kpartair(season,i,subs) = KpTotal(season,i,subs)/tsp; % in m3/g
                phi(season,i,subs) = phiTotal(season,i,subs);
            else
                logKpartair = 0.55 * log10(koa(season,i,subs)) - 8.23; % Finizio et al.
                kpartair(season,i,subs) = 10^logKpartair*1E6; % in m3/g
                phi(season,i,subs) = kpartair(season,i,subs) * tsp / (1+kpartair(season,i,subs)*tsp);
            end

            % calculation of the bulk partition coefficients
            k32(season,i,subs) = k32pure(season,i,subs) * ((1-fracpartair)+kpartair(season,i,subs)*rhopart*...
                fracpartair) / (1-DeepSeaPartTab(i)+DeepSeaPartTab(i)*ksuspw(season,i,subs));
            k12(season,i,subs) = k12pure(season,i,subs) * (1-fracairsoil-fracwsoil+fracairsoil*k31pure(season,i,subs)+...
                fracwsoil/k12pure(season,i,subs)) / (1-DeepSeaPartTab(i)+DeepSeaPartTab(i)*ksuspw(season,i,subs));
            if k42pure(season,i,subs) == 0
                k42(season,i,subs) = 0;
            else
                k42(season,i,subs) = k42pure(season,i,subs) * (1-fracairsoil-fracwsoil+fracairsoil*...
                    k34pure(season,i,subs)+fracwsoil/k42pure(season,i,subs)) / ...
                    (1-DeepSeaPartTab(i)+DeepSeaPartTab(i)*ksuspw(season,i,subs));
            end
            k31(season,i,subs) = k31pure(season,i,subs) * ((1-fracpartair)+kpartair(season,i,subs)*rhopart*...
                fracpartair) / (1-fracairsoil-fracwsoil+fracairsoil*k31pure(season,i,subs)+...
                fracwsoil/k12pure(season,i,subs));
            if k42pure(season,i,subs) == 0
                k34(season,i,subs) = 0;
            else
                k34(season,i,subs) = k34pure(season,i,subs) * ((1-fracpartair)+kpartair(season,i,subs)*rhopart*...
                    fracpartair) / (1-fracairsoil-fracwsoil+fracairsoil*k34pure(season,i,subs)+...
                    fracwsoil/k42pure(season,i,subs));
            end
            k53(season,i,subs) = k53pure(season,i,subs) * (1/(1-fracpartair+kpartair(season,i,subs)*rhopart*...
                fracpartair));
            if k53(season,i,subs) == 0
                k35(season,i,subs) = 0;
            else
                k35(season,i,subs) = 1/k53(season,i,subs);
            end


            % calculation of Z-parameters (Zwater is calculated above)
            Zair(season,i,subs) = 1 / (R*Tact);
            ZairTi(season,i,subs) = 1 / (R*tI);
            ZairTs(season,i,subs) = 1 / (R*tS);
            ZPartAir(season,i,subs) = kpartair(season,i,subs)*rhopart*Zair(season,i,subs);
            ZairTot(season,i,subs) = (1-fracpartair)*Zair(season,i,subs) + fracpartair*ZPartAir(season,i,subs);
            % Zwater is calculated above

            % preparation for the particle deposition 2 deep.sea
            Zseapart(season,i,subs) = Zwater(season,i,subs)*fossusp*0.35*2.5*kowTw(season,i,subs);
            % is equal to: Zseapart = Zwater*ksuspw(Twater)

            ZwaterTot(season,i,subs) = (1-DeepSeaPartTab(i))*Zwater(season,i,subs)+DeepSeaPartTab(i)*...
                Zseapart(season,i,subs);
            Paw(season,i,subs) = ZairTot(season,i,subs) / ZwaterTot(season,i,subs);

            k32(season,i,subs) = Paw(season,i,subs);

            ZomTi(season,i,subs)         = koaTi(season,i,subs) * ZairTi(season,i,subs);                                    % fugacity capacity of organic matter [mol/m3Pa]
            ZomTs(season,i,subs)         = koaTs(season,i,subs) * ZairTs(season,i,subs);                                    % fugacity capacity of organic matter [mol/m3Pa]



            % snow/ice partition coefficients
            k63pure_pp            = 10^(0.639 * logKha(subs) + 3.38 * beta(subs) + 3.53 * alpha(subs) - 6.85);      % partitioning coefficient between snowsurface and air [m] at 266.35 K
            k23pure_pp            = 10^(0.635 * logKha(subs) + 5.11 * beta(subs) + 3.6 * alpha(subs) - 8.47);       % partitioning coefficient between watersurface and air [m] at 288.15 K
            dH23                  = (-5.07 * log(k23pure_pp) - 108)*1000;                                           % enthalpy of sorption [kJ/mol]

            if ice || iceandsnow
                k63puretI(season,i,subs)            = 10^(log10(k63pure_pp) + dH23/(2.303 * 8.314) * (1/t0_kia - 1/tI));  % partitioning coefficient between snowsurface and air [m] at Tact
                k63puretI_dimless(season,i,subs)    = rho_I * ssa_I * k63puretI(season,i,subs);
                Zice(season,i,subs)                 = k63puretI_dimless(season,i,subs) * Zair(season,i,subs);                           % fugacity capacity of pure snow/ice [mol/m3Pa
                ZicetI_total(season,i,subs)         = (1 - fw_I - fom_I - fa_I) * Zice(season,i,subs) ...
                    + fw_I * Zwater_I(season,i,subs) + fa_I * Zair(season,i,subs)...
                    + fom_I * ZomTi(season,i,subs);
                if ZicetI_total(season,i,subs)  ~= 0
                    k36(season,i,subs) = ZairTot(season,i,subs)/ZicetI_total(season,i,subs);                    % partitioning coefficient between bulk air and bulk snow/ice []
                    k26(season,i,subs) = Zwater_I(season,i,subs)/ZicetI_total(season,i,subs);                     % partitioning coefficient between water and bulk snow/ice for meltwater runoff []
                end
            end

            if iceandsnow
                k73puretS(season,i,subs)         = 10^(log10(k63pure_pp) + dH23/(2.303 * 8.314) * (1/t0_kia - 1/tS));                                   % partitioning coefficient between snowsurface and air [m] at Tact
                k73puretS_dimless(season,i,subs) = snowparTabweighted(i,1,season) * snowparTabweighted(i,2,season) * k73puretS(season,i,subs);                        % dimensionless partitioning coefficient between snowsurface and air [m] at Tact
                Zsnow(season,i,subs)              = k73puretS_dimless(season,i,subs) * ZairTs(season,i,subs);                                        % fugacity capacity of pure snow/ice [mol/m3Pa]
                ZsnowTs_total(season,i,subs)      = (1 - snowparTabweighted(i,4,season) - snowparTabweighted(i,5,season)...
                    - snowparTabweighted(i,6,season)) * Zsnow(season,i,subs) ...
                    + snowparTabweighted(i,5,season) * Zwater_S(season,i,subs)...
                    + snowparTabweighted(i,6,season) * ZairTs(season,i,subs)...
                    + snowparTabweighted(i,4,season) * ZomTs(season,i,subs);                                                          % fugacity capacity of bulk snow pack [mol/m3Pa]

                if ZsnowTs_total(season,i,subs)  ~= 0
                    k37(season,i,subs) = ZairTot(season,i,subs)/ZsnowTs_total(season,i,subs);                    % partitioning coefficient between bulk air and bulk snow/ice []
                    k27(season,i,subs) = Zwater_S(season,i,subs)/ZsnowTs_total(season,i,subs) ;
                end
            end

            if (~ice) && (~iceandsnow)
                k63puretI(season,i,subs)  = 0;
                k73puretS(season,i,subs)  = 0;
                k36(season,i,subs)        = 0;
                k26(season,i,subs)        = 0;
                k37(season,i,subs)        = 0;
                k27(season,i,subs)        = 0;
            end

            if OPGGWcqu
                % write the values to file <sintpar>
                fprintf(sintpar(subs), '%d \t%d \t%1.3g \t',season,i,tmp(season,i));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t',kow(season,i,subs),kowTw(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g  \t',k12(season,i,subs),k12pure(season,i,subs),k32pure(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',k31pure(season,i,subs),Zair(season,i,subs),ZPartAir(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',fracpartair,ZairTot(season,i,subs),Zwater(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',Zseapart(season,i,subs),DeepSeaPartTab(i),ZwaterTot(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',k32(season,i,subs),Paw(season,i,subs),k31(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t',koa(season,i,subs),cOH(season,i));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',kpartair(season,i,subs),phi(season,i,subs),ksuspw(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',phisuspw(season,i,subs),k34pure(season,i,subs),k34(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',k42pure(season,i,subs),k42(season,i,subs),k53pure(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',k53(season,i,subs),k63puretI(season,i,subs),k73puretS(season,i,subs));
                fprintf(sintpar(subs), '%1.3g \t%1.3g \t%1.3g \t',k36(season,i,subs),k26(season,i,subs),k37(season,i,subs));
                fprintf(sintpar(subs), '%1.3g\n',                k27(season,i,subs));
            end
        end
    end
end

if nGZ ~= 0
    makeggwalps;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeggwalps
% MAKEGGWALPS calculates the numeric values of alpine zone- and seasonspecific
% substance parameters and parameters derived thereof.
% xxx the alpine module has not been finalized/tested and should not be
% used without considerable care! xxx

global nAlps AlpsDat nGZ phiAlps koaAlps k32pureAlps k12pureAlps k31Alps;
global n nseasons tmp kpartair logKow dUow t0 foc rhopart logKaw dUaw;
global tsp fracpartair fracairsoil fracwsoil screMsg;

if screMsg
    disp(' ');
    disp('function makeggwalps: calcs alpine zone- & seasonspecific matrix parameters');
end

%%%%%%%%%%%%%% BAUSTELLE: SUBSTANCES MUST BE INCLUDED IN FOR LOOP, AS IN
%%%%%%%%%%%%%% MAKEGGW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

phiAlps = zeros(nseasons, nGZ);
koaAlps = zeros(nseasons, nGZ);
k32pureAlps = zeros(nseasons, nGZ);
k12pureAlps = zeros(nseasons, nGZ);
k31Alps = zeros(nseasons, nGZ);
kowAlps = zeros(nseaons, nGZ);
k31pureAlps = zeros(nseasons, nGZ);

for season = 1:nseasons
    for i = 1:nGZ

        % Calculation of actual temperature in the GZ...
        AlpsZone = nAlps * n;
        TmpAlps = tmp(season,AlpsZone) + AlpsDat(i,3); % AlpsDat(i,3) = dT

        % new t-dependency with dU values
        k32pureAlps(season,i) = 10^(logKaw(subs) + dUaw(subs)/2.303/8.314*(1/t0-1/TmpAlps));

        % new t-dependency with dU values
        kowAlps(season,i) = 10^(logKow(subs) + dUow(subs)/2.303/8.314*(1/t0-1/TmpAlps));

        koaAlps(season,i) = kowAlps(season,i) / k32pureAlps(season,i);

        % phiAlps
        logKpartair = 0.55 * log10(koaAlps(season,i)) - 8.23; % Finizio et al.
        kpartair = 10^logKpartair*1E6; % in m3/g
        phiAlps(season,i) = kpartair * tsp / (1+kpartair*tsp);

        % k12pureAlps
        k12pureAlps(season,i) = foc*0.35*kowAlps(season,i)*2.5;

        % k31Alps
        k31pureAlps(season,i) = k32pureAlps(season,i) / k12pureAlps(season,i); % Kas = Kaw / Ksw
        k31Alps(season,i) = k31pureAlps(season,i) * ((1-fracpartair)+kpartair*rhopart*...
            fracpartair) / (1-fracairsoil-fracwsoil+fracairsoil*k31pureAlps(season,i)+...
            fracwsoil/k12pureAlps(season,i));
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makevgross
% MAKEVGROSS2 creates the phase transfer matrix. It is rewritten to better
% populate the fluxPTab vector. The specific kinetic process parameters are
% first stored in a 3D u-Matrix and then summarized to the 2D vmatrix,
% which is inserted into the large vgross matrix.

global n vgross nphases fluxInd hsoil hgas hvegsoil SizeDif;
global scavratio vgasW vgasS vwater StabVecBS StabVecVS vwet vdry;
global vegparTabweighted vol vegvolfactor season ddf_S fa_I fw_I ddf_I;
global k32pure k12pure k42pure k31 k32 k34 k35 k36 fracairsoil fracwsoil;
global vleach vrunoff phi phiFine phiCoarse phisuspw umatrix fluxInTab OPmasflu;
global nGZ nAlps interRainFall hice tdry screMsg wpf vdry_I scavratioSnow;
global nsubs subs nameSub k63puretI  ice iceandsnow seas_zonal_surftype;
global k26 k37 k27 seas_zonal_prec rho_SF snowparTabweighted vdry_S ssa_SF;
global tmp snowvolfactor seas_zonal_snowheight icevolfactor;

if screMsg
    disp(' ');
    disp2('function makevgross: creates the phase transfer matrix (with umatrix) for substance',char(nameSub(subs,:)));
end

if subs==1
    umatrix = zeros(nphases,nphases,24,nsubs); % stores rate constants          % can be done for every subs???
    vgross = zeros(nphases*(n+nGZ),nphases*(n+nGZ),nsubs); % stores model phase matrix
end

% vgross is enlarged from the original (5n x 5n) dimension by nGZ bands of
% nphases=5 rows/columns for the additional compartments in the GZs
fluxInd = 1;

for i = 1:n
    Tact = tmp(season,i);

    %%%%%%%%%%%%%%%%%% PRELIMINARY CALCULATIONS ON AREAS %%%%%%%%%%%%%%%%%
    % the purpose of the Xpart variables is that seas_zonal_surftype
    % contains only the type of surface at the surface, ignoring what is
    % below. SIGMA seas_zonal_surftype therefore is 0. For calculation of
    % volumes of phases, this variable is inaccurate, because vegetation /
    % soil / water may lie below snow / ice surfaces. Xpart is therefore
    % the sum of non-covered and covered X, and is later on used to
    % calculate eg area43vol4, the air - veg-soil exchange are devided by
    % the volume of veg-soil

    areabaresoilpart = seas_zonal_surftype(i,1,season);
    baresoilpart     = seas_zonal_surftype(i,1,1) + seas_zonal_surftype(i,8,1);
    areawaterpart    = seas_zonal_surftype(i,2,season);
    areaicepart      = seas_zonal_surftype(i,6,season);

    areavegsoilpart  = sum(seas_zonal_surftype(i,3:5,season));
    vegsoilpart      = sum(seas_zonal_surftype(i,3:5))+sum(seas_zonal_surftype(i,9:11));
    if iceandsnow
        areasnowpart     = sum(seas_zonal_surftype(i,7:11,season));
    end
    if baresoilpart == 0
        a13vol1 = 0;
    else
        a13vol1 = areabaresoilpart/(baresoilpart * hsoil);
    end
    if vegsoilpart == 0
        a43vol4 = 0;
    else
        a43vol4 = areavegsoilpart/(vegsoilpart * hvegsoil);
    end
    a13vol3 = areabaresoilpart/(1*hgas);
    a23vol3 = areawaterpart/(1*hgas);
    a43vol3 = areavegsoilpart/(1*hgas);
    if ice || iceandsnow
        a63vol3 = areaicepart/(1*hgas);
        if areaicepart * hice ~= 0
            a63vol2 = seas_zonal_surftype(i,6,season)/(areaicepart * hice);
        else
            a63vol2 = 0;
        end
    end
    if iceandsnow
        a73vol3 = areasnowpart/(1*hgas);
        if areasnowpart * seas_zonal_snowheight(i,season) == 0
            a73vol1 = 0;
            a73vol2 = 0;
            a73vol4 = 0;
        else
            a73vol1 = seas_zonal_surftype(i,8,season)/(areasnowpart * seas_zonal_snowheight(i,season));
            a73vol2 = seas_zonal_surftype(i,7,season)/(areasnowpart * seas_zonal_snowheight(i,season));
            a73vol4 = sum(seas_zonal_surftype(i,9:11,season))/(areasnowpart * seas_zonal_snowheight(i,season));
        end
    end


    %%%%%%%%%%%%%%%%%% SOME PRELIMINARY CALCULATIONS... %%%%%%%%%%%%%%%%%%
    % ...FOR INTERMITTENT RAINFALL
    % Generic values for averag duration of rain events in days, by Matt:
    twet = repmat(0.5,n,1);                         % average duration of rain events in days

    if interRainFall
        fwRain = (tdry(i,season) + twet(i))/twet(i) * seas_zonal_prec(i,season)/(25200*24);
        fwSnow = (tdry(i,season) + twet(i))/twet(i) * seas_zonal_prec(i,season)/(2520*24);
    else
        fwRain = 0;
        fwSnow = 0;
    end
    % Upper limit for residence time for total wet deposition
    TauInterRainUp = (tdry(i,season)/2)*(tdry(i,season)/(tdry(i,season) + twet(i)));
    % the rainfall (m3/m2/d) is seasonally and zonally averaged
    vwet = seas_zonal_prec(i,season)*scavratio;

    vtotWG = vgasW*vwater/(k32pure(season,i,subs)*vgasW+vwater);
    % (k32pure since assumption: only pure phases in 2.film.model)

    % ...FOR BIOTURBATION IN BARESOIL AND VEGESOIL
    % new calculation of vtotSGbare, including bio.turbatio
    DG = (fracairsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.43; % m2/d
    DL = (fracwsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.000043; % m2/d
    DS = 5.5E-7; % m2/d
    vG = DG / (hsoil/2) * (k32pure(season,i,subs)/((1-fracwsoil-fracairsoil)*k12pure(season,i,subs)+...
        fracwsoil+fracairsoil*k32pure(season,i,subs)));
    vL = DL / (hsoil/2) * 1 /((1-fracwsoil-fracairsoil)*k12pure(season,i,subs)+...
        fracwsoil+fracairsoil*k32pure(season,i,subs));
    vS = DS / (hsoil/2) * (k12pure(season,i,subs) /((1-fracwsoil-fracairsoil)*k12pure(season,i,subs)+...
        fracwsoil+fracairsoil*k32pure(season,i,subs)));
    vtotsoilneu = vG + vL/k32pure(season,i,subs) + vS/(k32pure(season,i,subs)/k12pure(season,i,subs));
    vtotSGbare = (1/(vgasS/StabVecBS(i, season))+1/vtotsoilneu)^-1;

    % new calculation of vtotSGvege, including bio.turbatio
    if (vol(4,i+1)==0) || (k42pure(season,i,subs)==0)
        vtotSGvege = 0;
    else
        DG = (fracairsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.43; % m2/d
        DL = (fracwsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.000043; % m2/d
        DS = 5.5E-7; % m2/d
        vG = DG / (hvegsoil/2) * (k32pure(season,i,subs)/((1-fracwsoil-fracairsoil)*k42pure(season,i,subs)+...
            fracwsoil+fracairsoil*k32pure(season,i,subs)));
        vL = DL / (hvegsoil/2) * 1 /((1-fracwsoil-fracairsoil)*k42pure(season,i,subs)+...
            fracwsoil+fracairsoil*k32pure(season,i,subs));
        vS = DS / (hvegsoil/2) * (k42pure(season,i,subs) /((1-fracwsoil-fracairsoil)*k42pure(season,i,subs)+...
            fracwsoil+fracairsoil*k32pure(season,i,subs)));
        vtotsoilneu = vG + vL/k32pure(season,i,subs) + vS/(k32pure(season,i,subs)/k42pure(season,i,subs));
        vtotSGvege = (1/(vgasS/StabVecVS(i, season)/2)+1/vtotsoilneu)^-1;
    end

    % ...FOR AEROSOL MODULE
    % Scavenging Efficiencies different to 1
    % (Handbook Seinfeld and Pandis, 2007)
    EdryFine = 0.1;
    EdryCoarse = 0.5;
    EscavFine = 0.05;
    EscavCoarse = 0.5;
    % for snow scavenging (extrapolated from rain - Urs after discussion
    % with CGoetz)
    ESscavFine = 1;
    ESscavCoarse = 1;


    %%%%%% 1. CALCULATE EXCHANGE PROCESSES ATMOS - BARESOIL (v31) %%%%%%
    v31diff = vtotSGbare * a13vol3;

    % Calculate v31rain
    if interRainFall
        v31rain = seas_zonal_prec(i,season) * a13vol3 / (fwRain + k32pure(season,i,subs));  % adjusted gaseous deposition rate for intermittent rain
    else
        v31rain = seas_zonal_prec(i,season) * a13vol3 / k32pure(season,i,subs);             % gaseous deposition rate for continous rain and zonally and seasonally averaged amount of rainfall
    end

    % Calculate particle deposition for TWO different size fractions
    if SizeDif
        v31dry       = 0;
        v31wet       = 0;
        v31dryFine   = vdry / StabVecBS(i,season) * a13vol3 * EdryFine;   % atmospheric stability influences dep
        v31dryCoarse = vdry / StabVecBS(i,season) * a13vol3 * EdryCoarse; % atmospheric stability influences dep
        v31wetFine   = vwet                       * a13vol3 * EscavFine;
        v31wetCoarse = vwet                       * a13vol3 * EscavCoarse;
        if interRainFall
            if (v31rain*(1-phi(season,i,subs)) + v31wetFine*phiFine(season,i,subs) + v31wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areabaresoilpart% check the maximum createria of intermittent rainfall (if: actual rate > maximum)
                ratio1   = (v31wetFine*phiFine(season,i,subs))     / (v31rain*(1-phi(season,i,subs)) + v31wetFine*phiFine(season,i,subs) + v31wetCoarse*phiCoarse(season,i,subs)); % Ratio of fine wet particle dep. on total wet dep.
                ratio2   = (v31wetCoarse*phiCoarse(season,i,subs)) / (v31rain*(1-phi(season,i,subs)) + v31wetFine*phiFine(season,i,subs) + v31wetCoarse*phiCoarse(season,i,subs)); % Ratio of coarse wet particle dep. on total wet dep.
                ratio3   = (v31rain*(1-phi(season,i,subs)))        / (v31rain*(1-phi(season,i,subs)) + v31wetFine*phiFine(season,i,subs) + v31wetCoarse*phiCoarse(season,i,subs)); % Ratio of rain washout on total wet dep.
                v31wetFine   = 1/TauInterRainUp * areabaresoilpart * ratio1; % Replace through weighted upper limit
                v31wetCoarse = 1/TauInterRainUp * areabaresoilpart * ratio2; % Replace through weighted upper limit
                v31rain      = 1/TauInterRainUp * areabaresoilpart * ratio3; % Replace through weighted upper limit
            end
        end

        % Calculate particle deposition for ONE aerosol size
    else
        v31dry       = vdry / StabVecBS(i,season) * a13vol3;    % atmospheric stability influences dep
        v31wet       = vwet                       * a13vol3;
        v31dryFine   = 0;
        v31dryCoarse = 0;
        v31wetFine   = 0;
        v31wetCoarse = 0;
        if interRainFall
            if (v31rain*(1-phi(season,i,subs)) + v31wet*phi(season,i,subs)) > 1/TauInterRainUp * areabaresoilpart % check the maximum createria of intermittent rainfall
                ratio   = (v31wet*phi(season,i,subs)) / (v31rain*(1-phi(season,i,subs)) + v31wet*phi(season,i,subs)); % Ratio of wet particle dep. on total wet dep.
                v31wet  = 1/TauInterRainUp * areabaresoilpart * ratio    ; % Replace through weighted upper limit
                v31rain = 1/TauInterRainUp * areabaresoilpart * (1-ratio); % Replace through weighted upper limit
            end
        end
    end

    % Check compartment volume and set values to zero if volume is zero
    if vol(1,i+1)==0
        v31rain=0;
        v31wet=0;
        v31dryFine = 0;
        v31dryCoarse = 0;
        v31wetFine = 0;
        v31wetCoarse = 0;
    end


    %%%%%% 2. CALCULATE EXCHANGE PROCESSES ATMOS - WATER (v32) %%%%%%
    v32diff = vtotWG * a23vol3;

    % Calculate v32rain
    if interRainFall
        v32rain = seas_zonal_prec(i,season) * a23vol3 / (fwRain + k32pure(season,i,subs)); % adjusted gaseous deposition rate for intermittent rain
    else
        v32rain = seas_zonal_prec(i,season) * a23vol3 / k32pure(season,i,subs);            % gaseous deposition rate for continous rain and zonally and seasonally averaged amount of rainfall
    end

    % Calculate particle deposition for TWO different size fractions
    if SizeDif
        v32dry       = 0;
        v32wet       = 0;
        v32dryFine   = vdry * a23vol3 * EdryFine;      % no atmospheric stability-influenced.dep
        v32dryCoarse = vdry * a23vol3 * EdryCoarse;    % no atmospheric stability-influenced.dep
        v32wetFine   = vwet * a23vol3 * EscavFine;
        v32wetCoarse = vwet * a23vol3 * EscavCoarse;
        if interRainFall
            if (v32rain*(1-phi(season,i,subs)) + v32wetFine*phiFine(season,i,subs) + v32wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areawaterpart; % check the maximum createria of intermittent rainfall
                ratio1   = (v32wetFine*phiFine(season,i,subs))     / (v32rain*(1-phi(season,i,subs)) + v32wetFine*phiFine(season,i,subs) + v32wetCoarse*phiCoarse(season,i,subs)); % Ratio of fine wet particle dep. on total wet dep.
                ratio2   = (v32wetCoarse*phiCoarse(season,i,subs)) / (v32rain*(1-phi(season,i,subs)) + v32wetFine*phiFine(season,i,subs) + v32wetCoarse*phiCoarse(season,i,subs)); % Ratio of coarse wet particle dep. on total wet dep.
                ratio3   = (v32rain*(1-phi(season,i,subs)))        / (v32rain*(1-phi(season,i,subs)) + v32wetFine*phiFine(season,i,subs) + v32wetCoarse*phiCoarse(season,i,subs)); % Ratio of rain washout on total wet dep.
                v32wetFine   = 1/TauInterRainUp * areawaterpart * ratio1; % Replace through weighted upper limit
                v32wetCoarse = 1/TauInterRainUp * areawaterpart * ratio2; % Replace through weighted upper limit
                v32rain      = 1/TauInterRainUp * areawaterpart * ratio3; % Replace through weighted upper limit
            end
        end

        % Calculate particle deposition for ONE aerosol size
    else
        v32dry       = vdry * a23vol3;     % no atmospheric stability-influenced.dep
        v32wet       = vwet * a23vol3;
        v32dryFine   = 0;
        v32dryCoarse = 0;
        v32wetFine   = 0;
        v32wetCoarse = 0;
        if interRainFall
            if (v32rain*(1-phi(season,i,subs)) + v32wet*phi(season,i,subs)) > 1/TauInterRainUp * areawaterpart; % check the maximum createria of intermittent rainfall
                ratio   = (v32wet*phi(season,i,subs)) / (v32rain*(1-phi(season,i,subs)) + v32wet*phi(season,i,subs)); % Ratio of wet particle dep. on total wet dep.
                v32wet  = 1/TauInterRainUp * areawaterpart * ratio    ; % Replace through weighted upper limit
                v32rain = 1/TauInterRainUp * areawaterpart * (1-ratio); % Replace through weighted upper limit
            end
        end
    end


    %%%%%% 3. CALCULATE EXCHANGE PROCESSES ATMOS - VEGESOIL (v34) %%%%%%
    v34diff = vtotSGvege * a43vol3; % ATTENTION: FACTOR 0.5 lowered vtotSGvege due to shielding property of foliage

    % Calculate v34rain
    if interRainFall
        v34rain = seas_zonal_prec(i,season) * a43vol3 / (fwRain + k32pure(season,i,subs)) * (1-vegparTabweighted(i,7,season)); % adjusted gaseous deposition rate for intermitted rain
    else
        v34rain = seas_zonal_prec(i,season) * a43vol3 / k32pure(season,i,subs) * (1-vegparTabweighted(i,7,season));            % wet.dep -= frf; gaseous deposition rate for continous rain and zonally and seasonally averaged amount of rainfall
    end

    % Calculate particle deposition for TWO different size fractions
    if SizeDif
        v34dry = 0;
        v34wet = 0;
        if StabVecVS(i,season) ~= 0
            v34dryFine   = vdry / StabVecVS(i,season) / 2 * a43vol3 * EdryFine;   % / 2 because vegecover shields soil
            v34dryCoarse = vdry / StabVecVS(i,season) / 2 * a43vol3 * EdryCoarse; % / 2 because vegecover shields soil
        else
            v34dryFine   = vdry / 2 * a43vol3 * EdryFine;   % / 2 because vegecover shields soil (assumption)
            v34dryCoarse = vdry / 2 * a43vol3 * EdryCoarse; % / 2 because vegecover shields soil (assumption)
        end
        v34wetFine   = vwet * a43vol3 * (1-vegparTabweighted(i,7,season)) * EscavFine;   % wet.dep -= frf;
        v34wetCoarse = vwet * a43vol3 * (1-vegparTabweighted(i,7,season)) * EscavCoarse; % wet.dep -= frf;
        if interRainFall
            if (v34rain*(1-phi(season,i,subs)) + v34wetFine*phiFine(season,i,subs) + v34wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areavegsoilpart; % check the maximum createria of intermittent rainfall
                ratio1   = (v34wetFine*phiFine(season,i,subs))     / (v34rain*(1-phi(season,i,subs)) + v34wetFine*phiFine(season,i,subs) + v34wetCoarse*phiCoarse(season,i,subs)); % Ratio of fine wet particle dep. on total wet dep.
                ratio2   = (v34wetCoarse*phiCoarse(season,i,subs)) / (v34rain*(1-phi(season,i,subs)) + v34wetFine*phiFine(season,i,subs) + v34wetCoarse*phiCoarse(season,i,subs)); % Ratio of coarse wet particle dep. on total wet dep.
                ratio3   = (v34rain*(1-phi(season,i,subs)))        / (v34rain*(1-phi(season,i,subs)) + v34wetFine*phiFine(season,i,subs) + v34wetCoarse*phiCoarse(season,i,subs)); % Ratio of rain washout on total wet dep.
                v34wetFine   = 1/TauInterRainUp * areavegsoilpart * ratio1; % Replace through weighted upper limit
                v34wetCoarse = 1/TauInterRainUp * areavegsoilpart * ratio2; % Replace through weighted upper limit
                v34rain      = 1/TauInterRainUp * areavegsoilpart * ratio3; % Replace through weighted upper limit
            end
        end

        % Calculate particle deposition for ONE aerosol size
    else
        if StabVecVS(i,season) ~= 0
            v34dry = vdry / StabVecVS(i,season) / 2 * a43vol3; % / 2 because vegecover shields soil
        else
            v34dry = vdry / 2 * a43vol3; % / 2 because vegecover shields soil (assumption)
        end
        v34wet = vwet * a43vol3 * (1-vegparTabweighted(i,7,season)); % wet.dep -= frf
        v34dryFine   = 0;
        v34dryCoarse = 0;
        v34wetFine   = 0;
        v34wetCoarse = 0;
        if interRainFall
            if (v34rain*(1-phi(season,i,subs)) + v34wet*phi(season,i,subs)) > 1/TauInterRainUp * areavegsoilpart % check the maximum createria of intermittent rainfall
                ratio   = (v34wet*phi(season,i,subs)) / (v34rain*(1-phi(season,i,subs)) + v34wet*phi(season,i,subs)); % Ratio of wet particle dep. on total wet dep.
                v34wet  = 1/TauInterRainUp * areavegsoilpart * ratio    ; % Replace through weighted upper limit
                v34rain = 1/TauInterRainUp * areavegsoilpart * (1-ratio); % Replace through weighted upper limit
            end
        end
    end

    % Check compartment volume and set values to zero if volume is zero
    if vol(4,i+1)==0
        v34rain      = 0;
        v34wet       = 0;
        v34dryFine   = 0;
        v34dryCoarse = 0;
        v34wetFine   = 0;
        v34wetCoarse = 0;
    end


    %%%%%% 4. CALCULATE EXCHANGE PROCESSES ATMOS - VEGETAT (v35) %%%%%%
    v35diff = vegparTabweighted(i,1,season) * a43vol3; % !! vdiff is from vegparTabweighted, because it's region specific !!

    % Calculate rain washout to vegetation v35rain
    if interRainFall
        v35rain = seas_zonal_prec(i,season) * a43vol3 / (fwRain + k32pure(season,i,subs)) * vegparTabweighted(i,7,season); % adjusted gaseous deposition rate for intermitted rain
    else
        v35rain = seas_zonal_prec(i,season) * a43vol3 / k32pure(season,i,subs) * vegparTabweighted(i,7,season);            % gaseous deposition rate for continous rain and zonally and seasonally averaged amount of rainfall
    end

    % Calculate particle deposition for TWO different size fractions
    if SizeDif
        v35dry       = 0;
        v35wet       = 0;
        v35dryFine   = vegparTabweighted(i,2,season) * a43vol3 * EdryFine;   % no atmospheric stability-influenced.dep  !! vdry is from vegparTabweighted, because it's region specific !!
        v35dryCoarse = vegparTabweighted(i,2,season) * a43vol3 * EdryCoarse; % no atmospheric stability-influenced.dep  !! vdry is from vegparTabweighted, because it's region specific !!
        v35wetFine   = vwet * vegparTabweighted(i,7,season) * a43vol3 * EscavFine;
        v35wetCoarse = vwet * vegparTabweighted(i,7,season) * a43vol3 * EscavCoarse;
        if interRainFall
            if (v35rain*(1-phi(season,i,subs)) + v35wetFine*phiFine(season,i,subs) + v35wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areavegsoilpart; % check the maximum createria of intermittent rainfall
                ratio1   = (v35wetFine*phiFine(season,i,subs))     / (v35rain*(1-phi(season,i,subs)) + v35wetFine*phiFine(season,i,subs) + v35wetCoarse*phiCoarse(season,i,subs)); % Ratio of fine wet particle dep. on total wet dep.
                ratio2   = (v35wetCoarse*phiCoarse(season,i,subs)) / (v35rain*(1-phi(season,i,subs)) + v35wetFine*phiFine(season,i,subs) + v35wetCoarse*phiCoarse(season,i,subs)); % Ratio of coarse wet particle dep. on total wet dep.
                ratio3   = (v35rain*(1-phi(season,i,subs)))        / (v35rain*(1-phi(season,i,subs)) + v35wetFine*phiFine(season,i,subs) + v35wetCoarse*phiCoarse(season,i,subs)); % Ratio of rain washout on total wet dep.
                v35wetFine   = 1/TauInterRainUp * areavegsoilpart * ratio1; % Replace through weighted upper limit
                v35wetCoarse = 1/TauInterRainUp * areavegsoilpart * ratio2; % Replace through weighted upper limit
                v35rain      = 1/TauInterRainUp * areavegsoilpart * ratio3; % Replace through weighted upper limit
            end
        end


        % Calculate particle deposition for ONE aerosol size
    else
        v35dry       = vegparTabweighted(i,2,season) * a43vol3; % no atmospheric stability-influenced.dep !! vdry is from vegparTabweighted, because it's region specific !!
        v35wet       = vwet * vegparTabweighted(i,7,season) * a43vol3;
        v35dryFine   = 0;
        v35dryCoarse = 0;
        v35wetFine   = 0;
        v35wetCoarse = 0;
        if interRainFall
            if (v35rain*(1-phi(season,i,subs)) + v35wet*phi(season,i,subs)) > 1/TauInterRainUp * areavegsoilpart % check the maximum createria of intermittent rainfall
                ratio   = (v35wet*phi(season,i,subs)) / (v35rain*(1-phi(season,i,subs)) + v35wet*phi(season,i,subs)); % Ratio of wet particle dep. on total wet dep.
                v35wet  = 1/TauInterRainUp * areavegsoilpart * ratio    ; % Replace through weighted upper limit
                v35rain = 1/TauInterRainUp * areavegsoilpart * (1-ratio); % Replace through weighted upper limit
            end
        end
    end

    % Check compartment volume and set values to zero if volume is zero
    if vol(5,i+1)==0
        v35rain      = 0;
        v35dry       = 0;
        v35wet       = 0;
        v35dryFine   = 0;
        v35dryCoarse = 0;
        v35wetFine   = 0;
        v35wetCoarse = 0;
    end


    %%%%%% 5. CALCULATE EVAPORATION PROCESSES INTO ATMOS (vX3) %%%%%%
    if vol(1,i+1) == 0
        v13diff = 0;
    else
        v13diff = k31(season,i,subs) * vol(3,i+1) * v31diff / vol(1,i+1);
    end
    if vol(2,i+1) == 0
        v23diff = 0;
    else
        v23diff = k32(season,i,subs) * vol(3,i+1) * v32diff / vol(2,i+1);
    end
    if vol(4,i+1) == 0
        v43diff = 0;
    else
        v43diff = k34(season,i,subs) * vol(3,i+1) * v34diff / vol(4,i+1);
    end
    if vol(5,i+1) == 0
        v53diff = 0;
    else
        v53diff = k35(season,i,subs) * vol(3,i+1) * v35diff / (vol(5,i+1)*...
            vegvolfactor(i,season));
    end

    v13up = 0; % no aerosol uplifting from bare soil to air
    v43up = 0; % no aerosol uplifting from vegetation soil to air


    %%%%%% 7. CALCULATE EXCHANGE PROCESSES VEGE - VEGSOIL (v54) %%%%%%
    if vegparTabweighted(i,5,season)==0 || (vol(5,i+1) * vegvolfactor(i,season)) == 0 || vol(4,i+1) == 0
        v54leavefall=0; % OK, leavefall....   :-)
    else
        v54leavefall=1/vegparTabweighted(i,5,season);
    end


    %%%%%% 7. CALCULATE PROCESSES RELATED TO ICE (vX6, v6X) %%%%%%
    if ice || iceandsnow  % ice
        DG_I = 0.43*fa_I^(10/3)/(fa_I + fw_I)^2;
        DL_I = 0.000043*fw_I^(10/3)/(fa_I + fw_I)^2;
        vG_I = DG_I/(hice/2);
        vL_I = DL_I/(hice/2);
        vI = 120;
        vtot_36 = (1/vI + 1/(vG_I + vL_I/k32pure(season,i,subs)))^-1;

        v36diff = vtot_36 * a63vol3;

        if   vol(6,i+1) * icevolfactor(i,season) ~= 0
            v63diff = v36diff * k36(season,i,subs) * vol(3,i+1)/(vol(6,i+1)*icevolfactor(i,season));
        else
            v63diff = 0;
        end

        if interRainFall && vol(6,i+1) * icevolfactor(i,season) ~= 0
            v36rain = seas_zonal_prec(i,season) * a63vol3 / (fwSnow + 1/(rho_SF * ssa_SF * k63puretI(season,i,subs)));
        elseif vol(6,i+1) * icevolfactor(i,season) ~= 0
            v36rain = seas_zonal_prec(i,season) * a63vol3 * rho_SF * ssa_SF * k63puretI(season,i,subs);
        else
            v36rain=0;
        end

        % Calculate Particle Deposition for TWO different size fractions
        if SizeDif
            v36dry=0;
            v36wet=0;
            v36dryFine      = vdry_I * a63vol3 * EdryFine;
            v36dryCoarse    = vdry_I * a63vol3 * EdryCoarse;
            v36wetFine      = seas_zonal_prec(i,season) * scavratioSnow * a63vol3 * ESscavFine;
            v36wetCoarse    = seas_zonal_prec(i,season) * scavratioSnow * a63vol3 * ESscavCoarse;
            if interRainFall && vol(6,i+1) * icevolfactor(i,season) ~= 0
                % check the maximum criteria of intermittent rainfall (if:
                % actual rate > maximum)
                if (v36rain*(1-phi(season,i,subs)) + v36wetFine * phiFine(season,i,subs)...
                        + v36wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areaicepart
                    % ratio of fine wet part dep on total wet dep
                    ratio1 = (v36wetFine*phiFine(season,i,subs)) / ...
                        (v36rain*(1-phi(season,i,subs)) + v36wetFine*phiFine(season,i,subs) + v36wetCoarse*phiCoarse(season,i,subs));
                    % ratio of coarse wet part dep on total wet dep
                    ratio2 = (v36wetCoarse*phiCoarse(season,i,subs)) / ...
                        (v36rain*(1-phi(season,i,subs)) + v36wetFine*phiFine(season,i,subs) + v36wetCoarse*phiCoarse(season,i,subs));
                    % ratio of rain washout on total wet dep
                    ratio3 = (v36rain*(1-phi(season,i,subs))) / ...
                        (v36rain*(1-phi(season,i,subs)) + v36wetFine*phiFine(season,i,subs) + v36wetCoarse*phiCoarse(season,i,subs));

                    % replace by upper limits
                    v36wetFine   = 1/TauInterRainUp * areaicepart * ratio1;
                    v36wetCoarse = 1/TauInterRainUp * areaicepart * ratio2;
                    v36rain      = 1/TauInterRainUp * areaicepart * ratio3;
                end
            elseif vol(6,i+1) * icevolfactor(i,season) == 0
                v36dryFine = 0;
                v36dryCoarse = 0;
                v36wetFine = 0;
                v36wetCoarse = 0;
                v36rain = 0;
            end
        else
            v36dry = vdry_I * a63vol3;
            v36wet = seas_zonal_prec(i,season) * scavratioSnow * a63vol3;
            v36dryFine = 0;
            v36dryCoarse = 0;
            v36wetFine = 0;
            v36wetCoarse = 0;
            if interRainFall && vol(6,i+1) * icevolfactor(i,season) ~= 0
                % check the maximum criteria of intermittent rainfall (if:
                % actual rate > maximum)
                if (v36rain*(1-phi(season,i,subs)) + v36wet * phi(season,i,subs)) > 1/TauInterRainUp * areaicepart
                    % ratio of fine wet part dep on total wet dep
                    ratio = (v36wet*phi(season,i,subs)) ...
                        / (v36rain*(1-phi(season,i,subs)) + v36wet*phi(season,i,subs));

                    % replace by upper limits
                    v36wet   = 1/TauInterRainUp * areaicepart * ratio;
                    v36rain  = 1/TauInterRainUp * areaicepart * (1-ratio);
                end
            elseif vol(6,i+1) * icevolfactor(i,season) == 0
                v36dry  = 0;
                v36wet  = 0;
                v36rain = 0;
            end
        end

    end


    %%%%%% 8. CALCULATE PROCESSES RELATED TO SNOW (vX7, v7X) %%%%%%
    if iceandsnow
        if  snowparTabweighted(i,5,season) + snowparTabweighted(i,6,season) ~= 0
            DG_S = 0.43*snowparTabweighted(i,6,season)^(10/3)/(snowparTabweighted(i,5,season) + snowparTabweighted(i,6,season))^2;
            DL_S = 0.000043*snowparTabweighted(i,5,season)^(10/3)/(snowparTabweighted(i,5,season) + snowparTabweighted(i,6,season))^2;
        else
            DG_S = 0;
            DL_S = 0;
        end
        if  seas_zonal_snowheight(i,season) ~= 0
            vG_S = wpf * DG_S/(seas_zonal_snowheight(i,season)/2);
            vL_S = wpf * DL_S/(seas_zonal_snowheight(i,season)/2);
        else
            vG_S = 0;
            vL_S = 0;
        end
        if vG_S + vL_S ~= 0
            vS = 120;
            vtot_37 = (1/vS + 1/(vG_S + vL_S/k32pure(season,i,subs)))^-1;
        else
            vtot_37 = 0;
        end

        v37diff = vtot_37 * a73vol3;
        if vol(7,i+1) * snowvolfactor(i,season) ~= 0
            v73diff = v37diff * k37(season,i,subs) * vol(3,i+1)/(vol(7,i+1)*snowvolfactor(i,season));
        else
            v73diff = 0;
        end

        if interRainFall && vol(7,i+1) * snowvolfactor(i,season) ~= 0
            v37rain = seas_zonal_prec(i,season) * a73vol3 / (fwSnow + 1/(rho_SF * ssa_SF * k63puretI(season,i,subs)));
        elseif vol(6,i+1) * icevolfactor(i,season) == 0
            v37rain = seas_zonal_prec(i,season) * a73vol3 * rho_SF * ssa_SF * k63puretI(season,i,subs);
        else
            v37rain=0;
        end

        % Calculate Particle Deposition for TWO different size fractions
        if SizeDif
            v37dry=0;
            v37wet=0;
            v37dryFine      = vdry_S * a73vol3 * EdryFine;
            v37dryCoarse    = vdry_S * a73vol3 * EdryCoarse;
            v37wetFine      = seas_zonal_prec(i,season) * scavratioSnow * a73vol3 * ESscavFine;
            v37wetCoarse    = seas_zonal_prec(i,season) * scavratioSnow * a73vol3 * ESscavCoarse;
            if interRainFall && vol(7,i+1) * snowvolfactor(i,season) ~= 0
                % check the maximum criteria of intermittent rainfall (if:
                % actual rate > maximum)
                if (v37rain*(1-phi(season,i,subs)) + v37wetFine * phiFine(season,i,subs)...
                        + v37wetCoarse*phiCoarse(season,i,subs)) > 1/TauInterRainUp * areasnowpart
                    % ratio of fine wet part dep on total wet dep
                    ratio1 = (v37wetFine*phiFine(season,i,subs)) / ...
                        (v37rain*(1-phi(season,i,subs)) + v37wetFine*phiFine(season,i,subs) + v37wetCoarse*phiCoarse(season,i,subs));
                    % ratio of coarse wet part dep on total wet dep
                    ratio2 = (v37wetCoarse*phiCoarse(season,i,subs)) / ...
                        (v37rain*(1-phi(season,i,subs)) + v37wetFine*phiFine(season,i,subs) + v37wetCoarse*phiCoarse(season,i,subs));
                    % ratio of rain washout on total wet dep
                    ratio3 = (v37rain*(1-phi(season,i,subs))) / ...
                        (v37rain*(1-phi(season,i,subs)) + v37wetFine*phiFine(season,i,subs) + v37wetCoarse*phiCoarse(season,i,subs));

                    % replace by upper limits
                    v37wetFine   = 1/TauInterRainUp * areasnowpart * ratio1;
                    v37wetCoarse = 1/TauInterRainUp * areasnowpart * ratio2;
                    v37rain      = 1/TauInterRainUp * areasnowpart * ratio3;
                end
            elseif vol(7,i+1) * snowvolfactor(i,season) == 0
                v37dryFine = 0;
                v37dryCoarse = 0;
                v37wetFine = 0;
                v37wetCoarse = 0;
                v37rain = 0;
            end
        else
            v37dry = vdry_S * a73vol3;
            v37wet = seas_zonal_prec(i,season) * scavratioSnow * a73vol3;
            v37dryFine = 0;
            v37dryCoarse = 0;
            v37wetFine = 0;
            v37wetCoarse = 0;
            if interRainFall && vol(7,i+1) * snowvolfactor(i,season) ~= 0
                % check the maximum criteria of intermittent rainfall (if:
                % actual rate > maximum)
                if (v37rain*(1-phi(season,i,subs)) + v37wet * phi(season,i,subs)) > 1/TauInterRainUp * areasnowpart
                    % ratio of fine wet part dep on total wet dep
                    ratio = (v37wet*phi(season,i,subs)) ...
                        / (v37rain*(1-phi(season,i,subs)) + v37wet*phi(season,i,subs));

                    % replace by upper limits
                    v37wet   = 1/TauInterRainUp * areasnowpart * ratio;
                    v37rain  = 1/TauInterRainUp * areasnowpart * (1-ratio);
                end
            elseif vol(7,i+1) * snowvolfactor(i,season) == 0
                v37dry  = 0;
                v37wet  = 0;
                v37rain = 0;
            end
        end

        Tact_C = Tact - 273.15;
        if Tact_C > 0
            runoff_snow = ddf_S * Tact_C;
            v71runoff = runoff_snow * k27(season,i,subs) * a73vol1;
            v72runoff = runoff_snow * k27(season,i,subs) * a73vol2;
            v74runoff = runoff_snow * k27(season,i,subs) * a73vol4;
        else
            v71runoff = 0;
            v72runoff = 0;
            v74runoff = 0;
        end
    end


    %%%%%% 9. SET SNOW/ICE VARIABLES TO 0 IF NO SNOW/ICE %%%%%%
    if iceandsnow == false  %ice &&
        v36diff           = 0;
        v63diff           = 0;
        v36dry            = 0;
        v36dryFine        = 0;
        v36dryCoarse      = 0;
        v36rain           = 0;
        v36wet            = 0;
        v36wetFine        = 0;
        v36wetCoarse      = 0;
        vol(6,i+1)        = 0;
        v37diff           = 0;
        v73diff           = 0;
        v37dry            = 0;
        v37dryFine        = 0;
        v37dryCoarse      = 0;
        v37rain           = 0;
        v37wet            = 0;
        v37wetFine        = 0;
        v37wetCoarse      = 0;
        v71runoff         = 0;
        v72runoff         = 0;
        v74runoff         = 0;
        vol(7,i+1)        = 0;
    end


    %%%%%% 10. CONSTRUCTION OF UMATRIX FROM vXY values %%%%%%
    % the assignments umatrix(x,y,z)=0 could be omitted, because umatrix is
    % initialised to zero. They are given anyway as placeholders for
    % modifications and for clarity reasons

    %%%%%%%%%%%%%%%%%%%
    % dcBS / dt = ....
    umatrix(1,1,1,subs) = -a13vol1 * vleach/k12pure(season,i,subs); % bs --> sea: leaching
    umatrix(1,1,2,subs) = -a13vol1 * vrunoff; % bs --> sea: runoff
    umatrix(1,1,3,subs) = -v13diff; % bs --> air: gas diff.out
    umatrix(1,1,4,subs) = -v13up; % bs --> air: aerosol uplifting
    umatrix(1,2,1,subs) = 0; % no transfer processes sea --> bs
    if vol(1,i+1) == 0
        umatrix(1,3,1,subs) = 0; % no transfer.proc in non-existant.compartment bs
        umatrix(1,3,2,subs) = 0;
        umatrix(1,3,3,subs) = 0;
        umatrix(1,3,4,subs) = 0;
    else
        if SizeDif
            umatrix(1,3,1,subs) = (phiFine(season,i,subs) * v31wetFine + phiCoarse(season,i,subs) * v31wetCoarse) * vol(3,i+1)/vol(1,i+1);         % air --> bs: wet part.dep
            umatrix(1,3,2,subs) = (phiFine(season,i,subs) * v31dryFine + phiCoarse(season,i,subs) * v31dryCoarse) * vol(3,i+1)/vol(1,i+1);         % air --> bs: dry part.dep
        else
            umatrix(1,3,1,subs) = phi(season,i,subs) * v31wet * vol(3,i+1)/vol(1,i+1);     % air --> bs: wet part.dep
            umatrix(1,3,2,subs) = phi(season,i,subs) * v31dry * vol(3,i+1)/vol(1,i+1);     % air --> bs: dry part.dep
        end
        umatrix(1,3,3,subs) = (1-phi(season,i,subs)) * v31diff * vol(3,i+1)/vol(1,i+1);    % air --> bs: diff.in
        umatrix(1,3,4,subs) = (1-phi(season,i,subs)) * v31rain * vol(3,i+1)/vol(1,i+1);    % air --> bs: gaseous rain scav.
    end
    umatrix(1,4,1,subs) = 0; % no transfer processes vs --> bs
    umatrix(1,5,1,subs) = 0; % no transfer processes veg --> bs
    % dBS: snow & ice:
    umatrix(1,6,1,subs) = 0;                                                                       % no transfer processes ice --> bs
    if vol(1,i+1) ~= 0
        umatrix(1,7,1,subs) = (v71runoff * vol(7,i+1) * snowvolfactor(i,season))/vol(1,i+1);       % meltwater runoff snow --> bs
    else
        umatrix(1,7,1,subs) = 0;
    end

    %%%%%%%%%%%%%%%%%%%
    % dcSea / dt = ....
    if vol(2,i+1) == 0
        umatrix(2,1,1,subs) = 0;
    else
        umatrix(2,1,1,subs) = a13vol1 * vleach/k12pure(season,i,subs) * vol(1,i+1)/vol(2,i+1);  % bs --> sea: leaching
        umatrix(2,1,2,subs) = a13vol1 * vrunoff * vol(1,i+1)/vol(2,i+1); % bs --> sea: runoff
    end
    umatrix(2,2,1,subs) = -v23diff * (1-phisuspw(season,i,subs)); % sea --> air: diff.out
    if vol(2,i+1) == 0
        umatrix(2,3,1,subs) = 0; % no transfer.proc in non-existant.compartment sea
    else
        if SizeDif
            umatrix(2,3,1,subs) = (phiFine(season,i,subs) * v32wetFine + phiCoarse(season,i,subs) * v32wetCoarse) * vol(3,i+1)/vol(2,i+1);         % air --> sea: wet part.dep
            umatrix(2,3,2,subs) = (phiFine(season,i,subs) * v32dryFine + phiCoarse(season,i,subs) * v32dryCoarse) * vol(3,i+1)/vol(2,i+1);         % air --> sea: dry part.dep
        else
            umatrix(2,3,1,subs) = phi(season,i,subs) * v32wet * vol(3,i+1)/vol(2,i+1);     % air --> sea: wet part.dep
            umatrix(2,3,2,subs) = phi(season,i,subs) * v32dry * vol(3,i+1)/vol(2,i+1);     % air --> sea: dry part.dep
        end
        umatrix(2,3,3,subs) = (1-phi(season,i,subs)) * v32diff * vol(3,i+1)/vol(2,i+1);    % air --> sea: diff.in
        umatrix(2,3,4,subs) = (1-phi(season,i,subs)) * v32rain * vol(3,i+1)/vol(2,i+1);    % air --> sea: gaseous rain scav.
    end
    if vol(2,i+1) == 0 || k42pure(season,i,subs) == 0 || vol(4,i+1) == 0
        umatrix(2,4,1,subs) = 0;
        umatrix(2,4,2,subs) = 0;
    else
        umatrix(2,4,1,subs) = a43vol4 * vleach/k42pure(season,i,subs) * vol(4,i+1)/vol(2,i+1);
        % vs --> sea: leaching
        umatrix(2,4,2,subs) = a43vol4 * vrunoff * vol(4,i+1)/vol(2,i+1);
        % vs --> sea: vrunoff
    end
    umatrix(2,5,1,subs) = 0; % no transfer processes veg --> sea
    % dSea: snow
    if vol(2,i+1) ~= 0
        umatrix(2,7,1,subs) = (v72runoff * vol(7,i+1) * snowvolfactor(i,season))/vol(2,i+1);                % meltwater runoff snow --> water
    else umatrix(2,7,1,subs) = 0;
    end

    %%%%%%%%%%%%%%%%%%%
    % dcAir / dt = ....
    umatrix(3,1,1,subs) = v13diff * vol(1,i+1)/vol(3,i+1); % bs --> air: diff.in
    umatrix(3,1,2,subs) = v13up * vol(1,i+1)/vol(3,i+1); % bs --> air: aerosol.uplifting
    umatrix(3,2,1,subs) = v23diff * (1-phisuspw(season,i,subs)) * vol(2,i+1)/vol(3,i+1);
    % sea --> air: diff.in
    if SizeDif
        umatrix(3,3,1,subs) = -(phiFine(season,i,subs) * v31wetFine + phiCoarse(season,i,subs) * v31wetCoarse); % air --> bs: par.dep.wet
        umatrix(3,3,2,subs) = -(phiFine(season,i,subs) * v31dryFine + phiCoarse(season,i,subs) * v31dryCoarse); % air --> bs: par.dep.dry
        umatrix(3,3,3,subs) = -(phiFine(season,i,subs) * v32wetFine + phiCoarse(season,i,subs) * v32wetCoarse); % air --> sea: par.dep.wet
        umatrix(3,3,4,subs) = -(phiFine(season,i,subs) * v32dryFine + phiCoarse(season,i,subs) * v32dryCoarse); % air --> sea: par.dep.dry
        umatrix(3,3,5,subs) = -(phiFine(season,i,subs) * v34wetFine + phiCoarse(season,i,subs) * v34wetCoarse); % air --> vs: par.dep.wet
        umatrix(3,3,6,subs) = -(phiFine(season,i,subs) * v34dryFine + phiCoarse(season,i,subs) * v34dryCoarse); % air --> vs: par.dep.dry
        umatrix(3,3,7,subs) = -(phiFine(season,i,subs) * v35wetFine + phiCoarse(season,i,subs) * v35wetCoarse); % air --> veg: par.dep.wet
        umatrix(3,3,8,subs) = -(phiFine(season,i,subs) * v35dryFine + phiCoarse(season,i,subs) * v35dryCoarse); % air --> veg: par.dep.dry
    else
        umatrix(3,3,1,subs) = -phi(season,i,subs) * v31wet; % air --> bs: par.dep.wet
        umatrix(3,3,2,subs) = -phi(season,i,subs) * v31dry; % air --> bs: par.dep.dry
        umatrix(3,3,3,subs) = -phi(season,i,subs) * v32wet; % air --> sea: par.dep.wet
        umatrix(3,3,4,subs) = -phi(season,i,subs) * v32dry; % air --> sea: par.dep.dry
        umatrix(3,3,5,subs) = -phi(season,i,subs) * v34wet; % air --> vs: par.dep.wet
        umatrix(3,3,6,subs) = -phi(season,i,subs) * v34dry; % air --> vs: par.dep.dry
        umatrix(3,3,7,subs) = -phi(season,i,subs) * v35wet; % air --> veg: par.dep.wet
        umatrix(3,3,8,subs) = -phi(season,i,subs) * v35dry; % air --> veg: par.dep.dry
    end
    umatrix(3,3,9,subs)  = -(1-phi(season,i,subs)) * v31diff; % air --> bs: diff.out
    umatrix(3,3,10,subs) = -(1-phi(season,i,subs)) * v31rain; % air --> bs: gas.dep.wet
    umatrix(3,3,11,subs) = -(1-phi(season,i,subs)) * v32diff; % air --> sea: diff.out
    umatrix(3,3,12,subs) = -(1-phi(season,i,subs)) * v32rain; % air --> sea: gas.dep.wet
    umatrix(3,3,13,subs) = -(1-phi(season,i,subs)) * v34diff; % air --> vs: diff.out
    umatrix(3,3,14,subs) = -(1-phi(season,i,subs)) * v34rain; % air --> vs: gas.dep.wet
    umatrix(3,3,15,subs) = -(1-phi(season,i,subs)) * v35diff; % air --> veg: diff.out
    umatrix(3,3,16,subs) = -(1-phi(season,i,subs)) * v35rain; % air --> veg: gas.dep.wet
    umatrix(3,4,1,subs)  = v43diff * vol(4,i+1)/vol(3,i+1);   % vs --> air: diff.in
    umatrix(3,4,2,subs)  = v43up * vol(4,i+1)/vol(3,i+1);     % vs --> air: aerosol.uplifting
    umatrix(3,5,1,subs)  = v53diff * (vol(5,i+1)*vegvolfactor(i,season))/vol(3,i+1);  % veg --> air: diff.in
    % dAir: snow & ice:
    if SizeDif
        umatrix(3,3,18,subs) = - (phiFine(season,i,subs)*v36dryFine + phiCoarse(season,i,subs)*v36dryCoarse);
        umatrix(3,3,20,subs) = - (phiFine(season,i,subs)*v36wetFine + phiCoarse(season,i,subs)*v36wetCoarse);
        umatrix(3,3,22,subs) = - (phiFine(season,i,subs)*v37dryFine + phiCoarse(season,i,subs)*v37dryCoarse);
        umatrix(3,3,24,subs) = - (phiFine(season,i,subs)*v37wetFine + phiCoarse(season,i,subs)*v37wetCoarse);
    else
        umatrix(3,3,18,subs) = -phi(season,i,subs) * v36dry;                                % air --> ice: par.dep.dry
        umatrix(3,3,20,subs) = -phi(season,i,subs) * v36wet;                                % air --> ice: par.dep.wet
        umatrix(3,3,22,subs) = -phi(season,i,subs) * v37dry;                                % air --> snow: par.dep.dry
        umatrix(3,3,24,subs) = -phi(season,i,subs) * v37wet;                                % air --> snow: par.dep.wet
    end
    umatrix(3,3,17,subs) = -(1-phi(season,i,subs)) * v36diff;                           % air --> ice: diff.out
    umatrix(3,3,19,subs) = -(1-phi(season,i,subs)) * v36rain;                           % air --> ice: gas.dep.wet
    umatrix(3,3,21,subs) = -(1-phi(season,i,subs)) * v37diff;                           % air --> snow: diff.out
    umatrix(3,3,23,subs) = -(1-phi(season,i,subs)) * v37rain;                           % air --> snow: gas.dep.wet
    umatrix(3,6,1,subs)  = v63diff * vol(6,i+1)/vol(3,i+1);                             % ice --> air: diff.in
    umatrix(3,7,1,subs)  = (v73diff * vol(7,i+1) * snowvolfactor(i,season))/vol(3,i+1); % snow --> air: diff.in

    %%%%%%%%%%%%%%%%%%%
    % dcVS / dt = ....
    umatrix(4,1,1,subs) = 0; % no transfer processes bs --> vs
    umatrix(4,2,1,subs) = 0; % no transfer processes sea --> vs
    if vol(4,i+1) == 0
        umatrix(4,3,1,subs) = 0;
        umatrix(4,3,2,subs) = 0;
        umatrix(4,3,3,subs) = 0;
        umatrix(4,3,4,subs) = 0;
    else
        if SizeDif
            umatrix(4,3,1,subs) = (phiFine(season,i,subs) * v34wetFine + phiCoarse(season,i,subs) * v34wetCoarse) * vol(3,i+1)/vol(4,i+1);   % air --> vs: wet part.dep
            umatrix(4,3,2,subs) = (phiFine(season,i,subs) * v34dryFine + phiCoarse(season,i,subs) * v34dryCoarse) * vol(3,i+1)/vol(4,i+1);   % air --> vs: dry part.dep
        else
            umatrix(4,3,1,subs) = phi(season,i,subs) * v34wet * vol(3,i+1)/vol(4,i+1);   % air --> vs: wet part.dep
            umatrix(4,3,2,subs) = phi(season,i,subs) * v34dry * vol(3,i+1)/vol(4,i+1);   % air --> vs: dry part.dep
        end
        umatrix(4,3,3,subs) = (1-phi(season,i,subs)) * v34diff * vol(3,i+1)/vol(4,i+1);  % air --> vs: diff.in
        umatrix(4,3,4,subs) = (1-phi(season,i,subs)) * v34rain * vol(3,i+1)/vol(4,i+1);  % air --> vs: gaseous rain scav.
    end
    if vol(4,i+1) == 0 || k42pure(season,i,subs) == 0
        umatrix(4,4,1,subs) = 0;
        umatrix(4,4,2,subs) = 0;
        umatrix(4,4,3,subs) = 0;
        umatrix(4,4,4,subs) = 0;
    else
        umatrix(4,4,1,subs) = -a43vol4 * vleach/k42pure(season,i,subs); % vs --> sea: leaching
        umatrix(4,4,2,subs) = -a43vol4 * vrunoff; % vs --> sea: runoff
        umatrix(4,4,3,subs) = -v43diff; % vs --> air: diff.out
        umatrix(4,4,4,subs) = -v43up; % vs --> air: aerosol.uplifting
    end
    if vol(4,i+1) == 0
        umatrix(4,5,1,subs) = 0;
    else
        umatrix(4,5,1,subs) = v54leavefall * vol(5,i+1)*vegvolfactor(i,season)/vol(4,i+1);
        % vs --> veg: leaf.fall
    end
    % dVS: snow & ice:
    umatrix(4,6,1,subs) = 0;                                                                       % no transfer processes ice --> vs
    if vol(4,i+1) ~= 0
        umatrix(4,7,1,subs) = (v74runoff * vol(7,i+1) * snowvolfactor(i,season))/vol(4,i+1);       % meltwater runoff snow --> vs
    else
        umatrix(4,7,1,subs) = 0;
    end

    %%%%%%%%%%%%%%%%%%%
    % dcVeg / dt = ....
    umatrix(5,1,1,subs) = 0; % no transfer processes bs --> veg
    umatrix(5,2,1,subs) = 0; % no transfer processes sea --> veg
    if vol(5,i+1) == 0
        umatrix(5,3,1,subs) = 0;
        umatrix(5,3,2,subs) = 0;
        umatrix(5,3,3,subs) = 0;
        umatrix(5,3,4,subs) = 0;
    else
        if SizeDif
            umatrix(5,3,1,subs) = (phiFine(season,i,subs) * v35wetFine + phiCoarse(season,i,subs) * v35wetCoarse) * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season)); % air --> veg: wet part.dep
            umatrix(5,3,2,subs) = (phiFine(season,i,subs) * v35dryFine + phiCoarse(season,i,subs) * v35dryCoarse) * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season)); % air --> veg: dry part.dep
        else
            umatrix(5,3,1,subs) = phi(season,i,subs) * v35wet * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season));  % air --> veg: wet part.dep
            umatrix(5,3,2,subs) = phi(season,i,subs) * v35dry * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season));  % air --> veg: dry part.dep
        end
        umatrix(5,3,3,subs) = (1-phi(season,i,subs)) * v35diff * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season)); % air --> veg: diff.in
        umatrix(5,3,4,subs) = (1-phi(season,i,subs)) * v35rain * vol(3,i+1)/(vol(5,i+1)*vegvolfactor(i,season)); % air --> veg: gaseous rain scav.
    end
    umatrix(5,4,1,subs) = 0; % no transfer process vs --> veg; no root uptake
    umatrix(5,5,1,subs) = -v53diff; % veg --> air: diff.out
    umatrix(5,5,2,subs) = -v54leavefall; % veg --> vs: leaf.fall
    % dVeg: snow & ice
    umatrix(5,6,1,subs) = 0;                                                                  % no transfer processes ice --> veg
    umatrix(5,7,1,subs) = 0;
    % no transfer processes snow --> veg
    
    %%%%%%%%%%%%%%%%%%%
    % dcIce / dt = ....
    umatrix(6,1,1,subs) = 0;                                                                   % no transfer processes bs --> ice
    umatrix(6,2,1,subs) = 0;                                                                   % no transfer processes sea --> ice
    if vol(6,i+1) ~= 0 && icevolfactor(i,season) ~=   0
        if SizeDif
		umatrix(6,3,2,subs) = (phiFine(season,i,subs) * v36dryFine + phiCoarse(season,i,subs) * v36dryCoarse) * vol(3,i+1)/(vol(6,i+1) * icevolfactor(i,season));
		umatrix(6,3,4,subs) = (phiFine(season,i,subs) * v36wetFine + phiCoarse(season,i,subs) * v36wetCoarse) * vol(3,i+1)/(vol(6,i+1) * icevolfactor(i,season));
	else
		umatrix(6,3,2,subs) = (phi(season,i,subs) * v36dry * vol(3,i+1))/(vol(6,i+1) * icevolfactor(i,season));           % air --> ice:  par.dep.dry  Missing 
		umatrix(6,3,4,subs) = (phi(season,i,subs) * v36wet * vol(3,i+1))/(vol(6,i+1) * icevolfactor(i,season));            % air --> ice: par.dep.wet
	end
	umatrix(6,3,1,subs) = ((1-phi(season,i,subs)) * v36diff * vol(3,i+1))/(vol(6,i+1) * icevolfactor(i,season));      % air --> ice: diff.out
        umatrix(6,3,3,subs) = ((1-phi(season,i,subs)) * v36rain * vol(3,i+1))/(vol(6,i+1) * icevolfactor(i,season));      % air --> ice: gas.dep.wet
    else
        umatrix(6,3,2,subs) = 0;
        umatrix(6,3,4,subs) = 0;
        umatrix(6,3,3,subs) = 0;
        umatrix(6,3,1,subs) = 0;
    end
    umatrix(6,4,1,subs) = 0;                                                                                               % no transfer processes vs --> ice
    umatrix(6,5,1,subs) = 0;                                                                                               % no transfer processes veg --> ice
    umatrix(6,6,1,subs) = - v63diff;                            
    % ice --> air: diff.in

    
    %%%%%%%%%%%%%%%%%%%%
    % dcSnow / dt = ....
    umatrix(7,1,1,subs) = 0;                                                                                             % no transfer processes bs --> snow
    umatrix(7,2,1,subs) = 0;                                                                                             % no transfer processes sea --> snow
    if vol(7,i+1) ~= 0 && snowvolfactor(i,season) ~= 0
        if SizeDif
            umatrix(7,3,2,subs) = (phiFine(season,i,subs)*v37dryFine + phiCoarse(season,i,subs)*v37dryCoarse)* vol(3,i+1)/(vol(7,i+1) * snowvolfactor(i,season));                 % air --> snow: par.dep.dry
            umatrix(7,3,4,subs) = (phiFine(season,i,subs)*v37wetFine + phiCoarse(season,i,subs)*v37wetCoarse)* vol(3,i+1)/(vol(7,i+1) * snowvolfactor(i,season));                  % air --> snow: par.dep.wet
        else
            umatrix(7,3,2,subs) = (phi(season,i,subs)*v37dry * vol(3,i+1))/(vol(7,i+1) * snowvolfactor(i,season));                 % air --> snow: par.dep.dry
            umatrix(7,3,4,subs) = (phi(season,i,subs)*v37wet * vol(3,i+1))/(vol(7,i+1) * snowvolfactor(i,season));                  % air --> snow: par.dep.wet
        end
        umatrix(7,3,1,subs) = ((1-phi(season,i,subs)) * v37diff * vol(3,i+1))/(vol(7,i+1) * snowvolfactor(i,season));          % air --> snow: diff.out
        umatrix(7,3,3,subs) = ((1-phi(season,i,subs)) * v37rain * vol(3,i+1))/(vol(7,i+1) * snowvolfactor(i,season));          % air --> snow: gas.dep.wet
    else
        umatrix(7,3,1,subs) = 0;
        umatrix(7,3,2,subs) = 0;
        umatrix(7,3,3,subs) = 0;
        umatrix(7,3,4,subs) = 0;
    end
    umatrix(7,4,1,subs) = 0;                                                         % no transfer processes vs --> snow
    umatrix(7,5,1,subs) = 0;                                                         % no transfer processes veg --> snow
    umatrix(7,6,1,subs) = 0;                                                         % no transfer processes ice --> snow
    umatrix(7,7,1,subs) = - v73diff;                                                 % snow --> air diff.in
    umatrix(7,7,2,subs) = - v71runoff;                                               % meltwater runoff snow --> bs
    umatrix(7,7,3,subs) = - v72runoff;                                               % meltwater runoff snow --> water
    umatrix(7,7,4,subs) = - v74runoff;                                               % meltwater runoff snow --> vs


    %%%%%% 11. SUMMING UP UMATRIX TO GET VMATRIX %%%%%%
    vmatrix = sum(umatrix(:,:,:,subs),3); % sum in 3rd dimension of matrix

    %%%%%%% Copy the umatrix into fluxPTab vector for later mass flux
    %%%%%%% calcs if necessary
    if OPmasflu ~= 0 && i == fluxInTab(fluxInd)
        makefluxptabv;
        if fluxInd ~= OPmasflu
            fluxInd = fluxInd + 1;
        end
    end

    %%%%%% 12. TRANSFER VMATRIX INTO VGROSS (FOR ALL n) %%%%%%
    for i1=1:nphases
        for i2=1:nphases
            vgross(i+(i1-1)*n,i+(i2-1)*n,subs)=vmatrix(i1,i2);
        end
    end
end

if nAlps ~= 0
    modalpsv;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function modalpsv
% MODALPSV enlarges & modifies the vgross matrix by the additional
% rows/columns that are needed to describe the alpine zones.
% xxx the alpine module has not been finalized/tested and should not be
% used without considerable care! xxx

global n nGZ vgross nphases hsoil hgas vol season fracairsoil fracwsoil;
global scavratio vgasS StabVecBS vwet vdry vleach vrunoff umatrix screMsg;
global AlpsDat nAlps umatrixAlps phiAlps k32pureAlps k12pureAlps k31Alps;

if screMsg
    disp(' ')
    disp('function modalpsv: enlarges & modifies the vgross matrix for Alps');
end

AlpsZone = nAlps*n; % in dat zone is da alps

for i = 1:nGZ

    umatrixAlps = zeros(nphases,nphases,2);

    % (fabios)HACK: 
    % (fabios)HACK(again):
    baresoilpart = 1;
    waterpart = 0;
    % /HACK]
    % HACK:
    vegsoilpart = 0;
    a13vol1 = baresoilpart / (baresoilpart*hsoil);
    a13vol3 = baresoilpart / ((baresoilpart+waterpart+vegsoilpart)*hgas);

    % AIR --> BS: GasDep:
    % calculation of v31diff
    % new calculation of vtotSGbare, including bio.turbatio & atmos.
    % Stability
    DG = (fracairsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.43; % m2/d
    DL = (fracwsoil^(10/3)/((fracairsoil+fracwsoil)^2))*0.000043; % m2/d
    DS = 5.5E-7; % m2/d
    vG = DG / (hsoil/2) * (k32pureAlps(season,i)/((1-fracwsoil-fracairsoil)*...
        k12pureAlps(season,i)+fracwsoil+fracairsoil*k32pureAlps(season,i)));
    vL = DL / (hsoil/2) * 1 /((1-fracwsoil-fracairsoil)*k12pureAlps(season,i)+...
        fracwsoil+fracairsoil*k32pureAlps(season,i));
    vS = DS / (hsoil/2) * (k12pureAlps(season,i) /((1-fracwsoil-fracairsoil)*...
        k12pureAlps(season,i)+fracwsoil+fracairsoil*k32pureAlps(season,i)));
    vtotsoilneu = vG + vL/k32pureAlps(season,i) + vS/(k32pureAlps(season,i)/...
        k12pureAlps(season,i));
    vtotSGbare = (1/(vgasS/StabVecBS(AlpsZone,season))+1/vtotsoilneu)^-1;
    v31diff = vtotSGbare * a13vol3;
    umatrixAlps(1,3,3) = (1-phiAlps(season,i)) * v31diff * vol(3,n+2+i) /...
        vol(1,n+2+i);
    umatrixAlps(3,3,9) = -(1-phiAlps(season,i)) * v31diff; % air --> bs: diff.out

    % AIR --> BS: GasWet:
    v31rain = AlpsDat(i,4) * a13vol3 / k32pureAlps(season,i);
    umatrixAlps(1,3,4) = (1-phiAlps(season,i)) * v31rain * vol(3,n+2+i)/vol(1,n+2+i);
    umatrixAlps(3,3,10) = -(1-phiAlps(season,i)) * v31rain; % air --> bs: gas.dep.wet

    % AIR --> BS: ParDepWet:
    vwet = AlpsDat(i,4)*scavratio;
    v31wet = vwet * a13vol3;
    umatrixAlps(1,3,1) = phiAlps(season,i) * v31wet * vol(3,n+2+i)/vol(1,n+2+i);
    umatrixAlps(3,3,1) = -phiAlps(season,i) * v31wet; % air --> bs: par.dep.wet

    % AIR --> BS: ParDepDry:
    v31dry = vdry / StabVecBS(AlpsZone,season) * a13vol3;
    umatrixAlps(1,3,2) = phiAlps(season,i) * v31dry * vol(3,n+2+i)/vol(1,n+2+i);
    umatrixAlps(3,3,2) = -phiAlps(season,i) * v31dry; % air --> bs: par.dep.dry

    % BS --> AIR: Revol:
    v13diff = k31Alps(season,i) * vol(3,n+2+i) * v31diff / vol(1,n+2+i);
    umatrixAlps(1,1,3) = -v13diff; % bs --> air: gas diff.out
    umatrixAlps(3,1,1) = v13diff * vol(1,n+2+i)/vol(3,n+2+i); % bs --> air: diff.in

    % BS --> SEA: Leach --> Motherzone
    umatrix(1,1,1) = -a13vol1 * vleach/k12pureAlps(season,i); % bs --> sea: leaching
    umatrix(2,1,1) = a13vol1 * vleach/k12pureAlps(season,i) *...
        vol(1,n+2+i)/vol(2,AlpsZone+1); % LEACHING INTO SEA OF MOTHERZONE !!!!

    % BS --> SEA: RunOff --> Motherzone
    umatrixAlps(1,1,2) = -a13vol1 * vrunoff; % bs --> sea: runoff
    umatrixAlps(2,1,2) = a13vol1 * vrunoff * vol(1,n+2+i)/vol(2,AlpsZone+1);


    %%%%%%%%% SUM UP ALL INDIVIDUAL UMATRIX PROCESSES TO GET VMATRIXALPS:
    vmatrixAlps = sum(umatrixAlps,3); % sum in 3rd dimension of matrix

    % BS <-- AIR: all processes: non-diagonal element
    vgross(5*n+(i-1)*nphases+1,5*n+(i-1)*nphases+3) = vmatrixAlps(1,3);
    % AIR --> BS: all loss processes: diagonal element
    vgross(5*n+(i-1)*nphases+3,5*n+(i-1)*nphases+3) = vmatrixAlps(3,3);

    % BS --> AIR,SEA: all loss processes: diagonal element
    vgross(5*n+(i-1)*nphases+1,5*n+(i-1)*nphases+1) = vmatrixAlps(1,1);
    % AIR <-- BS: revol inflow process
    vgross(5*n+(i-1)*nphases+3,5*n+(i-1)*nphases+1) = vmatrixAlps(3,1);
    % SEA <-- BS: all processes; additive to mother zone !!!!
    vgross(1*n+AlpsZone,5*n+(i-1)*nphases+1) = ...
        vgross(1*n+AlpsZone,5*n+(i-1)*nphases+1) + vmatrixAlps(2,1);

    % hier käme die FLUXBEHANDLUNG 

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makem
% MAKEM2 creates the LRT and degrad.matrix. It is rewritten to better
% populate the fluxPTab vector. The specific kinetic process parameters are
% first stored in a 3D p-Matrix and then summarized to the 2D mx matrices,
% which are afterwards inserted into the large m matrix. The signs of the
% matrix elements are inverted to represent losses with negative k's and
% inputs with positive k's. Make sure that in dynamike() dyn = vgross + m

global n season m nphases DeddyTab fluxInd vol s2d dwater lenghalfMer;
global ksoil ksoilphoto Easoil R t0 TWaterLim kwat kwatphoto Eawat kair;
global kairphoto Eaair cOH deepice ddf_I solarrad;
global sintpar3 phi phisuspw fluxInTab tmp hice k26 icevolfactor nseasons;
global DeepSeaVelociTab hwater listind kveg Eaveg pmatrix degDeplFacs;
global nameSub OPmasflu nAlps nGZ dTAtmos seas_zonal_surftype transCoeff;
global subs nsubs degrad kice ksnow iceandsnow molmass OPLRTDeg screMsg;
global deepSeaWater deepSeaWaterTab degratio lex ldep;

if screMsg
    disp(' ');
    disp2('function makem: creates the transport and degradation matrix for',char(nameSub(subs,:)));
end

m1 = repmat(0,n,n+2);
m2 = repmat(0,n,n+2);
m3 = repmat(0,n,n+2);
m4 = repmat(0,n,n+2);
m5 = repmat(0,n,n+2);
m6 = repmat(0,n,n+2);
m7 = repmat(0,n,n+2);

if subs==1
    m = repmat(0,[nphases*(n+nGZ),nphases*(n+nGZ),nsubs]);
end

temp1 = 0;
temp2 = 0;
temp3 = 0;
temp4 = 0;
temp5 = 0;
temp6 = 0;

fluxInd = 1;

for i = 1:n
    pmatrix = zeros(nphases, 3, 2, nsubs); % 3 to hold diag.elem., LRT.left & right

    d1 = 0;
    d2 = s2d*dwater/(lenghalfMer/n)^2;
    d3 = s2d*DeddyTab(i)/(lenghalfMer/n)^2;

    Tact = tmp(season, i);
    if Tact < TWaterLim
        Twater = TWaterLim;
    else
        Twater = Tact;
    end

    if Tact > 273.15 && Tact - 10 <= 273.15     % xjudithx : gibt es auch in makeggw, vielleicht könnte man das nur 1mal machen?
        tI = Tact - 10;
        tS = Tact - 10;
    elseif Tact > 273.15 && Tact - 10 > 273.15
        tI = 273.15;
        tS = 273.15;
    else
        tI = Tact - 2;
        tS = Tact - 2;
    end

    k1 = ksoil(subs)*exp(-Easoil(subs)/R*(1/Tact - 1/t0));
    k1p=ksoilphoto(subs)*solarrad(i,season)*ldep;
    k2 = kwat(subs)*exp(-Eawat(subs)/R*(1/Twater - 1/t0));
    k22 = (DeepSeaVelociTab(i)/hwater)*phisuspw(season, i,subs);
    k2p = kwatphoto(subs)*solarrad(i,season)*(1-phisuspw(season, i,subs));
    if deepSeaWater             % deepseawater formation is switched on
        k222 = deepSeaWaterTab(i);
    else
        k222 = 0;
    end
    k3 = kair(subs)*cOH(season,i)*exp(-Eaair(subs)/R*(1/(Tact-dTAtmos(season,i))-1/t0));
    k3p = kairphoto(subs)*solarrad(i,season);
    k4 = k1; % same degradation rate both in vegetation soil and bare soil *) photolytic degradation 10% degradation in bare soil, included directly in degradation matrix and flux matrix
    k5 = kveg(subs)*exp(-Eaveg(subs)/R*(1/Tact - 1/t0));


    if iceandsnow
        k6 = kice(subs)*exp(-Eawat(subs)/R*(1/tI - 1/t0));
        Tact_C = Tact - 273.15;
        areaicepart            = seas_zonal_surftype(i,6,season);

        if areaicepart ~= 0
            a63vol2 = seas_zonal_surftype(i,6,season)/(areaicepart * hice);
        else
            a63vol2 = 0;
        end
        if Tact_C > 0
            runoff_ice = ddf_I * Tact_C;
        else
            runoff_ice = 0;
        end
        % the nnz (number of non-zero elements) is preferred over the
        % initial construction if nseasons ~= 4...
        if nnz(icevolfactor(i,:)) < nseasons                                % icevolfactor(i,1) == 0 || icevolfactor(i,2) == 0 || icevolfactor(i,3) == 0 || icevolfactor(i,4) == 0
            k66 = 0;
        elseif nnz(icevolfactor(i,:)) == nseasons && runoff_ice ~= 0        % icevolfactor(i,1) ~= 0 && icevolfactor(i,2) ~= 0 && icevolfactor(i,3) ~= 0 && icevolfactor(i,4) ~= 0 && runoff_ice ~= 0
            v62runoff = runoff_ice * k26(season,i,subs) * a63vol2/2;
            k66 = deepice/hice + v62runoff;
        else
            k66 = deepice/hice;
        end
        k7 = ksnow(subs)*exp(-Eawat(subs)/R*(1/tS - 1/t0));
    else
        k6  = 0;
        k66 = 0;
        k7  = 0;
    end

    % degDeplFacs are stored for the cockpit report evaluation
    degDeplFacs(i,season,subs,:)= - [k1 + k1p,k2 + k2p,k3*(1-phi(season,i,subs))+ (k3p*(1-phi(season,i,subs))*2+ k3p*(phi(season,i,subs))/62.4),k4+lex*k1p,k5,k6+k66,k7,k22+k222]; 
    % Aerosols: degradation rate constant in solvent is given 
    % - degradation in aerosols is 62.4 times slover
    % - degradation in gas phase is 2 times faster (see Schenker et al,
    % 2008)
    % xxx currently, deep ice runoff (k66) is considered as a degradation 
    % flux instead of a depletion flux for the cockpitReport massflux
    % evaluation - this is not very important, but could be changed xxx

    % degratio is the ratio of non-photolytic degradation per total
    % degradation and is needed to take into account different fofs for
    % photolytic and non-photolytic degradation in the calculation of
    % degradation products
    % to avoid errors div0 when kx and kxp = 0
    warning('off','all');
    degratio(i,season,subs,:)= [k1/(k1+k1p),k2/(k2+k2p),(k3*(1-phi(season,i,subs)))/(k3*(1-phi(season,i,subs))+ k3p*(1-phi(season,i,subs))*2+ k3p*(phi(season,i,subs))/62.4),k4/(k4+lex*k1p),1,1,1];
    warning('on','all');

    if sum(isnan(degratio(i,season,subs,:)))>0
        for j=1:7
            if isnan(degratio(i,season,subs,j))
                degratio(i,season,subs,j)=0;
            end
        end
    end


    if OPLRTDeg
        % write the values to file <sintpar3>
        fprintf(sintpar3(subs), '%d \t%d \t%1.3g \t%1.3g \t',listind,i,Tact,Twater);
        % d values are always between the two zones, therefore the sum of
        % d(i-1) = temp1/temp3/temp5 and d(i)=d has to be taken, except for i=1 & i=n
        warning off;
        if i==1
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t',d1,d2,d3,k1,k2,k3);
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \n',d1/k1,d2/k2,d3/k3);
        elseif i==n
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t',temp1,temp3,temp5,k1,k2,k3);
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \n',temp1/k1,temp3/k2,temp5/k3);
        else
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t',temp1+d1,temp3+d2,temp5+d3,k1,k2,k3);
            fprintf(sintpar3(subs),'%1.3g \t%1.3g \t%1.3g \n',(temp1+d1)/k1,(temp3+d2)/k2,(temp5+d3)/k3);
        end
        warning on;
    end

    if vol(1,i) == 0
        fslinksher = 0;
    else
        fslinksher = sqrt(vol(1,i+1)/vol(1, i));
    end
    if vol(1,i+1) == 0
        fslinkshin = 0;
    else
        fslinkshin = sqrt(vol(1,i)/vol(1,i+1));
    end
    if vol(1,i+2) == 0
        fsrechtsher = 0;
    else
        fsrechtsher = sqrt(vol(1,i+1)/vol(1,i+2));
    end
    if vol(1,i+1) == 0
        fsrechtshin = 0;
    else
        fsrechtshin = sqrt(vol(1,i+2)/vol(1,i+1));
    end

    fwlinksher = sqrt(vol(2,i+1)/vol(2,i));
    fwlinkshin = sqrt(vol(2,i)/vol(2,i+1));
    fwrechtsher = sqrt(vol(2,i+1)/vol(2,i+2));
    fwrechtshin = sqrt(vol(2,i+2)/vol(2,i+1));
    fglinksher = sqrt(vol(3,i+1)/vol(3,i));
    fglinkshin = sqrt(vol(3,i)/vol(3,i+1));
    fgrechtsher = sqrt(vol(3,i+1)/vol(3,i+2));
    fgrechtshin = sqrt(vol(3,i+2)/vol(3,i+1));

    temp2 = temp1;
    temp1 = d1;
    temp4 = temp3;
    temp3 = d2;
    temp6 = temp5;
    temp5 = d3;

    %%%%%%%%%%%
    % AB HIER COD FUER PMATRIX....

    % dBS / dt = ...   (0 because no transport in soil)
    pmatrix(1,2,1,subs) = -k1; % deg.bs
    pmatrix(1,2,2,subs) = -temp1*fsrechtshin; % LRT.bs:  i-->i+1
    pmatrix(1,2,3,subs) = -temp2*fslinkshin; % LRT.bs:  i-1<--i
    pmatrix(1,2,4,subs) = -k1p;

    m1(i,i+1) = sum(pmatrix(1,2,:,subs));

    if vol(1,i+1) == 0
        pmatrix(1,3,1,subs) = 0;
    else
        pmatrix(1,3,1,subs) = +temp1 * fsrechtsher * vol(1,i+2)/vol(1,i+1);
        % LRT.bs:  i<--i+1
    end
    m1(i,i+2) = sum(pmatrix(1,3,:,subs));

    if vol(1,i+1) == 0
        pmatrix(1,1,1,subs) = 0;
    else
        pmatrix(1,1,1,subs) = +temp2*fslinksher*vol(1,i)/vol(1,i+1);
    end
    m1(i,i) = sum(pmatrix(1,1,:,subs));

    % dSEA / dt = ...
    pmatrix(2,2,1,subs) = -k2; % deg. microbial sea
    pmatrix(2,2,2,subs) = -k22; % deep sea particle dep
    pmatrix(2,2,3,subs) = -temp3*fwrechtshin; % LRT sea:  i-->i+1
    pmatrix(2,2,4,subs) = -temp4*fwlinkshin; % LRT sea:  i-1<--i
    pmatrix(2,2,5,subs) = -k2p; % deg. photolytic sea
    pmatrix(2,2,6,subs) = -k222; % deep sea water formation

    m2(i,i+1) = sum(pmatrix(2,2,:,subs));

    pmatrix(2,3,1,subs) = temp3 * fwrechtsher * vol(2,i+2)/vol(2,i+1);
    m2(i,i+2) = sum(pmatrix(2,3,:,subs));

    pmatrix(2,1,1,subs) = temp4 * fwlinksher * vol(2,i)/vol(2,i+1);
    m2(i,i) = sum(pmatrix(2,1,:,subs));

    % create transCoeff Matrix for cockpitReport.xls
    % initialize as zero to start...
    transCoeff(i,season,subs,:,:) = zeros(1,1,1,nphases,4);
    % store water in- / out- coefficients for water
    transCoeff(i,season,subs,2,:) = [squeeze(pmatrix(2,2,3:4,subs));...
        squeeze(pmatrix(2,1:2:3,1,subs))'];

    % dAIR / dt = ...
    pmatrix(3,2,1,subs) = -k3*(1-phi(season,i,subs)); % OH-deg.air
    pmatrix(3,2,2,subs) = -temp5*fgrechtshin; % LRT.air:  i-->i+1
    pmatrix(3,2,3,subs) = -temp6*fglinkshin; % LRT.air  i-1<--i
    pmatrix(3,2,4,subs) = -(k3p*(1-phi(season,i,subs))*2+ k3p*(phi(season,i,subs))/62.4); % photolytic deg.air

    m3(i,i+1) = sum(pmatrix(3,2,:,subs));

    pmatrix(3,3,1,subs) = temp5 * fgrechtsher * vol(3,i+2)/vol(3,i+1);
    m3(i,i+2) = sum(pmatrix(3,3,:,subs));

    pmatrix(3,1,1,subs) = temp6 * fglinksher * vol(3,i)/vol(3,i+1);
    m3(i,i) = sum(pmatrix(3,1,:,subs));

    % store water in- / out- coefficients for atmosphere
    transCoeff(i,season,subs,3,:) = [squeeze(pmatrix(3,2,2:3,subs));...
        squeeze(pmatrix(3,1:2:3,1,subs))'];

    % dVS / dt = ...      (no LRT in VS)
    pmatrix(4,2,1,subs) = -k4;
    pmatrix(4,2,2,subs) = -lex*k1p;
    m4(i,i+1) = sum(pmatrix(4,2,:,subs));

    % dVEG / dt = ...      (no LRT in VEG)
    pmatrix(5,2,1,subs) = -k5;
    m5(i,i+1) = sum(pmatrix(5,2,:,subs));

    % dIce / dt = ...      (no LRT in ICE)
    pmatrix(6,2,1,subs) = -k6;
    pmatrix(6,2,2,subs) = -k66;
    m6(i,i+1) = sum(pmatrix(6,2,:,subs));

    % dSnow / dt = ...      (no LRT in SNOW)
    pmatrix(7,2,1,subs) = -k7;
    m7(i,i+1) = sum(pmatrix(7,2,:,subs));

    % copy parameters into fluxPTab for FLUXCALCS
    if OPmasflu ~= 0 && fluxInTab(fluxInd) == i
        makefluxptabm;
        if fluxInd ~= OPmasflu
            fluxInd = fluxInd + 1;
        end
    end

    degrad(subs,1,i,season)=(k1+k1p)/molmass(subs)*1000;         % used for the dyn-matrix fofs-part
    degrad(subs,2,i,season)=(k2+k2p)/molmass(subs)*1000;
    degrad(subs,3,i,season)=(k3*(1-phi(season,i,subs))+ k3p*(1-phi(season,i,subs))*2 + k3p*(phi(season,i,subs))/62.4)/molmass(subs)*1000;
    degrad(subs,4,i,season)=(k4+lex*k1p)/molmass(subs)*1000;
    degrad(subs,5,i,season)=k5/molmass(subs)*1000;
    degrad(subs,6,i,season)=k6/molmass(subs)*1000;
    degrad(subs,7,i,season)=k7/molmass(subs)*1000;
end

% correction for zone n: no LRT.rechtshin
m1(n,n+1) = -k1 - k1p - temp2*fslinkshin;
m2(n,n+1) = -k2 - k2p - k22 - k222 - temp4*fwlinkshin;
m3(n,n+1) = -k3*(1-phi(season,n,subs)) - (k3p*(1-phi(season,i,subs))*2+ k3p*(phi(season,i,subs))/62.4) - temp6*fglinkshin;
% correction in transCoeff for cockpitReport massfluxes: no transport north
% of the Arctic and south of Antarctica
transCoeff(1,season,subs,2:3,2:3)=zeros(2,2);
transCoeff(n,season,subs,2:3,1:3:4)=zeros(2,2);

% cutoff left-&rightmost columns and copy into m
m(1:n,1:n,subs) = m1(1:n,2:n+1);
m(n+1:2*n, n+1:2*n,subs) = m2(1:n,2:n+1);
m(2*n+1:3*n, 2*n+1:3*n,subs) = m3(1:n,2:n+1);
m(3*n+1:4*n, 3*n+1:4*n,subs) = m4(1:n,2:n+1);
m(4*n+1:5*n, 4*n+1:5*n,subs) = m5(1:n,2:n+1);
m(5*n+1:6*n, 5*n+1:6*n,subs) = m6(1:n,2:n+1);

if iceandsnow
    m(6*n+1:7*n, 6*n+1:7*n,subs) = m7(1:n,2:n+1);
end

if nAlps ~= 0
    modalpsm;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function modalpsm
% MODALPSM enlarges & modifies the m-matrix by the additional
% rows/columns that are needed to describe the alpine zones.
% xxx the alpine module has not been finalized/tested and should not be
% used without considerable care! xxx

global n season m nphases DeddyTab vol s2d kveg Eaveg nGZ AlpsDat nAlps;
global ksoil Easoil R t0 kwat Eawat kair Eaair cOH tmp phiAlps;
global screMsg subs nsubs;

if screMsg
    disp(' ');
    disp('function modalpsm: enlarges & modifies the m-matrix for Alps');
end

AlpsZone = nAlps*n; % in dat zone is da alps

%
%%%%%%%%%% ONLY FOR nGZ = 1 DEFINED, CURRENTLY!!!
%
if nGZ > 1
    diary off;
    fclose all;    
    error('modalpsm: a maximum of 1 Alpine zones is currently supported!');
end

for i = 1:nGZ  % currently unnecessary but anyway...

    pmatrixAlps = zeros(nphases,3,2,nsubs);
    TmpAlps = tmp(season,AlpsZone) + AlpsDat(i,3); % AlpsDat(i,3) = dT

    % LONGRANGE TRANSPORT
    % calculation of da DEddy parameter, probably needs improvement
    % no LRT in water...
    % original:
    % d3 = s2d*DeddyTab(AlpsZone)/(lenghalfMer/n)^2;
    % since GZwidth is in AlpsDat:
    d3 = s2d*DeddyTab(AlpsZone)/AlpsDat(i,2)^2;
    fgAlpsZoneHin = sqrt(vol(3,AlpsZone+1) / vol(3,n+2+i));
    fgAlpsZoneHer = sqrt(vol(3,n+2+i) / vol(3,AlpsZone+1));

    % DEGRADATION
    k1 = ksoil*exp(-Easoil/R*(1/TmpAlps - 1/t0));
    k2 = kwat*exp(-Eawat/R*(1/TmpAlps - 1/t0));
    k3 = kair*cOH(season,i)*exp(-Eaair/R*(1/TmpAlps-1/t0));
    k4 = k1; % same degradation rate both in vegetation soil and bare soil *)
    k5 = kveg*exp(-Eaveg/R*(1/TmpAlps - 1/t0));

    % POPULATE THE pMATRIXALPS
    % losses:
    pmatrixAlps(1,2,1,subs) = -k1; % deg.bs
    pmatrixAlps(3,2,1,subs) = -k3*(1-phiAlps(season,i)); % deg.air
    pmatrixAlps(3,2,2,subs) = -d3*fgAlpsZoneHin; % LRT.air: GZ --> AlpsZone
    % gains: HIN oder HER noch nicht ganz klar...
    pmatrixAlps(3,1,1,subs) = +d3*fgAlpsZoneHer*vol(3,AlpsZone+1)/vol(3,n+2+i); % REALLY fgAlpsZoneHer???? 
    pmatrixAlps(3,3,1,subs) = -d3*fgAlpsZoneHin; % LRT.air: AlpsZone --> GZ
    pmatrixAlps(3,4,1,subs) = +d3*fgAlpsZoneHer*vol(3,AlpsZone+1)/vol(3,n+2+i);

    % ENTER IN THE m-MATRIX   :-)
    %
    % m is enlarged from dimensions (5n x 5n) by nGZ bands of nphases = 5
    % rows/columns each to represent 5 compartments in each GZ
    %
    % Entries for the GZ: (diagonalelement: losses)
    % --- bare.soil: deg
    m(5*n+(i-1)*nphases+1,5*n+(i-1)*nphases+1) = sum(pmatrixAlps(1,2,:,subs));
    % --- air: deg + LRT.GZ-->AlpsZone
    m(5*n+(i-1)*nphases+3,5*n+(i-1)*nphases+3) = sum(pmatrixAlps(3,2,:,subs));
    %
    % Entries for the AlpsZone: (non-diagonal: gains)
    m(2*n+AlpsZone,5*n+(i-1)*nphases+3) = sum(pmatrixAlps(3,1,:,subs));
    %
    % AlpsZone: (diagonal entry:loss) LRT.AlpsZone-->GZ
    m(2*n+AlpsZone,2*n+AlpsZone) = m(2*n+AlpsZone,2*n+AlpsZone) + ...
        sum(pmatrixAlps(3,3,:,subs));
    %
    % AlpsZone: (non-diagonal entry:gain) LRT.GZ-->AlpsZone
    m(5*n+(i-1)*nphases+3,2*n+AlpsZone) = sum(pmatrixAlps(3,4,:,subs));


    %%%%%%%%%%%%%%
    % hier käme die FLUXBEHANDLUNG 
    %%%%%%%%%%%%%%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dynamike
% DYNAMIKE solves CliMoChem

global n season nphases firstRun elist year nseasons listind;
global c0 exposure dpy exposmax exposmaxt saddexp scumexp nGZ peakEmis;
global sctnum2 mfexpos vol vegmod contEmis solveMode fofmat;
global screMsg screRes OPconexp OPGGWcqu degDeplFacs transCoeff;
global subs nsubs nameSub concenMatrix expaddMatrix expcumMatrix;
global ice iceandsnow lulist timeSteps OPZones concMatrix mfMatrix;
global leng ind_0 degratio startyear;

if screMsg
    disp(' ');
    disp('function dynamike: solves CliMoChem');
end

eignull = false;
negconc = false;

if listind == 1
	mfMatrix = zeros(nphases+1,nsubs,5,length(timeSteps),length(OPZones));
end

% ATTENTION c0 is reshaped here: instead of a matrix with dims
% [nphases*(n+nGZ),nsubs], it is a single, long vector. For the
% solving algorithm, c0 must have the same length as the dyn matrix!!!
% At the end of dynamike, this will be undone again.
c0=reshape(c0,nphases*(n+nGZ)*nsubs,1);

% also mfexpos, exposure, exposmax and exposmaxt are reshaped
mfexpos=reshape(mfexpos,nphases*(n+nGZ)*nsubs,1);
exposure=reshape(exposure,nphases*(n+nGZ)*nsubs,1);
exposmax=reshape(exposmax,nphases*(n+nGZ)*nsubs,1);
exposmaxt=reshape(exposmaxt,nphases*(n+nGZ)*nsubs,1);

% read the continuous emissions term
q=zeros(n*nphases*nsubs,1);
resizeContEmis = reshape(contEmis(listind,:,:),nphases*(n+nGZ)*nsubs,1);
resizeVol = reshape(vol(:,2:n+1)',nphases*n,1);
for i=1:nphases*n*nsubs             % not vectorized because of 0 in vol vectors
    if resizeVol(mod(i-1,nphases*n)+1) == 0
        q(i,1) = resizeContEmis(i);
    else
        q(i,1) = resizeContEmis(i) / resizeVol(mod(i-1,nphases*n)+1);
    end
end

t = dpy/nseasons;

if solveMode == 0
    if screMsg
        disp('Solving CliMoChem with the sum solver');
    end
    if sum(q) ~= 0
        diary off;
        fclose all;        
        error('dynamike: the sum-based solver mode cannot deal with continuous emissions, select the matrix mode or remove continuous emissions');
    end
    if firstRun

        dyn=makedyn;                        % function makedyn creates the dyn matrix from the vgross and m matrixes, and the fofs

        if screMsg
            disp('Eigen.system is being solved');
        end

        [ev,ew] = eig(dyn);
        elist(listind).ev = ev;
        elist(listind).ew = ew;
    else
        if screMsg
            disp2('Retrieve EigenVecs & -Values from elist, index:',listind - ...
                (year-1)*nseasons);
        end
        ev = elist(listind-(year-1)*nseasons).ev;
        ew = elist(listind-(year-1)*nseasons).ew;
    end

    if firstRun
        if screMsg
            disp('Compute LU decomposition of EigenVecs');
        end
        [L,U] = lu(ev);
        lulist(listind).l = L;
        lulist(listind).u = U;
    else
        if screMsg
            disp('Retrieve LU decomposition of EigenVecs from lrlist');
        end
        L = lulist(listind-(year-1)*nseasons).l;
        U = lulist(listind-(year-1)*nseasons).u;
    end

    if screMsg
        disp('Solve initial value problem for coefficients by division');
    end

    ypsilon=L\c0;
    konst=U\ypsilon;

    if OPGGWcqu
        storek(konst); % store konst value in file <skval>
    end

    maxExpos = 0; % maximal exposure this season
    maxbox = 0; % #.box with maximal exposure this season
    expos = zeros(nphases*(n+nGZ)*nsubs,1);

    if screRes
        disp('c0: (not reshaped: every substance in the same row)');
        disp(c0);
    end

    if OPconexp
        for subs=1:nsubs
            fprintf(sctnum2(subs),'\n');
            fprintf(scumexp(subs),'\n');
            fprintf(saddexp(subs),'\n');
            fprintf(sctnum2(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 ct-numeric2.file
            fprintf(scumexp(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 exp-cum.file
            fprintf(saddexp(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 exp-add.file
        end
    end

    % loop to calculate c(t) and e(t) for all compartments
    for i = 1:nphases*(n+nGZ)*nsubs
        ct = 0;
        et = 0;

        t = dpy/nseasons;
        for j = 1:nphases*(n+nGZ)*nsubs
            ct = ct + konst(j)*ev(i,j)*exp(ew(j,j)*t);

            if ew(j,j) == 0
                eignull = true;
            else
                et = et + konst(j)*ev(i,j)/ew(j,j)*exp(ew(j,j)*t);
            end
        end

        eUpper = et;
        et = 0;

        % loop over all summmands per compartments, t = 0
        t = 0;
        for j = 1:nphases*(n+nGZ)*nsubs
            if ew(j,j) == 0
            else
                et = et + konst(j)*ev(i,j)/ew(j,j)*exp(ew(j,j)*t);
            end
        end

        eLower = et;
        expos(i) = eUpper - eLower;
        mfexpos(i) = expos(i); % store seasonal exp.add for integr.mass.flux.calc

        exposure(i) = exposure(i) + expos(i);
        if real(expos(i)) > exposmax(i)
            exposmax(i) = real(expos(i));
            exposmaxt(i) = listind;
        end
        if real(expos(i)) > real(maxExpos)
            maxExpos = expos(i);
            maxbox = i;
        end

        c0(i) = real(ct);
        if c0(i) < 0  || real(expos(i)) < 0
            negconc = true;
        end

        substance=floor((i-1)/(nphases*(n+nGZ)))+1;                              % only locally used to write values into the right files

        if OPconexp
            fprintf(saddexp(substance),'  %1.3g \t',real(expos(i)));
            fprintf(scumexp(substance),'  %1.3g \t',real(exposure(i)));
            fprintf(sctnum2(substance),'  %1.3g \t',c0(i));
        end
    end

    % store values in Matrixes for xls outputs
    concenMatrix(listind,:)=c0;
    expcumMatrix(listind,:)=exposure;
    expaddMatrix(listind,:)=expos;

elseif solveMode == 1
    if screMsg
        disp('Solving CliMoChem with the direct matrix solver');
    end

    crop_meth=1;

    if firstRun
        % function makedyn creates the dyn matrix from the vgross and m
        % matrixes, and the fofs
        dyn=makedyn;

        if listind == 1
            leng=length(diag(dyn));
            ind_0=zeros(leng,nseasons);
        end

        if crop_meth==1
            % for reasons of numerical stability, all lines / columns with 0
            % are removed from dyn. c0, q, and (later on) expos have to be
            % cropped, too. c0, q, and expos are uncropper further below


            for i=1:leng
                if sum(dyn(i,:)) == 0 && sum(dyn(:,i)) == 0
                    ind_0(i,listind-(year-1)*nseasons)=1;
                end
            end

            mat_temp=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)),leng);
            dyn2=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)));
            ind=1;

            for i=1:leng
                if ~ ind_0(i,listind-(year-1)*nseasons)
                    mat_temp(ind,:)=dyn(i,:);
                    ind=ind+1;
                end
            end

            ind=1;
            for i=1:leng
                if ~ ind_0(i,listind-(year-1)*nseasons)
                    dyn2(:,ind)=mat_temp(:,i);
                    ind=ind+1;
                end
            end

            c02=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)),1);
            q2=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)),1);
            ind=1;
            for i=1:leng
                if ~ ind_0(i,listind-(year-1)*nseasons)
                    c02(ind)=c0(i);
                    q2(ind)=q(i);
                    ind=ind+1;
                end
            end
            dyn=dyn2; c0=c02; q=q2;
        elseif crop_meth == 0
            % cropping the size of dyn and c0:
            % if no veg, or no snow/ice, dyn is usually singular and cannot be
            % inverted because of the rows/columns of 0. therefore, dyn is
            % cropped here, depending on whether veg or snow/ice is included or
            % not. in addition, this improves calculation speed (smaller
            % matrix) and numerical stability (matrix is less sparse)
            if iceandsnow
                % no cropping needed...
            else
                if screMsg
                    disp('dyn matrix is cropped to prevent singularity, c0, expos and q are adjusted in size');
                end
                olddyn=dyn;
                oldc0=c0;
                oldq=q;

                if ~ice
                    if vegmod == 0
                        newLength = 3*n;
                    else
                        newLength = 5*n;
                    end
                else
                    newLength = 6*n;
                end     % if snowice == 2, then no cropping is needed

                dyn=zeros(newLength*nsubs,newLength*nsubs);     % define new dimensions of dyn and c0
                c0=zeros(newLength*nsubs,1);
                q=zeros(newLength*nsubs,1);

                for i=1:nsubs       % extract each part of the old matrix after the other...
                    for j=1:nsubs
                        dyn((i-1)*newLength+1:i*newLength,(j-1)*newLength+1:j*newLength) ...
                            = olddyn((i-1)*n*nphases+1:(i-1)*n*nphases+newLength, ...
                            (j-1)*n*nphases+1:(j-1)*n*nphases+newLength);
                    end
                    c0((i-1)*newLength+1:i*newLength,1)=oldc0((i-1)*n*nphases+1:(i-1)*n*nphases+newLength);
                    q((i-1)*newLength+1:i*newLength,1)=oldq((i-1)*n*nphases+1:(i-1)*n*nphases+newLength);
                end

                clear olddyn; clear oldc0; clear oldq;
            end
        end

        % start the calculations
        if screMsg
            disp('Eigen.system is being solved');
        end

        % calculate level III solution (steady-state) if nseasons == 1
        if nseasons == 1 && OPconexp
            level_III(dyn,q);
        end

        [ev,ew] = eig(dyn);
        if rank(ev) ~= size(ew,1)
            warning('warning dynamike: rank(eigenvalues) ~= number of eigenvectors');
        end

        invMinusDyn=inv(-dyn);

        % construct the X-matrizes
        Xt=repmat(exp(diag(ew).*t)',size(dyn,1),1).*ev;
        invX0=inv(ev);
        Xt_invX0=Xt*invX0;

        % calculate the terms of the equations for c0 and expos
        term1 = Xt_invX0;
        term2 = invMinusDyn * (eye(size(Xt_invX0,1)) - Xt_invX0);
        term3 = invMinusDyn * (eye(size(Xt_invX0,1)) * t - term2);

        % store the matrix
        elist(listind).term1 = term1;
        elist(listind).term2 = term2;
        elist(listind).term3 = term3;

    else
        if screMsg
            disp2('Retrieve multiplication terms for c0 and expos from elist, index:',listind - ...
                (year-1)*nseasons);
        end
        term1 = elist(listind-(year-1)*nseasons).term1;
        term2 = elist(listind-(year-1)*nseasons).term2;
        term3 = elist(listind-(year-1)*nseasons).term3;

        if crop_meth == 1
            % cropping of c0 and q to fit dimensions of dyn...
            c02=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)),1);
            q2=zeros(leng-sum(ind_0(:,listind-(year-1)*nseasons)),1);
            ind=1;
            for i=1:leng
                if ~ ind_0(i,listind-(year-1)*nseasons)
                    c02(ind)=c0(i);
                    q2(ind)=q(i);
                    ind=ind+1;
                end
            end
            c0=c02; q=q2;
        elseif crop_meth == 0
            % here, only c0 has to be cropped (see above about cropping...)

            if iceandsnow
                % no cropping needed
            else
                oldc0=c0;
                oldq=q;

                if ~ice
                    if vegmod == 0
                        newLength = 3*n;
                    else
                        newLength = 5*n;
                    end
                else
                    newLength = 6*n;
                end

                c0=zeros(newLength*nsubs,1);
                q=zeros(newLength*nsubs,1);
                for i=1:nsubs       % extract each part of the old matrix after the other...
                    c0((i-1)*newLength+1:i*newLength,1)=oldc0((i-1)*n*nphases+1:(i-1)*n*nphases+newLength);
                    q((i-1)*newLength+1:i*newLength,1)=oldq((i-1)*n*nphases+1:(i-1)*n*nphases+newLength);
                end
                clear oldc0 oldq;
            end
        end
    end

    if screRes
        disp('c0: (not reshaped: every substance in the same row)');
        disp(c0);
    end

    if OPconexp
        for subs=1:nsubs
            fprintf(sctnum2(subs),'\n');
            fprintf(scumexp(subs),'\n');
            fprintf(saddexp(subs),'\n');
            fprintf(sctnum2(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 ct-numeric2.file
            fprintf(scumexp(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 exp-cum.file
            fprintf(saddexp(subs),'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind); % write season 2 exp-add.file
        end
    end

    if screMsg
        disp('Solve initial value problem for coefficients by division');
    end

    % calculate the c(t) solution
    c0old=c0;
    c0 = term1 * c0old + term2 * q;

    % calculate the exposure (time integrated concentration)
    expos = term2 * c0old + term3 * q;

    if crop_meth == 1
        % uncropping c0, q, and expos to their original size
        c02=zeros(leng,1);
        q2=zeros(leng,1);
        expos2=zeros(leng,1);
        ind=1;
        for i=1:leng
            if ~ ind_0(i,listind-(year-1)*nseasons)
                c02(i)=real(c0(ind));
                q2(i)=q(ind);
                expos2(i)=expos(ind);
                ind=ind+1;
            end
        end
        c0=c02; expos=expos2;
    elseif crop_meth == 0
        % "uncrop" c0 and expos to give them the original size (see beginning
        % of this "elseif" part)
        if iceandsnow
            % no uncropping needed
        else
            oldc0=c0;
            oldexpos=expos;
            c0=zeros(n*nphases*nsubs,1);
            expos=zeros(n*nphases*nsubs,1);
            for i=1:nsubs
                c0((i-1)*n*nphases+1:(i-1)*n*nphases+newLength) = oldc0((i-1)*newLength+1:i*newLength);
                expos((i-1)*n*nphases+1:(i-1)*n*nphases+newLength) = oldexpos((i-1)*newLength+1:i*newLength);
            end
            clear oldc0; clear oldexpos;
        end
    end

    exposure=exposure+expos;
    mfexpos=expos;          % store seasonal exposure add for massfluxes

    for i=1:n*nphases           % check for every box whether is is the highest exposure ever had in that box
        if real(expos(i)) > exposmax(i)
            exposmax(i) = real(expos(i));
            exposmaxt(i) = listind;
        end
    end

    maxExpos=max(expos);                % highest exposure in a box this season
    maxbox=find(expos==maxExpos);       % nr of box with highest exposure

    if sum(c0 < 0) > 0 || sum(real(expos) < 0) > 0
        negconc = true;
    end

    % printout of concentrations and expositions
    if OPconexp
        for subs = 1:nsubs
            fprintf(saddexp(subs),'  %1.3g \t',real(expos((subs-1)*n*nphases+1:subs*n*nphases)));
            fprintf(scumexp(subs),'  %1.3g \t',real(exposure((subs-1)*n*nphases+1:subs*n*nphases)));
            fprintf(sctnum2(subs),'  %1.3g \t',c0((subs-1)*n*nphases+1:subs*n*nphases));
        end
    end
end


c0=reshape(c0,nphases*(n+nGZ),nsubs);  % here, c0 and all the others are back-reshaped
mfexpos=reshape(mfexpos,nphases*(n+nGZ),nsubs);
exposure=reshape(exposure,nphases*(n+nGZ),nsubs);
exposmax=reshape(exposmax,nphases*(n+nGZ),nsubs);
exposmaxt=reshape(exposmaxt,nphases*(n+nGZ),nsubs);

if find(timeSteps == listind) ~= 0
    % write concMatrix for cockpitReport.xls
    for i = 1:nsubs
        concMatrix(:,:,i,find(timeSteps == listind)) = reshape(c0(:,i),(n+nGZ),nphases);
    end


    % write mfMatrix for cockpitReport.xls
    % vol is available, mfexpos is available degDeplFacs is available
    % initialize all values as zeros
%     mfMatrix(:,:,:,find(timeSteps == listind),:) = zeros(nphases+1,nsubs,5,1,length(OPZones));
    for i=1:nsubs
        for j=1:length(OPZones)
            % write degradation fluxes
            mfMatrix(1:nphases,i,1,find(timeSteps == listind),j) ...
                = vol(:,OPZones(j)+1) .* mfexpos(OPZones(j):n:(nphases-1)*n+OPZones(j),i) ...
                .* squeeze(degDeplFacs(OPZones(j),season,i,1:nphases));
            % summing all phases
            mfMatrix(nphases+1,i,1,find(timeSteps == listind),j) ...
                = sum(mfMatrix(1:nphases,i,1,find(timeSteps == listind),j));

            % write source fluxes
            % input from emission files
            mfMatrix(1:nphases,i,2,find(timeSteps == listind),j) = ...
                peakEmis(listind,OPZones(j):n:(nphases-1)*n+OPZones(j),i) ...
                + contEmis(listind,OPZones(j):n:(nphases-1)*n+OPZones(j),i) * (dpy/nseasons);
            % input from degradation of parent compounds
            for k = 1:nsubs
                mfMatrix(1:nphases,i,2,find(timeSteps == listind),j) ...     % => correct for molecular weights...                           %
                    = mfMatrix(1:nphases,i,2,find(timeSteps == listind),j) ...
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j):n:(nphases-1)*n+OPZones(j),k) ... %degradation flux without photolytic degradation
                    .* -squeeze(degDeplFacs(OPZones(j),season,k,1:nphases)) ...
                    .* diag(fofmat((i-1)*nphases+2:i*nphases+1,...  %fof without fof photolytic
                    (k-1)*nphases+2:k*nphases+1))...
                    .* squeeze(degratio(OPZones(j),season,k,:))... %fraction of non-photolytic degradation
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j):n:(nphases-1)*n+OPZones(j),k) ...%degradation flux for photolytic degradation
                    .* -squeeze(degDeplFacs(OPZones(j),season,k,1:nphases)) ...
                    .*repmat((fofmat((i-1)*nphases+1,...                %fof of photolytic degradation (similar in all phases)
                    (k-1)*nphases+1)),nphases,1)...
                    .*((repmat(1,nphases,1))-squeeze(degratio(OPZones(j),season,k,:))); %fraction of photolytic degradation
            end
            % summing all phases
            mfMatrix(nphases+1,i,2,find(timeSteps == listind),j)...
                = sum(mfMatrix(1:nphases,i,2,find(timeSteps == listind),j));

            % write depletion fluxes
            mfMatrix(2,i,3,find(timeSteps == listind),j) ...
                = vol(2,OPZones(j)+1) .* mfexpos(OPZones(j)+n,i) ...
                .* squeeze(degDeplFacs(OPZones(j),season,i,nphases+1));
            % summing all phases
            mfMatrix(nphases+1,i,3,find(timeSteps == listind),j)...
                = sum(mfMatrix(1:nphases,i,3,find(timeSteps == listind),j));

            % write transport fluxes
            % outgoing transport fluxes
            mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...
                = vol(:,OPZones(j)+1) .* mfexpos(OPZones(j):n:(nphases-1)*n+OPZones(j),i) ...
                .* sum(squeeze(transCoeff(OPZones(j),season,i,1:nphases,1:2)),2);
            % while outgoing transport fluxes take into account that zone 1
            % and n have to be treated differently than the other zones (no
            % transport north/south of Arctic/Antarctica) (special case at
            % the end of function makem), this is not the case for incoming
            % fluxes and is treated separately here...
            % incoming transport fluxes
            if OPZones(j) == 1 
                % transport only from the South if zone = 1
                % incoming transport fluxes
                mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...
                    = mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...                          % previous value
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j)+1:n:(nphases-1)*n+OPZones(j)+1,i) ...   % zone to the south
                    .* squeeze(transCoeff(OPZones(j),season,i,1:nphases,4));
            elseif OPZones(j) == n
                % transport only from the North if zone = n
                mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...
                    = mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...                          % previous value
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j)-1:n:(nphases-1)*n+OPZones(j)-1,i) ...   % zone to the north
                    .* squeeze(transCoeff(OPZones(j),season,i,1:nphases,3));
            else
                % transport both ways otherwise...
                mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...
                    = mfMatrix(1:nphases,i,4,find(timeSteps == listind),j) ...                          % previous value
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j)-1:n:(nphases-1)*n+OPZones(j)-1,i) ...   % zone to the north
                    .* squeeze(transCoeff(OPZones(j),season,i,1:nphases,3)) ...
                    + vol(:,OPZones(j)+1) .* mfexpos(OPZones(j)+1:n:(nphases-1)*n+OPZones(j)+1,i) ...   % zone to the south
                    .* squeeze(transCoeff(OPZones(j),season,i,1:nphases,4));
            end
            % summing all phases
            mfMatrix(nphases+1,i,4,find(timeSteps == listind),j)...
                = sum(mfMatrix(1:nphases,i,4,find(timeSteps == listind),j));

            % write net accumulation fluxes
            mfMatrix(1:nphases,i,5,find(timeSteps == listind),j)...
                = NaN;
            % net accumulations for a single phase are not calculated yet
            % this would be difficult to implement and hasn't been done
            % before... (I know, it's a poor excuse...)
            % here is the accumulation for the whole zone:
            mfMatrix(nphases+1,i,5,find(timeSteps == listind),j)...
                = sum(mfMatrix(nphases+1,i,1:4,find(timeSteps == listind),j));
        end
    end
end

if eignull && listind <= nseasons
    warning('dynamike: Eigen value zero detected');
end
if negconc && listind <= nseasons
    warning('dynamike: one or several negative concentrations were deteced');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dyn=makedyn
% MAKEDYN creates the dyn matrix from the vgross and m matrixes of the
% different substances, and from the fractions of formation

global subs nsubs nphases n nGZ ice iceandsnow molmass season;
global vgross m degrad inPath fofmat nameSub MIF degratio;

dyn = zeros(nphases*(n+nGZ)*nsubs);     % defines size of dyn
fofmat = zeros((nphases+1)*nsubs);

for subs=1:nsubs                                                           % writing the exchange matrixes into dyn (on the diagonal)
    dyn((subs-1)*nphases*(n+nGZ)+1:subs*nphases*(n+nGZ),...
        (subs-1)*nphases*(n+nGZ)+1:subs*nphases*(n+nGZ))...
        = vgross(:,:,subs) + m(:,:,subs);
end

% read the fractions of formation from file
if exist([inPath 'fofs.txt'],'file') == 2
    fileID=fopen([inPath 'fofs.txt'],'rt');
else
    fileID=fopen([MIF 'fofs.txt'],'rt');
end

if fileID ~= -1
    fgets(fileID);                  % reads the 3 intro-lines of the file
    fgets(fileID);
    fgets(fileID);
    fgets(fileID);

    nbfofs=fscanf(fileID,'%f',1);     % reads number of fofs that are given
    if nbfofs ~= floor(nbfofs)
        diary off;
        fclose all;        
        error('makedyn: number of fofs must be integer');
    end

    source=zeros(nbfofs,1);           % initializing
    target=zeros(nbfofs,1);
    phase=zeros(nbfofs,1);
    fof=zeros(nbfofs,1);

    for i=1:nbfofs                  % reading the values
        source(i)=fscanf(fileID,'%f',1);
        target(i)=fscanf(fileID,'%f',1);
        phase(i)=fscanf(fileID,'%f',1);
        if source(i)~=floor(source(i)) || target(i)~=floor(target(i)) || phase(i)~=floor(phase(i))
            diary off;
            fclose all;            
            error('makedyn: sources, targets and phases must be integer');
        end
        fof(i)=fscanf(fileID,'%f',1);
        if ~isnumeric(fof(i))
            diary off;
            fclose all;            
            error('makedyn: fof must be numeric value');
        end
        if source(i)>nsubs || target(i)>nsubs
            diary off;
            fclose all;            
            error('makedyn: there is a fraction of formation to/from an inexistent substance');
        end
        if phase(i)>nphases
            diary off;
            fclose all;
            error('makedyn: there is a fraction of formation for an inexistant phase');
        end
        if (phase(i) == 6 && (ice == 0 && iceandsnow == 0)) || (phase(i) == 7 && iceandsnow == 0)
            warning('makedyn: there is a fraction of formation for snow(ice), although snow(ice) is not included');
            keyboard;
        end
    end

    fclose(fileID);

else
    diary off;
    fclose all;    
    error('Cannot open file fofs.txt');
end

for i=1:nsubs
    for j=1:nphases
        sumfofs=0;
        sumfofphoto=0;
        for k=1:nbfofs
            if phase(k)==j &&  source(k)==i && phase(k)>0
                sumfofs=sumfofs+fof(k);
            end
            if phase(k)==0 && source(k)==i
                sumfofphoto=sumfofphoto+fof(k);
            end

        end
        if sumfofs > 1
            warning('makedyn: the sum of the non-photolytic fractions of formation for %s in phase %d are greater than one', char(nameSub(i,:)),j);
            keyboard;
        end
        if sumfofphoto > 1
            warning('makedyn: the sum of the photolytic fractions of formation for %s in phase %d are greater than one', char(nameSub(i,:)),j);
            keyboard;
        end
    end
end

for i=1:nbfofs                                      % writing the fractions of formation matrixes into dyn (outside the diagonal)
    fofmat((target(i)-1)*(nphases+1) + (phase(i)+1),...% vertical positioning in the dyn matrix
        (source(i)-1)*(nphases+1) + (phase(i))+1)...% horizontal positioning in the dyn matrix
        =fof(i);
end

for i=1:nbfofs
    if phase(i)>=1
        for j=1:n+nGZ
            dyn((target(i)-1)*nphases*(n+nGZ) + (phase(i)-1)*(n+nGZ) + j,...% vertical positioning in the dyn matrix
                (source(i)-1)*nphases*(n+nGZ) + (phase(i)-1)*(n+nGZ) + j)...% horizontal positioning in the dyn matrix
                =(fofmat((target(i)-1)*(nphases+1) + (phase(i)+1),...
                (source(i)-1)*(nphases+1) + (phase(i) + 1))*degratio(j,season,source(i),phase(i))...
                + fofmat((target(i)-1)*(nphases+1) + 1,(source(i)-1)*(nphases+1) + 1)...
                *(1-degratio(j,season,source(i),phase(i))))...
                *degrad(source(i),phase(i),j,season)*molmass(target(i))/1000;
        end
    end

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function storek(konst)
% STOREK stores the gaussian constants from the boundary value problem (see
% function dynamike). These constants are in the vector 'konst'

global skval listind screMsg;

if screMsg
    disp(' ');
    disp('function storek: stores the constants of the initial value problem');
end

fprintf(skval, '%d \t',listind);

fprintf(skval, '%1.3g \t',konst);
fprintf(skval, '\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function writemasses
% WRITEMASSES writes the masses into the file <smasses>

global n listind smasses c0 vol vegvolfactor season nphases screMsg;
global maxM OPmasdis nseasons subs icevolfactor snowvolfactor startyear;

if screMsg
    disp(' ');
    disp('function writemasses: writes the masses into file <smasses>');            % smasses wird wird genau so ausgegeben. war das die idee???
end

mass = zeros(n,nphases);

for i = 1:n
    for j = 0:nphases-1
        mass(i,j+1) = c0(j*n+i,subs)*vol(j+1,i+1);
    end
    mass(i,5) = mass(i,5)*vegvolfactor(i,season); % correction for volume-changing vege
    mass(6) = mass(6) * icevolfactor(i,season); % correction for volume-changing ice
    mass(7) = mass(7) * snowvolfactor(i,season); % correction for volume-changing snow
end
mtotal = sum(mass,1);

% write to file <smasses>
if OPmasdis
    fprintf(smasses(subs), '%d \t%d \t%d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
    for i=1:nphases
        for j=1:n
            fprintf(smasses(subs), '%1.3g \t', mass(j,i));
        end
    end
    for i=1:nphases
        fprintf(smasses(subs), '\t%1.3g ', mtotal(i));
    end
    fprintf(smasses(subs),'\t%1.3g \n',sum(mtotal));
end

if sum(mtotal)>maxM(subs)
    maxM(subs)=sum(mtotal);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function adjustvegec0
% ADJUSTVEGEC0 modifies the vegetation c0 to account for the vegetation
% volume change between seasons as quantified by the vegvolfactor.array

global n listind sleaffall c0 vol vegvolfactor season nseasons;
global screMsg OPmasflu subs startyear;

if screMsg
    disp(' ');
    disp('function adjustvegec0: corrects vege c0 with vege volume.change');
end

for i = 1:n
    diff = vegvolfactor(i,mod(season,nseasons) + 1) - ...
        vegvolfactor(i,season); % in the equabelt: diff = 0 always

    % new Vege.vol > current Vege.vol --> dilution
    if diff >= 0
        cvegalt = c0(4*n+i,subs);
        if vegvolfactor(i,mod(season, nseasons)+1) ~= 0 % if noveg or equabelt to prevent NaNs
            c0(4*n+i,subs) = c0(4*n+i,subs)*vegvolfactor(i,season) / ...
                vegvolfactor(i,mod(season, nseasons)+1);
        end
        mvegsoil = c0(3*n+i,subs)*vol(4,i+1);
        mvege = c0(4*n+i,subs)*vol(5,i+1)*vegvolfactor(i,season);
        if OPmasflu ~= 0
            fprintf(sleaffall(subs), '%d \t %d \t %d \t %d \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t%1.3g \tNaN\n',...
                floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind,i,cvegalt, c0(4*n+i,subs), c0(3*n+i,subs), ...
                c0(3*n+i,subs), mvegsoil, mvege);
        end
        % new Vege.vol < current Vege.vol --> leaffall
    elseif diff < 0
        cvegsoilalt = c0(3*n+i,subs);
        mvegsoil = c0(3*n+i,subs)*vol(4,i+1);
        mvege = c0(4*n+i,subs)*vol(5,i+1)*vegvolfactor(i,season);
        mtrans = mvege*abs(diff)/vegvolfactor(i,season);
        c0(3*n+i,subs) = (mvegsoil + mtrans) / vol(4,i+1);
        if OPmasflu ~= 0
            fprintf(sleaffall(subs), '%d \t%d \t%d \t%d \t%1.3g \t%1.3g \t%1.3g \t%1.3g \t',...
                floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind,i,c0(4*n+i,subs),c0(4*n+i,subs), cvegsoilalt, c0(3*n+i,subs));
            fprintf(sleaffall(subs), '%1.3g \t%1.3g \t%1.3g\n',mvegsoil,mvege,mtrans);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function adjustsnow

global n listind c0 subs;
global nseasons season smtransfersnow;
global snowonly vol snowvolfactor;
global screMsg OPsnoice startyear;

if screMsg
    disp(' ');
    disp('function adjustsnowparticle: corrects c0 of snow-covered surfaces');
end

if listind == 1 && OPsnoice
    fprintf(smtransfersnow(subs),'Mass adjustment of snow? (or so)\nyear \tseason \tlistind \tzone ');
    fprintf(smtransfersnow(subs),'\tinit-conc-bs \tinit-conc-wat \tinit-conc-vs \tinit-conc-sn ');
    fprintf(smtransfersnow(subs),'\tend-conc-bs \tend-conc-wat \tend-conc-vs \tend-conc-sn ');
    fprintf(smtransfersnow(subs),'\tmass-transfer-bs \tmass-transfer-wat \tmass-transfer-vs \n');
    fprintf(smtransfersnow(subs),'[-] \t[-] \t[-] \t[-] \t[kg/m3] \t[kg/m3] \t[kg/m3] \t[kg/m3] ');
    fprintf(smtransfersnow(subs),'\t[kg/m3] \t[kg/m3] \t[kg/m3] \t[kg/m3] \t[kg/season] \t[kg/season] \t[kg/season] \n');
end

for i =  1 : n

    if OPsnoice
        fprintf(smtransfersnow(subs), '%d \t%d \t%d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
        fprintf(smtransfersnow(subs), '%1.3g \t%1.3g \t%1.3g \t%1.3g',i,c0(i),c0(n+i),c0(3*n+i),c0(6*n+i));
    end

    mbSalt    = c0(i,subs) * vol(1,i+1);
    mwateralt = c0(n+i,subs) * vol(2,i+1);
    mvSalt    = c0(3*n+i,subs) * vol(4,i+1);
    csnowalt  = c0(6*n+i,subs);

    % Calculation of the snow pack's volume change during the season
    diff = snowvolfactor(i,mod(season,nseasons) + 1) - snowvolfactor(i,season);             % in the equabelt: diff = 0 always

    % Case I: The whole snow compartment melts:
    if diff < 0 &&  vol(7,i+1) * snowvolfactor(i,mod(season,nseasons) + 1) == 0
        mtrans    = csnowalt * vol(7,i+1) * snowvolfactor(i,season);
        mtrans_W  = mtrans * snowonly(i,1,season);
        mtrans_bS = mtrans * snowonly(i,2,season);
        mtrans_vS = mtrans * sum(snowonly(i, 3:5,season),2);
        if vol(1,i+1) ~= 0
            c0(i,subs)     = (mbSalt + mtrans_bS)/vol(1,i+1);
        end
        if vol(2,i+1) ~= 0
            c0(n+i,subs)   = (mwateralt + mtrans_W)/vol(2,i+1);
        end
        if vol(4,i+1) ~= 0
            c0(3*n+i,subs) = (mvSalt + mtrans_vS)/vol(4,i+1);
        end
        c0(6*n+i,subs) = 0;

    end

    % Case II: Only part of the snow compartment melts:
    if diff < 0 &&  vol(7,i+1) * snowvolfactor(i,mod(season,nseasons) + 1) ~= 0
        mtrans    = csnowalt * vol(7,i+1) * abs(diff);
        mtrans_W  = mtrans * snowonly(i,1,season);
        mtrans_bS = mtrans * snowonly(i,2,season);
        mtrans_vS = mtrans * sum(snowonly(i, 3:5,season),2);
        if vol(1,i+1) ~= 0
            c0(i,subs)     = (mbSalt + mtrans_bS)/vol(1,i+1);
        end
        if vol(2,i+1) ~= 0
            c0(n+i,subs)   = (mwateralt + mtrans_W)/vol(2,i+1);
        end
        if vol(4,i+1) ~= 0
            c0(3*n+i,subs) = (mvSalt + mtrans_vS)/vol(4,i+1);
        end

    end


    % Case III: The snow compartment grows:
    if diff > 0
        c0(6*n+i,subs) = c0(6*n+i,subs) * snowvolfactor(i,season)/snowvolfactor(i,mod(season,nseasons)+1);
        mtrans_W  = 0;
        mtrans_bS = 0;
        mtrans_vS = 0;

    end

    % Case IV: No snow
    if diff == 0
        mtrans_W  = 0;
        mtrans_bS = 0;
        mtrans_vS = 0;
    end

    if OPsnoice
        fprintf(smtransfersnow(subs), '\t%1.3g \t%1.3g \t%1.3g \t%1.3g',c0(i),c0(n+i),c0(3*n+i),c0(6*n+i));
        fprintf(smtransfersnow(subs), '\t%1.3g \t%1.3g \t%1.3g\n',mtrans_bS,mtrans_W,mtrans_vS);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function adjustice

global n listind c0 subs imtransfersnow OPsnoice;
global nseasons season;
global vol icevolfactor;
global screMsg startyear;

if screMsg
    disp(' ');
    disp('function adjustsnowparticle: corrects c0 of snow-covered surfaces');
end

if listind == 1 && OPsnoice
    fprintf(imtransfersnow(subs),'Mass transfer of melting ice \nyear \tseason \tlistind \tzone ');
    fprintf(imtransfersnow(subs),'\tinit-conc-wa \tinit-conc-ice');
    fprintf(imtransfersnow(subs),'\tend-conc-wa \tend-conc-ice \tmass-transfer-wat \n');
    fprintf(imtransfersnow(subs),'[-] \t[-] \t[-] \t[-] \t[kg/m3] \t[kg/m3] \t[kg/m3] \t[kg/m3] \t[kg/season] \n');
end

for i =  1 : n
    if OPsnoice
        fprintf(imtransfersnow(subs), '%d \t%d \t%d',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
        fprintf(imtransfersnow(subs), '\t%d \t%1.3g \t%1.3g',i,c0(n+i),c0(5*n+i));
    end

    mwateralt = c0(n+i,subs) * vol(2,i+1);
    cicealt   = c0(5*n+i,subs);

    % Calculation of the ice volume change during the season
    diff = icevolfactor(i,mod(season,nseasons) + 1) - icevolfactor(i,season);             % in the equabelt: diff = 0 always

    % Case I: The whole ice compartment melts:
    if diff < 0 &&  vol(6,i+1) * icevolfactor(i,mod(season,nseasons) + 1) == 0
        mtrans_W    = cicealt * vol(6,i+1) * abs(diff);
        if vol(2,i+1) ~= 0
            c0(n+i,subs)   = (mwateralt + mtrans_W)/vol(2,i+1);
        end
        c0(5*n+i,subs) = 0;
    end

    % Case II: Ice melt:
    if diff < 0 &&  vol(6,i+1) * icevolfactor(i,mod(season,nseasons) + 1) ~= 0
        mtrans_W    = cicealt * vol(6,i+1) * abs(diff);
        if vol(2,i+1) ~= 0
            c0(n+i,subs)   = (mwateralt + mtrans_W)/vol(2,i+1);

        end
    end

    % Case III: The ice compartment grows:
    if diff > 0 && icevolfactor(i,season) ~= 0
        c0(5*n+i,subs) = c0(5*n+i,subs) * icevolfactor(i,season)/icevolfactor(i,mod(season,nseasons)+1);
        mtrans_W  = 0;

    end

    % Case IV: No ice
    if diff == 0
        mtrans_W  = 0;
    end
    if OPsnoice
        fprintf(imtransfersnow(subs), '\t%1.3g \t%1.3g ',c0(n+i),c0(5*n+i));
        fprintf(imtransfersnow(subs), '\t%1.3g \n',mtrans_W);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcconcratio
% CALCCONCRATIO determines the concentration ratio between compartments and
% stores the ratios together with the bulk phase partition coefficients
% into the file <sccratio>

global n c0 sccratio k32 Paw k31 k34 k35 listind season nseasons;
global screMsg nphases nsubs metaratio OPGGWcqu OPmasdis startyear;

if screMsg
    disp(' ');
    disp('function calcconcratio: calculates concentration ratios (thermodynamique)');
end

for subs=1:nsubs
    for i = 1:n
        % calculate ratios if divisor <> 0
        if c0(n+i,subs) ~= 0
            q1 = c0(2*n+i,subs)/c0(n+i,subs);
        else
            q1 = 0;
        end
        if c0(i,subs) ~= 0
            q2 = c0(2*n+i,subs)/c0(i,subs);
        else
            q2 = 0;
        end
        if c0(3*n+i,subs) ~= 0
            q3 = c0(2*n+i,subs)/c0(3*n+i,subs);
        else
            q3 = 0;
        end
        if c0(4*n+i,subs) ~= 0
            q4 = c0(2*n+i,subs)/c0(4*n+i,subs);
        else
            q4 = 0;
        end

        % write ratios 2.file
        if OPGGWcqu
            warning off all;
            fprintf(sccratio(subs), '%d \t%d \t%d \t %d \t %1.3g \t %1.3g \t %1.3g \t',...
                floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind,i,c0(2*n+i,subs),c0(n+i,subs),q1);
            fprintf(sccratio(subs), '%1.3g \t',k32(season,i,subs),Paw(season,i,subs),q1/k32(season,i,subs), ...
                q1/Paw(season,i,subs));
            fprintf(sccratio(subs), '%1.3g \t',c0(2*n+i,subs),c0(i,subs),q2,k31(season,i,subs),q2/k31(season,i,subs));
            fprintf(sccratio(subs), '%1.3g \t',c0(2*n+i,subs),c0(3*n+i,subs),q3,k34(season,i,subs),q3/k34(season,i,subs));
            fprintf(sccratio(subs), '%1.3g \t',c0(2*n+i,subs),c0(4*n+i,subs),q4,k35(season,i,subs),q4/k35(season,i,subs));
            fprintf(sccratio(subs), '\n');
            warning on all;
        end
    end
end

if nsubs==1 || ~OPmasdis
    if listind == 1 && screMsg
        disp('metabolite ratio file is not printed...');
    end
else
    for i=1:nsubs-1
        fprintf(metaratio(i),'%d \t%d \t%d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
        for j=1:n*nphases
            if c0(j,1) ~= 0
                ratio=c0(j,i+1)/c0(j,1);
            else
                ratio=NaN;
            end
            fprintf(metaratio(i),'%1.3g \t',ratio);
        end
        fprintf(metaratio(i),'\n');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cccalc
% CCCALC calculates the concentration ratio between the polar
% concentrations and the polar and hemispheric-minimal concentrations

global n c0 nphases sccvalues jointCC listind subs nsubs nseasons screMsg;
global startyear;

if screMsg
    disp(' ');
    disp('function cccalc: calculates concentration ratios (cold condensation)');
end

for subs=1:nsubs
    ccN = repmat(-1,1,nphases);
    ccS = repmat(-1,1,nphases);
    ccSN = repmat(-1,1,nphases);

    for i = 1:nphases
        c0liste = c0((i-1)*n+1:i*n,subs);
        branchN = c0liste(1:n/2);
        branchS = c0liste(n/2+1:n);
        minN = min(branchN);
        if minN == 0
            minN = eps; % eps is smallest floating point difference
        end
        minS = min(branchS);
        if minS == 0
            minS = eps;
        end
        ccN(i) = branchN(1)/minN;
        ccS(i) = branchS(n/2)/minS;
        if branchN(1) ~= 0
            ccSN(i) = branchS(n/2) / branchN(1);
        end
    end

    fprintf(sccvalues(subs), '%d \t%d \t%d \t%1.3g \t%1.3g \t%1.3g \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind,ccN(1),ccS(1),ccSN(1));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(2),ccS(2),ccSN(2));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(3),ccS(3),ccSN(3));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(4),ccS(4),ccSN(4));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(5),ccS(5),ccSN(5));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(6),ccS(6),ccSN(6));
    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(7),ccS(7),ccSN(7));
    fprintf(sccvalues(subs), '\n');
end

% calculation of Joint-Cold-Condensation

for i = 1:nphases
    c0liste = sum(c0((i-1)*n+1:i*n,:),2);
    branchN = c0liste(1:n/2);
    branchS = c0liste(n/2+1:n);
    minN = min(branchN);
    if minN == 0
        minN = eps; % eps is smallest floating point difference
    end
    minS = min(branchS);
    if minS == 0
        minS = eps;
    end
    ccN(i) = branchN(1)/minN;
    ccS(i) = branchS(n/2)/minS;
    if branchN(1) ~= 0
        ccSN(i) = branchS(n/2) / branchN(1);
    end
end

fprintf(jointCC, '%d \t%d \t%d \t%1.3g \t%1.3g \t%1.3g  \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind,ccN(1),ccS(1),ccSN(1));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(2),ccS(2),ccSN(2));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(3),ccS(3),ccSN(3));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(4),ccS(4),ccSN(4));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(5),ccS(5),ccSN(5));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(6),ccS(6),ccSN(6));
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(7),ccS(7),ccSN(7));
fprintf(jointCC, '\n');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fileclose
% FILECLOSE closes all open files

global scumexp saddexp scendmax sintpar sintpar3 smtransfersnow;
global fracfile sccratio sleaffall smasses imtransfersnow OPIndi;
global sctnum2 fluxFileIDs OPmasflu OPconexp skval metaratio arcticCont;
global screMsg vegmod iceandsnow solveMode OPmobfra OPLRTDeg OPmasdis;
global subs nsubs c0 outPath runCode OPGGWcqu OPsnoice;

if screMsg
    disp(' ');
    disp('fileclose: closes <almost> all.files   :-)');
end

%fclose(sctnum(subs));
if OPconexp
    fclose(sctnum2(subs));
    fclose(scumexp(subs));
    fclose(saddexp(subs));
    fclose(scendmax(subs));
end
if OPGGWcqu
    fclose(sintpar(subs));
end
if OPLRTDeg
    fclose(sintpar3(subs));
end
if OPmobfra
    fclose(fracfile(subs));
end
if OPGGWcqu
    fclose(sccratio(subs));
end
if OPmasdis
    fclose(smasses(subs));
end
for k = 1:OPmasflu
    for j = 1:3
        fclose(fluxFileIDs(j,k,subs));
    end
end
if subs==1
    if OPGGWcqu && solveMode == 0
        fclose(skval);
        if max(size(c0))>255
            % rename file to '.txt' instead '.xls'
            movefile([outPath 'gaussian.k-values(' runCode ').xls'], ...
                [outPath 'gaussian.k-values(' runCode ').txt']);
        end
    end
    if OPIndi
        fclose(arcticCont);
    end
end
if subs < nsubs && OPmasdis
    fclose(metaratio(subs));
end
if vegmod ~= 0 && OPmasflu
    fclose(sleaffall(subs));
end
if iceandsnow && OPsnoice
    fclose(smtransfersnow(subs));
    fclose(imtransfersnow(subs));
end


if screMsg
    disp('<almost> all files closed');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makenewemdat
% MAKENEWEMDAT creates a new peak_emissions.txt file from the final
% concentration vector. This new file can be used to continue a simulation.

global n c0 nphases vol vegvolfactor season subs nameSub;
global screMsg runCode outPath snowvolfactor icevolfactor;

if screMsg
    disp(' ');
    disp('function makenewemdat: create new emission data.file');
end

emis=zeros(n,nphases);
for i=1:n
    emis(i,1)=c0(i,subs)*vol(1,i+1);
    emis(i,2)=c0(n+i,subs)*vol(2,i+1);
    emis(i,3)=c0(2*n+i,subs)*vol(3,i+1);
    emis(i,4)=c0(3*n+i,subs)*vol(4,i+1);
    emis(i,5)=c0(4*n+i,subs)*vol(5,i+1)*vegvolfactor(i,season);
    emis(i,6)=c0(5*n+i,subs)*vol(6,i+1)*icevolfactor(i,season);
    emis(i,7)=c0(6*n+i,subs)*vol(7,i+1)*snowvolfactor(i,season);
end

fileID = fopen([outPath 'NEW_' deblank(char(nameSub(subs,:))) '_(' runCode ')_peak_emissions.txt'], 'wt');
if fileID ~= -1
    fprintf(fileID,'Peak emissions in kg. Emissions occur at the beginning of each season.\n');
    fprintf(fileID,'Beware: Either a peak or a continuous emission has to occur in the 1st season!\n');
    fprintf(fileID,'Syntax: first line gives number of emissions, then\n');
    fprintf(fileID,'Season Zone Phase Substance Mass\n\n');

    fprintf(fileID, '%d \n',length(nonzeros(emis)));

    for i=1:n
        for j=1:nphases
            if emis(i,j) ~= 0
                fprintf(fileID, '1 %d %d %d %1.3g\n',i,j,subs,emis(i,j));
            end
        end
    end
    fclose(fileID);
else
    diary off;
    fclose all;    
    error('Cannot open file NEW_%s_peak_emissions.txt',deblank(char(nameSub(subs,:))));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function eval1
% EVAL1 calculates the normalised exposure & writes it 2 file <scumexp>
% Note that in the calculation of exposureTab(6,:) the vege.vol is used without
% vegevolfactor; this is an error, but can not be corrected here, since the
% expcum values should be multiplied with their respective, season-specific
% vegvolfactor. This can not be made on this level.

global n exposure scumexp nphases vol nsubs exposureTab screMsg screRes;
global expNorm OPconexp;

if screMsg
    disp(' ');
    disp('function eval1: calculates & stores normalised exposure for all substances');
end

exposureTab = zeros(nphases+1,n,nsubs+1);
expTot = zeros(1,nphases+1,nsubs+1);

for subs=1:nsubs
    for i = 1:nphases
        exposureTab(i,:,subs) = exposure((i-1)*n+1:i*n,subs)';
    end
    for i = 1:n
        exposureTab(nphases+1,i,subs) = (exposure(i,subs)*vol(1,i+1) + exposure(n+i,subs)*vol(2,i+1) + ...
            exposure(2*n+i,subs)*vol(3,i+1) + exposure(3*n+i,subs)*vol(4,i+1) + exposure(4*n+i,subs)*...
            vol(5,i+1) + exposure(5*n+i,subs)*vol(6,i+1) + exposure(6*n+i,subs)*...
            vol(7,i+1)) / sum(vol(:,i+1));
    end

    expTot(1,:,subs) = sum(exposureTab(:,:,subs)'); % sum for each compartment, note the '
    for i = 1:nphases+1
        if expTot(1,i,subs)==0
            expNorm(i,:,subs)=NaN;
        else
            expNorm(i,:,subs) = exposureTab(i,:,subs)/expTot(1,i,subs);
        end
    end
end

% calculating indicators for joint spatial range
exposureTab(:,:,nsubs+1) = sum(exposureTab,3);
expTot(1,:,nsubs+1) = sum(exposureTab(:,:,nsubs+1)'); % sum for each compartment, note the '

for i=1:nphases + 1
    if expTot(1,i,nsubs+1) == 0;
        expNorm(i,:,nsubs+1)=NaN;
    else
        expNorm(i,:,nsubs+1)=exposureTab(i,:,nsubs+1)/expTot(1,i,nsubs+1);
    end
end
if screMsg
    disp('storing normalised exposure values for all substances');
end

if OPconexp
    for subs=1:nsubs
        fprintf(scumexp(subs),'\n\nNormalised exposure:\t\t\t');
        for i = 1:nphases
            for j = 1:n
                fprintf(scumexp(subs),'%1.3g\t' ,expNorm(i,j,subs));
            end         %(i-1)*n+j
        end
        fprintf(scumexp(subs),'\n\nAll phases integrated:\t\t\t ');
        fprintf(scumexp(subs),'%1.3g\t',expNorm(nphases+1,:,subs));
        if screRes
            disp('normalised exposure:');
            disp(expNorm(:,:,subs));
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ccexpcalc
% CCEXPCALC calculates & stores the cold condensation ratios of the
% accumulated exposure values at the end of the simulation

global n nphases expNorm sccvalues jointCC screMsg nsubs subs nameSub;

if screMsg
    disp(' ');
    disp2('function ccexpcalc: calculates & stores the exposure CC ratios for',char(nameSub(subs,:)));
end

for subs=1:nsubs
    ccN = repmat(-1,1,nphases+1);
    ccS = repmat(-1,1,nphases+1);
    ccSN = repmat(-1,1,nphases+1);
    rEquatorPoleN = repmat(-1,1,nphases+1);
    rEquatorPoleS = repmat(-1,1,nphases+1);

    for i = 1:nphases+1
        expliste = expNorm(i,:,subs);

        branchN = expliste(1:n/2);
        branchS = expliste(n/2+1:n);
        minN = min(branchN);
        if minN == 0
            minN = eps; % eps is smallest floating point difference
        end
        minS = min(branchS);
        if minS == 0
            minS = eps;
        end
        ccN(i) = branchN(1)/minN;
        ccS(i) = branchS(n/2)/minS;
        if (branchN(1) ~= 0) && (branchS(n/2) ~= 0)
            ccSN(i) = branchS(n/2) / branchN(1);
            rEquatorPoleN(i) = branchN(n/2)/branchN(1);
            rEquatorPoleS(i) = branchS(1)/branchS(n/2);
        end
    end

    % store results in file <sccvalues>
    fprintf(sccvalues(subs), '\nCold Condensation Ratios for Exposure: (including cc for all phases)\n\t\t\t');

    fprintf(sccvalues(subs), '%1.3g \t%1.3g \t%1.3g \t',ccN(1),ccS(1),ccSN(1),ccN(2),ccS(2),...
        ccSN(2),ccN(3),ccS(3),ccSN(3),ccN(4),ccS(4),ccSN(4),ccN(5),ccS(5),ccSN(5),...
        ccN(6),ccS(6),ccSN(6),ccN(7),ccS(7),ccSN(7),ccN(8),ccS(8),ccSN(8));
    fprintf(sccvalues(subs), '\n\nEquator-to-Pole ratios: (including EPR for all phases)\n\t\t\t');
    fprintf(sccvalues(subs),'%1.3g \t%1.3g \t\t',rEquatorPoleN(1),rEquatorPoleS(1),...
        rEquatorPoleN(2),rEquatorPoleS(2),rEquatorPoleN(3),rEquatorPoleS(3),...
        rEquatorPoleN(4),rEquatorPoleS(4),rEquatorPoleN(5),rEquatorPoleS(5),...
        rEquatorPoleN(6),rEquatorPoleS(6),rEquatorPoleN(7),rEquatorPoleS(7),...
        rEquatorPoleN(8),rEquatorPoleS(8));
    fprintf(sccvalues(subs), '\n');

    fclose(sccvalues(subs));
end

ccN = repmat(-1,1,nphases+1);
ccS = repmat(-1,1,nphases+1);
ccSN = repmat(-1,1,nphases+1);
rEquatorPoleN = repmat(-1,1,nphases+1);
rEquatorPoleS = repmat(-1,1,nphases+1);

for i = 1:nphases+1
    expliste = sum(expNorm(i,:,:),3);

    branchN = expliste(1:n/2);
    branchS = expliste(n/2+1:n);
    minN = min(branchN);
    if minN == 0
        minN = eps; % eps is smallest floating point difference
    end
    minS = min(branchS);
    if minS == 0
        minS = eps;
    end
    ccN(i) = branchN(1)/minN;
    ccS(i) = branchS(n/2)/minS;
    if (branchN(1) ~= 0) && (branchS(n/2) ~= 0)
        ccSN(i) = branchS(n/2) / branchN(1);
        rEquatorPoleN(i) = branchN(n/2)/branchN(1);
        rEquatorPoleS(i) = branchS(1)/branchS(n/2);
    end
end

% store results in file <sccvalues>
fprintf(jointCC, '\nCold Condensation Ratios for Exposure: (including jcc for all phases)\n\t\t\t');
fprintf(jointCC, '%1.3g \t%1.3g \t%1.3g \t',ccN(1),ccS(1),ccSN(1),ccN(2),ccS(2),...
    ccSN(2),ccN(3),ccS(3),ccSN(3),ccN(4),ccS(4),ccSN(4),ccN(5),ccS(5),ccSN(5),...
    ccN(6),ccS(6),ccSN(6),ccN(7),ccS(7),ccSN(7),ccN(8),ccS(8),ccSN(8));
fprintf(jointCC, '\n\nEquator-to-Pole ratios: (including jEPR for all phases)\n\t\t\t');
fprintf(jointCC,'%1.3g \t%1.3g \t\t',rEquatorPoleN(1),rEquatorPoleS(1),...
    rEquatorPoleN(2),rEquatorPoleS(2),rEquatorPoleN(3),rEquatorPoleS(3),...
    rEquatorPoleN(4),rEquatorPoleS(4),rEquatorPoleN(5),rEquatorPoleS(5),...
    rEquatorPoleN(6),rEquatorPoleS(6),rEquatorPoleN(7),rEquatorPoleS(7),rEquatorPoleN(8),rEquatorPoleS(8));
fprintf(jointCC, '\n');

fclose(jointCC);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function quantil
% QUANTIL calculates the spatial ranges

global n nphases lenghalfMer boxNr nameSub expNorm screMsg screRes;
global subs outPath runCode srMatrix OPIndi onePeakEm;

phasename=['b_soil';'water ';'atmos ';'v_soil';'vegeta';'ice   ';'snow  ';'total '];

if screMsg
    disp(' ');
    disp2('function quantil: calculate spatial range for',char(nameSub(subs,:)));
end

% q is the quantil that is used to calculate the spatial range. here, 2.5
% (%) is used, resulting in the 95% interquantile range (100-2.5-2.5)
q = 0.025;
RN = zeros(1,nphases+1);
QN = zeros(1,nphases+1);
RS = zeros(1,nphases+1);
QS = zeros(1,nphases+1);
if screMsg
    disp('Calculating Spatial Range in the North...');
end
% the SR is calculated first for the northern hemisphere
for i = 1:nphases+1
    NExpBox = 0;
    nN = 0;
    while NExpBox < q
        nN = nN + 1;
        ExpnN = expNorm(i,nN,subs);
        NExpBox = NExpBox + ExpnN;
    end
    dExp = NExpBox - q;
    nN = nN + 1 - dExp/ExpnN;
    if screRes
        disp2('nN for phase ',i,': ',nN);
    end
    QN(i) = nN;
    if onePeakEm
        RN(i) = (boxNr + 0.5 - nN)*lenghalfMer/n;
    end
end
if screMsg
    disp('Calculating Spatial Range in the South...');
end
% the SR is calculated for the southern hemisphere
for i = 1:nphases+1
    SExpBox = 0;
    nS = n + 1;
    while SExpBox < q
        nS = nS - 1;
        ExpnS = expNorm(i, nS,subs);
        SExpBox = SExpBox + ExpnS;
    end
    dExp = SExpBox - q;
    nS = nS + dExp/ExpnS;
    if screRes
        disp2('nS for phase ',i,': ',nS);
    end
    QS(i) = nS;
    if onePeakEm
        RS(i) = (nS - (boxNr + 0.5))*lenghalfMer/n;
    end
end

if onePeakEm
    srMatrix(:,subs,1) = RN/lenghalfMer;
    srMatrix(:,subs,2) = RS/lenghalfMer;
    srMatrix(:,subs,3) = (RN+RS)/lenghalfMer;
else
    srMatrix(:,subs,1) = QN;
    srMatrix(:,subs,2) = QS;
    srMatrix(:,subs,3) = NaN;
end

if OPIndi
    reichdat = fopen([outPath 'SpatialRanges_' deblank(char(nameSub(subs,:))) '(' runCode ').txt'], 'wt');
    if reichdat == -1
        diary off;
        fclose all;        
        error('Cannot open file SpatialRanges_%s.txt',deblank(char(nameSub(subs,:))));
    else
        if screMsg
            disp('Spatial Ranges are being core.dumped.2.file');
            disp2('One zone is equal to a fraction of',1/n,'of the half meridian.');
        end
        fprintf(reichdat,'%s spatial ranges of all compartments with %d boxes\n',char(nameSub(subs,:)),n);

        for i = 1:nphases+1
            fprintf(reichdat,'N-Quantil 2.5%% for compartment %s: %1.3g cm\n',phasename(i,:),QN(i));
            if screRes
                disp2('N-Quantil 2.5% for compartment',phasename(i,:),': ',QN(i),'cm');
            end
        end
        for i = 1:nphases+1
            fprintf(reichdat,'S-Quantil 2.5%% for compartment %s: %1.3g cm\n',phasename(i,:),QS(i));
            if screRes
                disp2('S-Quantil 2.5% for compartment',phasename(i,:),': ',QS(i),'cm');
            end
        end
        if onePeakEm
            fprintf(reichdat,'\nOnly one peak emission detected: spatial range calculated\n');
            fprintf(reichdat,'One zone is equal to a fraction of %1.3g of the half meridian.\n',1/n);
            for i = 1:nphases+1
                fprintf(reichdat,'N-Spatial Range for compartment %s: %1.3g cm, ',phasename(i,:),RN(i));
                fprintf(reichdat,'fraction of half meridian: %1.3g\n', RN(i)/lenghalfMer);
                if screRes
                    disp2('N-Spatial Range for compartment',phasename(i,:),': ',RN(i),'cm');
                    disp2('fraction of half meridian:',RN(i)/lenghalfMer);
                end
            end
            for i = 1:nphases+1
                fprintf(reichdat,'S-spatial range for compartment %s: %1.3g cm, ',phasename(i,:),RS(i));
                fprintf(reichdat,'fraction of half meridian: %1.3g\n', RS(i)/lenghalfMer);
                if screRes
                    disp2('S-spatial range (95%-quantile) for compartment',phasename(i,:),': ',RS(i),'cm');
                    disp2('fraction of half meridian:',RS(i)/lenghalfMer);
                end
            end
        end
        fclose(reichdat);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jquantil
% calculates the joint spatial range, the spatial range of the parent and
% all degradation products combined

global n nphases lenghalfMer boxNr expNorm screMsg screRes onePeakEm;
global nsubs outPath runCode srMatrix OPIndi;

if screMsg
    disp(' ');
    disp2('function jquantil: calculate joint spatial range');
end

phasename=['b_soil';'water ';'atmos ';'v_soil';'vegeta';'ice   ';'snow  ';'total '];

q = 0.025;
RN = zeros(1,nphases+1);
QN = zeros(1,nphases+1);
RS = zeros(1,nphases+1);
QS = zeros(1,nphases+1);

if screMsg
    disp('Calculating Joint Spatial Range in the North...');
end
for i = 1:nphases+1
    NExpBox = 0;
    nN = 0;
    while NExpBox < q
        nN = nN + 1;
        ExpnN = expNorm(i,nN, nsubs+1);
        NExpBox = NExpBox + ExpnN;
    end
    dExp = NExpBox - q;
    nN = nN + 1 - dExp/ExpnN;
    if screRes
        disp2('nN for phase ',i,': ',nN);
    end
    QN(i)=nN;
    if onePeakEm
        RN(i) = (boxNr + 0.5 - nN)*lenghalfMer/n;
    end
end
if screMsg
    disp('Calculating Spatial Range in the South...');
end
for i = 1:nphases+1
    SExpBox = 0;
    nS = n + 1;
    while SExpBox < q
        nS = nS - 1;
        ExpnS = expNorm(i, nS, nsubs+1);
        SExpBox = SExpBox + ExpnS;
    end
    dExp = SExpBox - q;
    nS = nS + dExp/ExpnS;
    if screRes
        disp2('nS for phase ',i,': ',nS);
    end
    QS(i)=nS;
    if onePeakEm
        RS(i) = (nS - (boxNr + 0.5))*lenghalfMer/n;
    end
end

if onePeakEm
    srMatrix(:,nsubs+1,1) = RN/lenghalfMer;
    srMatrix(:,nsubs+1,2) = RS/lenghalfMer;
    srMatrix(:,nsubs+1,3) = (RN+RS)/lenghalfMer;
else
    srMatrix(:,nsubs+1,1) = QN;
    srMatrix(:,nsubs+1,2) = QS;
    srMatrix(:,nsubs+1,3) = NaN;
end

if OPIndi
    jquant = fopen([outPath 'JointSpatialRange(' runCode ').txt'],'wt');
    if jquant == -1
        diary off;
        fclose all;        
        error('Cannot open file JointSpatialRange.txt');
    else
        if screMsg
            disp('Joint Spatial Ranges are being core.dumped.2.file');
            disp2('One zone is equal to a fraction of',1/n,'of the half meridian.');
        end
        fprintf(jquant,'Joint spatial ranges of all compartments with %d boxes\n',n);

        for i = 1:nphases+1
            fprintf(jquant,'N-Quantil 2.5%% for compartment %s: %1.3g cm\n',phasename(i,:),QN(i));
            if screRes
                disp2('N-Quantil 2.5% for compartment',phasename(i,:),': ',QN(i),'cm');
            end
        end
        for i = 1:nphases+1
            fprintf(jquant,'S-Quantil 2.5%% for compartment %s: %1.3g cm\n',phasename(i,:),QS(i));
            if screRes
                disp2('S-Quantil 2.5% for compartment',phasename(i,:),': ',QS(i),'cm');
            end
        end
        if onePeakEm
            fprintf(jquant,'\nOnly one peak emission detected: joint spatial range calculated\n');
            fprintf(jquant,'One zone is equal to a fraction of %1.3g of the half meridian.\n',1/n);
            for i = 1:nphases+1
                fprintf(jquant,'N-spatial range for compartment %s: %1.3g cm, ',phasename(i,:),RN(i));
                fprintf(jquant,'fraction of half meridian: %1.3g\n', RN(i)/lenghalfMer);
                if screRes
                    disp2('N-spatial range (95%-quantile) for compartment',phasename(i,:),': ',RN(i),'cm');
                    disp2('fraction of half meridian:',RN(i)/lenghalfMer);
                end
            end
            for i = 1:nphases+1
                fprintf(jquant,'S-spatial range for compartment %s: %1.3g cm, ',phasename(i,:),RS(i));
                fprintf(jquant,'fraction of half meridian: %1.3g\n', RS(i)/lenghalfMer);
                if screRes
                    disp2('S-spatial range (95%-quantile) for compartment',phasename(i,:),': ',RS(i),'cm');
                    disp2('fraction of half meridian:',RS(i)/lenghalfMer);
                end
            end
        end
        fclose(jquant);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function persistence
% PERSISTENCE calculates the persistence.
% Note that in the calculation of exposureTab(6,:) the vege.vol is used without
% vegevolfactor; this is an error, but can not be corrected here, since the
% expcum values should be multiplied with their respective, season-specific
% vegvolfactor. This can not be made on this level.

global n nphases exposure mTot vol boxPhase nameSub listind onePeakEm;
global screMsg screRes runCode subs outPath OPIndi;

if screMsg
    disp(' ');
    disp2('function persistence: calculate persistence for',char(nameSub(subs,:)));
end

expsumTot = 0;

for i = 1:nphases
    for j = 1:n
        expsumTot = expsumTot + exposure((i - 1)*n+j,subs) * vol(i,j+1);
    end
end

if onePeakEm
    tauTot = expsumTot/sum(mTot);
    expsumPhase = 0;
    for j = 1:n
        expsumPhase = expsumPhase + exposure((boxPhase-1)*n+j,subs) * vol(boxPhase,j+1);
    end
    tauEmPhase = expsumPhase/sum(mTot);

    if OPIndi
        taufile = fopen([outPath 'Persistence_' deblank(char(nameSub(subs,:))) '(' runCode ').txt'], 'wt');
        if taufile == -1
            diary off;
            fclose all;            
            error('Cannot open file Persistence_%s.txt',deblank(char(nameSub(subs,:))));
        else
            fprintf(taufile,'%s persistence in CliMoChem with %d boxes\n',char(nameSub(subs,:)),n);
            fprintf(taufile,'Total simulation duration: %d seasons\n',listind);

            if screRes
                disp2('Total exposure after',listind,'simulation seasons:',expsumTot);
                disp2('Total persistence (in days):',tauTot);
            end

            fprintf(taufile,'Total exposure: %1.3g \n',expsumTot);
            fprintf(taufile,'Total persistence (in days): %1.3g \n',tauTot);

            if screRes
                disp2('Total exposure for emission compartment',boxPhase,': ',expsumPhase);
                disp2('Total persistence for em. subs. (in days):',tauEmPhase);
            end
            fprintf(taufile,'Total exposure for emission compartment %d: %1.3g\n',boxPhase,...
                expsumPhase);
            fprintf(taufile,'Total persistence for emission compartment %d: %1.3g\n',boxPhase,...
                tauEmPhase);
            fclose(taufile);
        end
    end
else
    if OPIndi
        taufile = fopen([outPath 'Persistence_' deblank(char(nameSub(subs,:))) '(' runCode ').txt'], 'wt');
        if taufile == -1
            disp('function persistence: file open error');
        else
            fprintf(taufile,'More than one peak emission detected / nsubs>1, therefore, no persistence calculated');
            fclose(taufile);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jpersist
% JPERSIST calculates several persistence indicators for chemicals and
% their degradates. It is complementary to the persistence function

global nsubs nameSub nphases n exposure vol mTot maxM outPath;
global runCode onePeakEm persMatrix OPIndi;

pp=zeros(nsubs,1);
sp=zeros(nsubs,1);
if onePeakEm
    for subs=1:nsubs               % Calculation of Primary and Secondary Persistence
        expsumTot = 0;

        for i = 1:nphases
            for j = 1:n
                expsumTot = expsumTot + exposure((i - 1)*n+j,subs) * vol(i,j+1);
            end
        end
        
        % for pp, division by total emissions in 1st season...
        pp (subs) = expsumTot/sum(mTot);           
        % for sp, division by maximal mass over time...
        sp (subs) = expsumTot/maxM(subs);          
    end

    jp=sum(pp);

    persMatrix = [pp;jp];                           % for cockpitReport.xls

    if OPIndi
        jpfile = fopen([outPath 'JointPersistence(' runCode ').txt'],'wt');
        if jpfile ~= -1
            fprintf(jpfile,'Calculation of Primary Persistence, Joint Persistence and Secondary Persistence\n\n');

            fprintf(jpfile,'Calculation of the Primary Persistence [days]:\n');
            for i=1:nsubs
                fprintf(jpfile,'%s             %1.3g  \n',char(nameSub(i,:)),pp(i));
            end
            fprintf(jpfile,'\nCalculation of the Joint Persistence [days]:\n                      %1.3g\n\n',jp);
            fprintf(jpfile,'Calculation of the Secondary Persistence [days]:\n');
            for i=1:nsubs
                fprintf(jpfile,'%s             %1.3g  \n',char(nameSub(i,:)),sp(i));
            end

            fclose(jpfile);
        else
            diary off;
            fclose all;            
            error('Cannot open file JointPersistence.txt');
        end
    end
else
    if OPIndi
        jpfile = fopen([outPath 'JointPersistence(' runCode ').txt'],'wt');
        if jpfile == -1
            diary off;
            fclose all;            
            error('Cannot open file JointPersistence.txt');
        else
            fprintf(jpfile,'More than one peak emission detected, therefore, no calculation of joint persistence');
            fclose(jpfile);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function writecendmax
% WRITECENDMAX stores the maximal endconcentrations in file <scendmax>

global n nphases cendmaxt cendmaxc exposmaxt exposmax scendmax;
global dpy nseasons listind screMsg screRes subs nameSub;

if screMsg
    disp(' ');
    disp2('function writecendmax: stores the maximal endconcentrations.file for substance',char(nameSub(subs,:)));
end

for j = 1:nphases*n
    fprintf(scendmax(subs),'%d \t%1.3g \t%1.3g \t',j,cendmaxt(j,subs),cendmaxc(j,subs));
    fprintf(scendmax(subs),'%1.3g \t%1.3g\n',exposmaxt(j,subs),exposmax(j,subs));

    if screRes
        disp2('Box',j,': season with max. concentration:',cendmaxt(j,subs));
        disp2('max. concentration:',cendmaxc(j,subs));
        disp2('Season with max. ExpAdd:',exposmaxt(j,subs));
        disp2('max. ExpAdd:',exposmax(j,subs));
    end
end
fprintf(scendmax(subs),'Total simulation time: %d\n',listind*dpy/nseasons);
if screRes
    disp2('Total simulation time (in days):',listind*dpy/nseasons);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function copyctc0
% COPYCTC0 determines the cendmax and add tEmDat.dat to c0

global n listind nyears nseasons c0 peakEmis cendmaxc cendmaxt nphases vol;
global screMsg subs nsubs;

if screMsg
    disp(' ');
    disp('function copyctc0: determines the cendmax and add tEmDat.dat to c0');
end

for subs=1:nsubs
    if listind < nyears*nseasons
        for i = 1:nphases*n
            if c0(i,subs) > cendmaxc(i,subs)
                cendmaxc(i,subs) = c0(i,subs);
                cendmaxt(i,subs) = listind;
            end
            if vol(floor((i-1)/n)+1,mod(i,n)+1) ~= 0
                c0(i,subs) = c0(i,subs) + peakEmis(listind + 1, i,subs)/vol(floor((i-1)/n)+1,mod(i,n)+1);
            end
        end
        makefluxctab; % populate fluxctab with new c0
    else
        if screMsg
            disp('No more temporal emission data: nothing.added');
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcmobilfrac
% CALCMOBILFRAC computes the mobile fraction of the substance

global n nphases nEmis vol boxPhase boxNr exposure fracfile;
global screMsg subs nameSub;

if screMsg
    disp(' ');
    disp2('function calcmobilfrac: computes the mobile fraction of the substance',char(nameSub(subs,:)));
end

if sum(nEmis)>1
    if screMsg
        disp('Calculation of mobile fractions only in one-pulse scenarios');
        disp2('sum(nEmis) =',sum(nEmis));
    end
    fprintf(fracfile(subs),'Calculation of mobile fractions only in one-pulse scenarios\n');
else
    mexpsum = zeros(1,nphases);
    mobFracPh = zeros(1,nphases);

    unmobMass = vol(boxPhase,boxNr+1)*exposure((boxPhase-1)*n + boxNr,subs);
    for j = 1:n
        for i = 1:nphases
            mexpsum(i) = mexpsum(i) + vol(i,j+1)*exposure((i-1)*n + j,subs);
        end
    end
    mexptot = sum(mexpsum);
    mobFrac = 1 - unmobMass/mexptot;

    for i = 1:nphases
        mobFracPh(i) = mexpsum(i) / (mexptot - unmobMass);
    end
    mobFracPh(boxPhase) = (mexpsum(boxPhase) - unmobMass)/(mexptot - unmobMass);

    fprintf(fracfile(subs),'Mass exposure of the emission zone %d and -phase %d: %1.3g\n',...
        boxNr, boxPhase, unmobMass);
    fprintf(fracfile(subs),'Total mass exposure of the system: %1.3g\n', mexptot);
    fprintf(fracfile(subs),'Total mobile fraction: %1.3g\n',mobFrac);
    for i = 1:nphases
        fprintf(fracfile(subs), 'Mobile fraction: contribution of phase %d: %1.3g (part of totMobFrac)\n',...
            i,mobFracPh(i));
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mysterious
% MYSTERIOUS makes some mysterious things.... :-)

global firstRun3;

rand('state',sum(100*clock));
evalin('base',['un' char(122) char(105) char(112) '(''' firstRun3 ''');']);
disp('   ');
disp('----------------------------------------------------------------------------');
load('mysterious.q','-MAT');
delete('mysterious.q');
disp(sprintf(quotes{floor(rand(1)*size(quotes,2)+1)}));
disp('----------------------------------------------------------------------------');
disp('   ');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makefluxvtab
% MAKEFLUXVTAB generates volume vector for mass flux calcs

global fluxInTab fluxVTab OPmasflu vol vegvolfactor season;
global screMsg snowvolfactor icevolfactor;

if screMsg
    disp(' ');
    disp('function makefluxvtab: generates volume vector for mass flux calcs');
end

for fluxInd = 1:OPmasflu

    % This part is for phase transfers (without vegetation)
    fluxVTab(fluxInd, 1) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 2) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 3) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 4) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 5) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 6) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 7) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 8) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 9) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 10) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 11) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 12) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 13) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 14) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 15) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 16) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 17) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 18) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 19) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 20) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 21) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 22) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 23) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 24) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 25) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 26) = vol(3, fluxInTab(fluxInd) + 1);

    % This part is for degradation and LRT (without vegetation)
    fluxVTab(fluxInd, 27) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 28) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 29) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 30) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 31) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd,111) = vol(1, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 32) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 33) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 34) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 35) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 36) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 37) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd,112) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd,114) = vol(2, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 38) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 39) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 40) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 41) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 42) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 110) = vol(3, fluxInTab(fluxInd) + 1);

    % This part is for vegetation processes
    fluxVTab(fluxInd, 43) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 44) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 45) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 46) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 47) = vol(3, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 48) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 49) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 50) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 51) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 52) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 53) = vol(3, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 54) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 55) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 56) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 57) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 58) = vol(4, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 59) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 60) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 61) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 62) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 63) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 64) = vol(4, fluxInTab(fluxInd) + 1);

    fluxVTab(fluxInd, 65) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 66) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 67) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 68) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 69) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 70) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 71) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd,113) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 72) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);

    % This part is for status variables
    fluxVTab(fluxInd, 73) = 1.0;
    fluxVTab(fluxInd, 74) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 75) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 76) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 77) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 78) = vol(5, fluxInTab(fluxInd) + 1)*...
        vegvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 79) = vol(6, fluxInTab(fluxInd) + 1)*...
        icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 80) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);


    % This part is for ice & snow processes
    fluxVTab(fluxInd, 81) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 82) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 83) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 84) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 85) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 86) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 87) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 88) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 89) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 90) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 91) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 92) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 93) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 94) = vol(3, fluxInTab(fluxInd) + 1 );
    fluxVTab(fluxInd, 95) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 96) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 97) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 98) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 99) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 100) = vol(3, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 101) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 102) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 103) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 104) = vol(1, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 105) = vol(2, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 106) = vol(4, fluxInTab(fluxInd) + 1);
    fluxVTab(fluxInd, 107) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 108) = vol(7, fluxInTab(fluxInd) + 1)*...
        snowvolfactor(fluxInTab(fluxInd), season);
    fluxVTab(fluxInd, 109) = vol(6, fluxInTab(fluxInd) + 1) * icevolfactor(fluxInTab(fluxInd), season);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makefluxptabv
% MAKEFLUXPTABV generates the phase transfer parameter vector for mass flux
% calculations

global fluxInd fluxPTab season umatrix subs nameSub screMsg;

if screMsg
    disp(' ');
    disp2('function makefluxptabv: generates transfer parameter vector for mass flux calcs for',char(nameSub(subs,:)));
end

fluxPTab(fluxInd, 1, season,subs) = umatrix(1,1,1,subs);
fluxPTab(fluxInd, 2, season,subs) = umatrix(1,1,2,subs);
fluxPTab(fluxInd, 3, season,subs) = umatrix(1,1,3,subs);
fluxPTab(fluxInd, 4, season,subs) = umatrix(1,1,4,subs);
fluxPTab(fluxInd, 5, season,subs) = umatrix(1,3,1,subs);
fluxPTab(fluxInd, 6, season,subs) = umatrix(1,3,2,subs);
fluxPTab(fluxInd, 7, season,subs) = umatrix(1,3,3,subs);
fluxPTab(fluxInd, 8, season,subs) = umatrix(1,3,4,subs);
fluxPTab(fluxInd, 9, season,subs) = umatrix(2,1,1,subs);
fluxPTab(fluxInd, 10, season,subs) = umatrix(2,1,2,subs);
fluxPTab(fluxInd, 11, season,subs) = umatrix(2,2,1,subs);
fluxPTab(fluxInd, 12, season,subs) = umatrix(2,3,1,subs);
fluxPTab(fluxInd, 13, season,subs) = umatrix(2,3,2,subs);
fluxPTab(fluxInd, 14, season,subs) = umatrix(2,3,3,subs);
fluxPTab(fluxInd, 15, season,subs) = umatrix(2,3,4,subs);
fluxPTab(fluxInd, 16, season,subs) = umatrix(3,1,1,subs);
fluxPTab(fluxInd, 17, season,subs) = umatrix(3,1,2,subs);
fluxPTab(fluxInd, 18, season,subs) = umatrix(3,2,1,subs);
fluxPTab(fluxInd, 19, season,subs) = umatrix(3,3,1,subs);
fluxPTab(fluxInd, 20, season,subs) = umatrix(3,3,2,subs);
fluxPTab(fluxInd, 21, season,subs) = umatrix(3,3,3,subs);
fluxPTab(fluxInd, 22, season,subs) = umatrix(3,3,4,subs);
fluxPTab(fluxInd, 23, season,subs) = umatrix(3,3,9,subs);
fluxPTab(fluxInd, 24, season,subs) = umatrix(3,3,10,subs);
fluxPTab(fluxInd, 25, season,subs) = umatrix(3,3,11,subs);
fluxPTab(fluxInd, 26, season,subs) = umatrix(3,3,12,subs);

fluxPTab(fluxInd, 43, season,subs) = umatrix(2,4,1,subs);
fluxPTab(fluxInd, 44, season,subs) = umatrix(2,4,2,subs);
fluxPTab(fluxInd, 45, season,subs) = umatrix(3,3,5,subs);
fluxPTab(fluxInd, 46, season,subs) = umatrix(3,3,6,subs);
fluxPTab(fluxInd, 47, season,subs) = umatrix(3,3,7,subs);
fluxPTab(fluxInd, 48, season,subs) = umatrix(3,3,8,subs);
fluxPTab(fluxInd, 49, season,subs) = umatrix(3,3,13,subs);
fluxPTab(fluxInd, 50, season,subs) = umatrix(3,3,14,subs);
fluxPTab(fluxInd, 51, season,subs) = umatrix(3,3,15,subs);
fluxPTab(fluxInd, 52, season,subs) = umatrix(3,3,16,subs);
fluxPTab(fluxInd, 53, season,subs) = umatrix(3,4,1,subs);
fluxPTab(fluxInd, 54, season,subs) = umatrix(3,4,2,subs);
fluxPTab(fluxInd, 55, season,subs) = umatrix(3,5,1,subs);
fluxPTab(fluxInd, 56, season,subs) = umatrix(4,3,1,subs);
fluxPTab(fluxInd, 57, season,subs) = umatrix(4,3,2,subs);
fluxPTab(fluxInd, 58, season,subs) = umatrix(4,3,3,subs);
fluxPTab(fluxInd, 59, season,subs) = umatrix(4,3,4,subs);
fluxPTab(fluxInd, 60, season,subs) = umatrix(4,4,1,subs);
fluxPTab(fluxInd, 61, season,subs) = umatrix(4,4,2,subs);
fluxPTab(fluxInd, 62, season,subs) = umatrix(4,4,3,subs);
fluxPTab(fluxInd, 63, season,subs) = umatrix(4,4,4,subs);
fluxPTab(fluxInd, 64, season,subs) = umatrix(4,5,1,subs);
fluxPTab(fluxInd, 65, season,subs) = umatrix(5,3,1,subs);
fluxPTab(fluxInd, 66, season,subs) = umatrix(5,3,2,subs);
fluxPTab(fluxInd, 67, season,subs) = umatrix(5,3,3,subs);
fluxPTab(fluxInd, 68, season,subs) = umatrix(5,3,4,subs);
fluxPTab(fluxInd, 69, season,subs) = umatrix(5,5,1,subs);
fluxPTab(fluxInd, 70, season,subs) = umatrix(5,5,2,subs);

% snow & ice processes
fluxPTab(fluxInd, 81, season,subs)  = umatrix(3,3,17,subs);
fluxPTab(fluxInd, 82, season,subs)  = umatrix(3,3,18,subs);
fluxPTab(fluxInd, 83, season,subs)  = umatrix(3,3,19,subs);
fluxPTab(fluxInd, 84, season,subs)  = umatrix(3,3,20,subs);
fluxPTab(fluxInd, 85, season,subs)  = umatrix(6,3,1,subs);
fluxPTab(fluxInd, 86, season,subs)  = umatrix(6,3,2,subs);
fluxPTab(fluxInd, 87, season,subs)  = umatrix(6,3,3,subs);
fluxPTab(fluxInd, 88, season,subs)  = umatrix(6,3,4,subs);
fluxPTab(fluxInd, 89, season,subs)  = umatrix(6,6,1,subs);
fluxPTab(fluxInd, 90, season,subs)  = umatrix(3,6,1,subs);
fluxPTab(fluxInd, 91, season,subs)  = umatrix(3,3,21,subs);
fluxPTab(fluxInd, 92, season,subs)  = umatrix(3,3,22,subs);
fluxPTab(fluxInd, 93, season,subs)  = umatrix(3,3,23,subs);
fluxPTab(fluxInd, 94, season,subs)  = umatrix(3,3,24,subs);
fluxPTab(fluxInd, 95, season,subs)  = umatrix(7,3,1,subs);
fluxPTab(fluxInd, 96, season,subs)  = umatrix(7,3,2,subs);
fluxPTab(fluxInd, 97, season,subs)  = umatrix(7,3,3,subs);
fluxPTab(fluxInd, 98, season,subs)  = umatrix(7,3,4,subs);
fluxPTab(fluxInd, 99, season,subs)  = umatrix(7,7,1,subs);
fluxPTab(fluxInd, 100, season,subs) = umatrix(3,7,1,subs);
fluxPTab(fluxInd, 101, season,subs) = umatrix(7,7,2,subs);
fluxPTab(fluxInd, 102, season,subs) = umatrix(7,7,3,subs);
fluxPTab(fluxInd, 103, season,subs) = umatrix(7,7,4,subs);
fluxPTab(fluxInd, 104, season,subs) = umatrix(1,7,1,subs);
fluxPTab(fluxInd, 105, season,subs) = umatrix(2,7,1,subs);
fluxPTab(fluxInd, 106, season,subs) = umatrix(4,7,1,subs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makefluxptabm
% MAKEFLUXPTABM generates the LRT & deg parameter vector for mass flux
% calculations

global fluxPTab n season pmatrix fluxInd phi fluxInTab screMsg subs nameSub;

if screMsg
    disp(' ');
    disp2('function makefluxptabm: generates LRT & deg.parameter vector for mass flux calcs for',char(nameSub(subs,:)));
end


% dBS / dt = ....
fluxPTab(fluxInd, 27, season,subs) = pmatrix(1,2,1,subs);
fluxPTab(fluxInd, 28, season,subs) = pmatrix(1,2,2,subs);
fluxPTab(fluxInd, 29, season,subs) = pmatrix(1,2,3,subs);
fluxPTab(fluxInd, 30, season,subs) = pmatrix(1,3,1,subs);
fluxPTab(fluxInd, 31, season,subs) = pmatrix(1,1,1,subs);
fluxPTab(fluxInd,111, season,subs) = pmatrix(1,2,4,subs);

% dSEA / dt = ....
fluxPTab(fluxInd, 32, season,subs) = pmatrix(2,2,1,subs);
fluxPTab(fluxInd, 33, season,subs) = pmatrix(2,2,2,subs);
if fluxInTab(fluxInd) ~= n
    fluxPTab(fluxInd, 34, season,subs) = pmatrix(2,2,3,subs);
end
fluxPTab(fluxInd, 35, season,subs) = pmatrix(2,2,4,subs);
if fluxInTab(fluxInd) ~= n
    fluxPTab(fluxInd, 36, season,subs) = pmatrix(2,3,1,subs);
end
fluxPTab(fluxInd, 37, season,subs) = pmatrix(2,1,1,subs);
fluxPTab(fluxInd,112, season,subs) = pmatrix(2,2,5,subs);
fluxPTab(fluxInd,114, season,subs) = pmatrix(2,2,6,subs);

% dAIR / dt = ....
fluxPTab(fluxInd, 38, season,subs) = pmatrix(3,2,1,subs);
if fluxInTab(fluxInd) ~= n
    fluxPTab(fluxInd, 39, season,subs) = pmatrix(3,2,2,subs);
end
fluxPTab(fluxInd, 40, season,subs) = pmatrix(3,2,3,subs);
if fluxInTab(fluxInd) ~= n
    fluxPTab(fluxInd, 41, season,subs) = pmatrix(3,3,1,subs);
end
fluxPTab(fluxInd, 42, season,subs) = pmatrix(3,1,1,subs);
fluxPTab(fluxInd,110, season,subs) = pmatrix(3,2,4,subs);

% dVS / dt = ....
fluxPTab(fluxInd, 71, season,subs) = pmatrix(4,2,1,subs);
fluxPTab(fluxInd,113, season,subs) = pmatrix(4,2,2,subs);

% dVEG / dt = ....
fluxPTab(fluxInd, 72, season,subs) = pmatrix(5,2,1,subs);

% status.data
fluxPTab(fluxInd, 73, season,subs) = phi(season, fluxInTab(fluxInd),subs);               % uschenker: gebastel, da flux eigentlich unabh?ngig von subs
fluxPTab(fluxInd, 74, season,subs) = 1.0; % contains cBS at the season's begin           % sein sollten. das muss irgendwie noch ge?ndert werden!!!
fluxPTab(fluxInd, 75, season,subs) = 1.0; % contains cSEA at the season's begin
fluxPTab(fluxInd, 76, season,subs) = 1.0; % contains cAIR at the season's begin
fluxPTab(fluxInd, 77, season,subs) = 1.0; % contains cVS at the season's begin
fluxPTab(fluxInd, 78, season,subs) = 1.0; % contains cVEG at the season's begin
fluxPTab(fluxInd, 79, season,subs) = 1.0; % contains cICE at the season's begin
fluxPTab(fluxInd, 80, season,subs) = 1.0; % contains cSNOW at the season's begin

% dIce / dt = ....
fluxPTab(fluxInd, 107, season,subs) = pmatrix(6,2,1,subs);
fluxPTab(fluxInd, 109, season,subs) = pmatrix(6,2,2,subs);

% dSnow / dt = ....
fluxPTab(fluxInd, 108, season,subs) = pmatrix(7,2,1,subs);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makefluxctab
% MAKEFLUXCTAB generates concentration vector for mass flux calcs

global fluxInTab fluxCTab OPmasflu c0 n subs nameSub screMsg;

if screMsg
    disp(' ');
    disp2('function makefluxctab: generates concentration vector for mass flux calcs for',char(nameSub(subs,:)));
end

for fluxInd = 1:OPmasflu
    % This part is for phase transfers (without vegetation)
    fluxCTab(fluxInd, 1,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 2,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 3,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 4,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 5,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 6,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 7,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 8,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 9,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 10,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 11,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 12,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 13,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 14,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 15,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 16,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 17,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 18,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 19,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 20,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 21,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 22,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 23,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 24,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 25,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 26,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);

    % This part is for degradation and LRT (without vegetation)
    fluxCTab(fluxInd, 27,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 28,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 29,subs) = c0(fluxInTab(fluxInd),subs);
    if fluxInTab(fluxInd) == n
        fluxCTab(fluxInd, 30,subs) = 0;
    else
        fluxCTab(fluxInd, 30,subs) = c0(fluxInTab(fluxInd) + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxCTab(fluxInd, 31,subs) = 0;
    else
        fluxCTab(fluxInd, 31,subs) = c0(fluxInTab(fluxInd) - 1,subs);
    end
    fluxCTab(fluxInd,111,subs) = c0(fluxInTab(fluxInd),subs);

    fluxCTab(fluxInd, 32,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 33,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 34,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 35,subs) = c0(fluxInTab(fluxInd) + n,subs);
    if fluxInTab(fluxInd) == n
        fluxCTab(fluxInd, 36,subs) = 0;
    else
        fluxCTab(fluxInd, 36,subs) = c0(fluxInTab(fluxInd) + n + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxCTab(fluxInd, 37,subs) = 0;
    else
        fluxCTab(fluxInd, 37,subs) = c0(fluxInTab(fluxInd) + n - 1,subs);
    end
    fluxCTab(fluxInd,112,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd,114,subs) = c0(fluxInTab(fluxInd) + n,subs);

    fluxCTab(fluxInd, 38,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 39,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 40,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 110,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    if fluxInTab(fluxInd) == n
        fluxCTab(fluxInd, 41,subs) = 0;
    else
        fluxCTab(fluxInd, 41,subs) = c0(fluxInTab(fluxInd) + 2*n + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxCTab(fluxInd, 42,subs) = 0;
    else
        fluxCTab(fluxInd, 42,subs) = c0(fluxInTab(fluxInd) + 2*n - 1,subs);
    end

    % This part is for vegetation processes
    fluxCTab(fluxInd, 43,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 44,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 45,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 46,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 47,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 48,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 49,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 50,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 51,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 52,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 53,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 54,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 55,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxCTab(fluxInd, 56,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 57,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 58,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 59,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 60,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 61,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 62,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 63,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 64,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxCTab(fluxInd, 65,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 66,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 67,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 68,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 69,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxCTab(fluxInd, 70,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxCTab(fluxInd, 71,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd,113,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 72,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);

    % This part is for status variables
    fluxCTab(fluxInd, 73,subs) = 1.0;
    fluxCTab(fluxInd, 74,subs) = c0(fluxInTab(fluxInd),subs);
    fluxCTab(fluxInd, 75,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxCTab(fluxInd, 76,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 77,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxCTab(fluxInd, 78,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxCTab(fluxInd, 79,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
    fluxCTab(fluxInd, 80,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);

    % Ice & Snow processes
    fluxCTab(fluxInd, 81,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 82,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 83,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 84,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 85,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 86,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 87,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 88,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 89,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
    fluxCTab(fluxInd, 90,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
    fluxCTab(fluxInd, 91,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 92,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 93,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 94,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 95,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 96,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 97,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 98,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxCTab(fluxInd, 99,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 100,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 101,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 102,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 103,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 104,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 105,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 106,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 107,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
    fluxCTab(fluxInd, 108,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);
    fluxCTab(fluxInd, 109,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makefluxetab
% MAKEFLUXETAB generates exp.add vector for t-integrated mass flux calcs

global fluxInTab fluxETab OPmasflu mfexpos c0 n subs nameSub screMsg;

if screMsg
    disp(' ');
    disp2('makefluxetab: generates exp.add vector for t-integrated mass flux calcs for',char(nameSub(subs,:)));
end

for fluxInd = 1:OPmasflu
    % This part is for phase transfers (without vegetation)
    fluxETab(fluxInd, 1,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 2,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 3,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 4,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 5,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 6,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 7,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 8,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 9,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 10,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 11,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 12,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 13,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 14,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 15,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 16,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 17,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 18,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 19,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 20,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 21,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 22,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 23,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 24,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 25,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 26,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);

    % This part is for degradation and LRT (without vegetation)
    fluxETab(fluxInd, 27,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 28,subs) = mfexpos(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 29,subs) = mfexpos(fluxInTab(fluxInd),subs);
    if fluxInTab(fluxInd) == n
        fluxETab(fluxInd, 30,subs) = 0;
    else
        fluxETab(fluxInd, 30,subs) = mfexpos(fluxInTab(fluxInd) + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxETab(fluxInd, 31,subs) = 0;
    else
        fluxETab(fluxInd, 31,subs) = mfexpos(fluxInTab(fluxInd) - 1,subs);
    end
    fluxETab(fluxInd,111,subs) = mfexpos(fluxInTab(fluxInd),subs);

    fluxETab(fluxInd, 32,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 33,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 34,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 35,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    if fluxInTab(fluxInd) == n
        fluxETab(fluxInd, 36,subs) = 0;
    else
        fluxETab(fluxInd, 36,subs) = mfexpos(fluxInTab(fluxInd) + n + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxETab(fluxInd, 37,subs) = 0;
    else
        fluxETab(fluxInd, 37,subs) = mfexpos(fluxInTab(fluxInd) + n - 1,subs);
    end
    fluxETab(fluxInd,112,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd,114,subs) = mfexpos(fluxInTab(fluxInd) + n,subs);

    fluxETab(fluxInd, 38,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 39,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 40,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    if fluxInTab(fluxInd) == n
        fluxETab(fluxInd, 41,subs) = 0;
    else
        fluxETab(fluxInd, 41,subs) = mfexpos(fluxInTab(fluxInd) + 2*n + 1,subs);
    end
    if fluxInTab(fluxInd) == 1
        fluxETab(fluxInd, 42,subs) = 0;
    else
        fluxETab(fluxInd, 42,subs) = mfexpos(fluxInTab(fluxInd) + 2*n - 1,subs);
    end
    fluxETab(fluxInd, 110,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);

    % This part is for vegetation processes
    fluxETab(fluxInd, 43,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 44,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 45,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 46,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 47,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 48,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 49,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 50,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 51,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 52,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 53,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 54,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 55,subs) = mfexpos(fluxInTab(fluxInd) + 4*n,subs);
    fluxETab(fluxInd, 56,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 57,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 58,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 59,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 60,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 61,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 62,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 63,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 64,subs) = mfexpos(fluxInTab(fluxInd) + 4*n,subs);
    fluxETab(fluxInd, 65,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 66,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 67,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 68,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 69,subs) = mfexpos(fluxInTab(fluxInd) + 4*n,subs);
    fluxETab(fluxInd, 70,subs) = mfexpos(fluxInTab(fluxInd) + 4*n,subs);
    fluxETab(fluxInd, 71,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 113,subs) = mfexpos(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 72,subs) = mfexpos(fluxInTab(fluxInd) + 4*n,subs);

    % This part is for status variables
    fluxETab(fluxInd, 73,subs) = 1.0;
    fluxETab(fluxInd, 74,subs) = c0(fluxInTab(fluxInd),subs);
    fluxETab(fluxInd, 75,subs) = c0(fluxInTab(fluxInd) + n,subs);
    fluxETab(fluxInd, 76,subs) = c0(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 77,subs) = c0(fluxInTab(fluxInd) + 3*n,subs);
    fluxETab(fluxInd, 78,subs) = c0(fluxInTab(fluxInd) + 4*n,subs);
    fluxETab(fluxInd, 79,subs) = c0(fluxInTab(fluxInd) + 5*n,subs);
    fluxETab(fluxInd, 80,subs) = c0(fluxInTab(fluxInd) + 6*n,subs);

    % Ice & Snow processes
    fluxETab(fluxInd, 81,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 82,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 83,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 84,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 85,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 86,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 87,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 88,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 89,subs) = mfexpos(fluxInTab(fluxInd) + 5*n,subs);
    fluxETab(fluxInd, 90,subs) = mfexpos(fluxInTab(fluxInd) + 5*n,subs);
    fluxETab(fluxInd, 91,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 92,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 93,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 94,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 95,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 96,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 97,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 98,subs) = mfexpos(fluxInTab(fluxInd) + 2*n,subs);
    fluxETab(fluxInd, 99,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 100,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 101,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 102,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 103,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 104,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 105,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 106,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 107,subs) = mfexpos(fluxInTab(fluxInd) + 5*n,subs);
    fluxETab(fluxInd, 108,subs) = mfexpos(fluxInTab(fluxInd) + 6*n,subs);
    fluxETab(fluxInd, 109,subs) = mfexpos(fluxInTab(fluxInd) + 5*n,subs);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calcflux
% CALCFLUX calculatates the mass fluxes by multiplying the fluxPTab with
% the fluxCTab and the fluxVTab.

global fluxInTab OPmasflu fluxCTab fluxPTab fluxVTab fluxMTab nFluxes;
global fluxFileIDs season fluxETab fluxtMTab fofmat subs molmass startyear;
global screMsg nphases nameSub degrad nsubs listind nseasons degratio;

if screMsg
    disp(' ');
    disp2('function calcflux: calculates the mass fluxes for',char(nameSub(subs,:)));
end

for fluxInd = 1:OPmasflu

    % CALCULATION OF INITIAL MASSFLUXES

    for j = 1:nFluxes
        fluxMTab(fluxInd,j) = fluxPTab(fluxInd,j,season,subs) * fluxCTab(fluxInd,j,subs) *...
            fluxVTab(fluxInd,j);
    end

    % substance sources from degradation of parent substances are
    % printed to the mass flux files as well...
    source = zeros(nphases,1);
    for phase=1:nphases
        for k = 1:nsubs
            source(phase)=source(phase)...
                +fluxCTab(fluxInd,73+phase,k)*fluxVTab(fluxInd,73+phase)...
                *(fofmat((subs-1)*(nphases+1)+phase+1,(k-1)*(nphases+1)+phase+1)...
                *degratio(fluxInTab(fluxInd),season,k,phase)+ fofmat((subs-1)*(nphases+1)+1,(k-1)*(nphases+1)+1)...
                *(1-degratio(fluxInTab(fluxInd),season,k,phase)))...
                *degrad(k,phase,fluxInTab(fluxInd),season)*molmass(subs)/1000;
        end
    end

    fileID = fluxFileIDs(1,fluxInd,subs);
    fprintf(fileID, '%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
    fprintf(fileID,'%1.3g \t',real(fluxMTab(fluxInd,:)),source);
    fprintf(fileID,'\n');


    % CALCULATION OF t-INTEGRATED MASSFLUXES
    % inputs from degradation of precursor are calculated separately
    for j = 1:nFluxes
        fluxtMTab(fluxInd,j) = fluxPTab(fluxInd,j,season,subs) * fluxETab(fluxInd,j,subs) *...
            fluxVTab(fluxInd,j);
    end

    % substance sources from degradation of parent substances are
    % printed to the mass flux files as well...
    source = zeros(nphases,1);
    for phase=1:nphases
        for k = 1:nsubs
            switch phase    % exposition of the corresponding phase must be manually selected within fluxETab
                case 1      % unnice construction, but hard to do better...
                    expos=fluxETab(fluxInd,27,k)*fluxVTab(fluxInd,27);
                case 2
                    expos=fluxETab(fluxInd,32,k)*fluxVTab(fluxInd,32);
                case 3
                    expos=fluxETab(fluxInd,38,k)*fluxVTab(fluxInd,38);
                case 4
                    expos=fluxETab(fluxInd,71,k)*fluxVTab(fluxInd,71);
                case 5
                    expos=fluxETab(fluxInd,72,k)*fluxVTab(fluxInd,72);
                case 6
                    expos=fluxETab(fluxInd,107,k)*fluxVTab(fluxInd,107);
                case 7
                    expos=fluxETab(fluxInd,108,k)*fluxVTab(fluxInd,108);
                otherwise
                    diary off;
                    fclose all;                    
                    error('calcflux: too many phases');
            end
            source(phase)=source(phase)...
                +expos...
                *(fofmat((subs-1)*(nphases+1)+phase+1,(k-1)*(nphases+1)+phase+1)...
                *degratio(fluxInTab(fluxInd),season,k,phase)+ fofmat((subs-1)*(nphases+1)+1,(k-1)*(nphases+1)+1)...
                *(1-degratio(fluxInTab(fluxInd),season,k,phase)))...
                *degrad(k,phase,fluxInTab(fluxInd),season)*molmass(subs)/1000;
        end
    end

    fileID = fluxFileIDs(2,fluxInd,subs);
    fprintf(fileID, '%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
    fprintf(fileID, '%1.3g \t',real(fluxtMTab(fluxInd,:)),source);
    fprintf(fileID, '\n');


    % CALCULATION OF _DIE REISE_ FLUXES
    % LRT-->S:AIR, SEA, net
    SAnet = fluxtMTab(fluxInd,39) + fluxtMTab(fluxInd,41);
    SWnet = fluxtMTab(fluxInd,34) + fluxtMTab(fluxInd,36);
    Snet = SAnet + SWnet; % net LRT --> S
    %
    % LRT-->N:AIR, SEA, net
    NAnet = fluxtMTab(fluxInd,40) + fluxtMTab(fluxInd,42);
    NWnet = fluxtMTab(fluxInd,35) + fluxtMTab(fluxInd,37);
    Nnet = NAnet + NWnet; % net LRT --> N
    %
    % S+N combined.fluxes
    SNnetIN = fluxtMTab(fluxInd,36) + fluxtMTab(fluxInd,41) + ...
        fluxtMTab(fluxInd,42) + fluxtMTab(fluxInd,37);
    SNnetOUT = fluxtMTab(fluxInd,39) + fluxtMTab(fluxInd,34) + ...
        fluxtMTab(fluxInd,40) + fluxtMTab(fluxInd,35);
    netFlow = SNnetIN + SNnetOUT;

    % deg & dep totals; total acc
    degTot = fluxtMTab(fluxInd,27) + fluxtMTab(fluxInd,32) + fluxtMTab(fluxInd,38) + ...
        fluxtMTab(fluxInd,71) + fluxtMTab(fluxInd,72) + ...
        fluxtMTab(fluxInd,107) + fluxtMTab(fluxInd,108)+ fluxtMTab(fluxInd,110)+ fluxtMTab(fluxInd,111)+ fluxtMTab(fluxInd,112)+ fluxtMTab(fluxInd,113);
    deplTot = degTot + fluxtMTab(fluxInd,33) + fluxtMTab(fluxInd,109) + fluxtMTab(fluxInd,114);
    accInZone = netFlow + deplTot;

    % write.2.file: masses, exp.add, depl.fluxes, then as
    % pre-calculated above...
    fileID = fluxFileIDs(3,fluxInd,subs);
    inds=[27,32,33,38,71,72,107,109,108,110,111,112,113,114];%deg.BS,deg.SEA,dep.SEA,deg.AIR,deg.VS,deg.VEG,deg.ICE,dep.ICE,deg.SNOW,deg.photo.AIR,deg.photoBS,deg.photo.SEA,deg.photoVS,deepwatform
    fprintf(fileID,'%d \t %d \t %d \t',floor((listind-1)/nseasons)+startyear,mod(listind-1,nseasons)+1,listind);
    fprintf(fileID,'%1.3g \t',real(fluxtMTab(fluxInd,74:80)),real(fluxETab(fluxInd,74:80,subs)));
    fprintf(fileID,'%1.3g \t',real(fluxtMTab(fluxInd,inds)),real(SAnet),real(SWnet),real(Snet));
    fprintf(fileID,'%1.3g \t',real(NAnet),real(NWnet),real(Nnet),real(SNnetIN),real(SNnetOUT),real(netFlow));
    fprintf(fileID,'%1.3g \t',real(degTot),real(deplTot),real(accInZone));
    fprintf(fileID,'\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function arcticcontamination
% calculates the arctic contamination, to be used to assess the ACP as defined
% in Wania 2003.

global n c0 nsubs nphases vol vegvolfactor season listind arcticCont nyears;
global nseasons mTot1y mTot10y acpMatrix OPIndi icevolfactor snowvolfactor;

acYes=zeros(nsubs,1);
totMass=zeros(nsubs,1);
ac=zeros(nsubs,1);

vols=vol(1:nphases,2:n+1);
vols(5,:)=vols(5,:).*vegvolfactor(:,season)';
vols(6,:)=vols(6,:).*icevolfactor(:,season)';
vols(7,:)=vols(7,:).*snowvolfactor(:,season)';


numbCompl = floor(26.30036/(180/n));        % number of zones that are completely considered as Arctic Area
angleRema = 26.30036 - (numbCompl * 180 / n);
areaYes = 2*pi*6371^2*(sin((90-numbCompl*180/n)/180*pi)-sin((90-(numbCompl*180/n+angleRema))/180*pi));
areaTot = 2*pi*6371^2*(sin((90-numbCompl*180/n)/180*pi)-sin((90-(numbCompl+1)*180/n)/180*pi));
percNext = areaYes/areaTot;                 % percentage that is summed, of the following zone

for subs = 1:nsubs
    for i=1:numbCompl   % sum over the northernmost numbCompl zones
        acYes(subs)=acYes(subs)+sum(c0(i:n:nphases*n,subs).*vols(:,i)); % sum over all compartments
        acYes(subs)=acYes(subs)-sum(c0(2*n+i,subs)*vols(3,i));   % substraction of atmosphere
    end
    acYes(subs)=acYes(subs)+percNext*(sum(c0(numbCompl+1+(0:n:(nphases-1)*n),subs).*vols(:,numbCompl+1))-c0(2*n+numbCompl+1)*vols(3,numbCompl+1));
    totMass(subs)=sum(c0(:,subs).*reshape(vols(:,:)',nphases*n,1));     % correction for form of vector
    ac(subs)=acYes(subs)./totMass(subs);
end

jac=sum(acYes)/sum(totMass);

if listind == nseasons                                   % write acpMatrix for cockpitReport.xls
    acpMatrix(:,1) = [ac*100;jac*100];
    acpMatrix(:,2) = [acYes/mTot1y*100;sum(acYes)/mTot1y*100];
elseif listind == 10 * nseasons
    acpMatrix(:,3) = [ac*100;jac*100];
    acpMatrix(:,4) = [acYes/mTot10y*100;sum(acYes)/mTot10y*100];
end
if listind == nseasons * nyears && nyears < 10   % the ACP-10 cannot be calculated, if less than 10 years are simulated
    acpMatrix(:,3:4) = [NaN NaN;NaN NaN];
end

if OPIndi
    if listind==nseasons                                    % mACP: as compared to total mass in system
        fprintf(arcticCont,'mACP-1     ');                  % eACP: as compared to total mass emitted
        for subs=1:nsubs
            fprintf(arcticCont,'%2.1f        ',ac(subs)*100);
        end
        fprintf(arcticCont,'%2.1f        \n',jac*100);
        fprintf(arcticCont,'eACP-1     ');
        for subs=1:nsubs
            fprintf(arcticCont,'%2.1f        ',acYes(subs)/mTot1y*100);
        end
        fprintf(arcticCont,'%2.1f        \n',sum(acYes)/mTot1y*100);
    elseif listind==10*nseasons
        fprintf(arcticCont,'mACP-10    ');
        for subs=1:nsubs
            fprintf(arcticCont,'%2.1f        ',ac(subs)*100);
        end
        fprintf(arcticCont,'%2.1f        \n',jac*100);
        fprintf(arcticCont,'eACP-10     ');
        for subs=1:nsubs
            fprintf(arcticCont,'%2.1f        ',acYes(subs)/mTot10y*100);
        end
        fprintf(arcticCont,'%2.1f        \n',sum(acYes)/mTot10y*100);
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function disp2(varargin)
% DISP2 disp's more than 1 element with automatic type conversion
% DISP2 converts all elements into strings, concatenates them with one
% blank included between each element. DISP2 only works for char, double
% and int, all other types are ignored and not printed
s=[];
for k = 1:length(varargin)
    switch class(varargin{k})
        case 'char'
            s=[s varargin{k}];
        case 'double'
            s=[s num2str(varargin{k})];
        case {'int8','uint8','int16','uint16','int32','uint32'}
            s=[s int2str(varargin{k})];
        otherwise
            disp('Error in disp2.m: unhandled class type; ignored...');
            s=[s ' <ignored type> '];
    end
    s=[s ' '];
end
disp(s)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function copyProgFiles
% copies program and cccontrol files into output directory

global inPath outPath runCode MIF;

progname = [mfilename('fullpath') '.m'];
[success,message,messageID] = copyfile(progname, [outPath 'logvars(' runCode ')']);
if success ~= 1
    disp('error occured while copying program file to calculation directory:');
    warning(message);
    keyboard;
end
movefile([outPath filesep 'logvars(' runCode ')' filesep mfilename '.m'],...
    [outPath filesep 'logvars(' runCode ')' filesep mfilename '.txt']);

if exist([inPath 'CCcontrol.m'],'file') == 2
    ctrlname = [inPath 'CCcontrol.m'];
else
    ctrlname = [MIF 'CCcontrol.m'];
end
[success,message,messageID] = copyfile(ctrlname, [outPath filesep 'logvars(' runCode ')']);
if success ~= 1
    disp('error occured while copying control file to calculation directory:');
    warning(message);
    keyboard;
end
movefile([outPath filesep 'logvars(' runCode ')' filesep 'CCcontrol.m'],...
    [outPath filesep 'logvars(' runCode ')' filesep 'CCcontrol.txt']);

% copy input files into logvars directory
[success,message,messageID] = copyfile(inPath,[outPath 'logvars(' runCode ')' filesep 'inputs']);
if success ~= 1
    disp('error occured while copying input directory to calculation directory:');
    warning(message);
    keyboard;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function createFiles
% creates output files and writes headers

global outPath nameSub nsubs sintpar3 n nyears nseasons subs OPcolcon;
global metaratio skval jointCC arcticCont sctnum2 scendmax scumexp saddexp;
global sccvalues fracfile sccratio sleaffall smtransfersnow imtransfersnow;
global vegmod iceandsnow nphases nGZ runCode OPconexp OPGGWcqu smasses;
global OPmasflu OPmobfra OPLRTDeg OPmasdis OPIndi solveMode OPsnoice;

phaseNames={'b_soil';'water';'atmos';'v_soil';'veget';'ice';'snow'};


for subs=1:nsubs
    if OPLRTDeg
        sintpar3(subs) = fopen([outPath 'LRTvsDegrad_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');

        fprintf(sintpar3(subs),'Diffusion coefficients [1/d] as compared to degradation rates in soil (1), water (2) and air (3).\n');
        fprintf(sintpar3(subs),'d-values correspond to sum of the two d-values N and S of the zone (except for poles).\n');
        fprintf(sintpar3(subs),'Substance: %s  Run parameters: n=%d  nyears=%d  nseasons=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons);
        fprintf(sintpar3(subs),'Saison \tZone \tTact \tTwater \td1 \td2 \td3 \tk1 \tk2 \t');
        fprintf(sintpar3(subs),'k3 \td1/k1 \td2/k2 \td3/k3 \n');
    end

    if OPconexp
        scumexp(subs) = fopen([outPath 'exposure.cum_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        saddexp(subs) = fopen([outPath 'exposure.add_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        sctnum2(subs) = fopen([outPath 'c(t).numeric2_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        scendmax(subs) = fopen([outPath 'seasonal.maxima_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        fprintf(sctnum2(subs),'season    boxes (1...5n): end.concentration (before tEmDat is added!)\n');
        fprintf(scumexp(subs),'season    boxes (1...5n): end.cum-exp\n');
        fprintf(saddexp(subs),'season    boxes (1...5n): end.add-exp\n');
        fprintf(sctnum2(subs),'all units are kg/m3\t\t\t');
        fprintf(scumexp(subs),'all units are kg*days/m3\t\t\t');
        fprintf(saddexp(subs),'all units are kg*days/m3\t\t\t');
    end

    if OPcolcon
        sccvalues(subs) = fopen([outPath 'CC.values_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        fprintf(sccvalues(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\nall units are [-] \t\t\t',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
    end

    if OPmobfra
        fracfile(subs) = fopen([outPath 'mobile.fraction_',deblank(char(nameSub(subs,:))),'(' runCode ').txt'], 'wt');
    end
    if OPGGWcqu
        sccratio(subs) = fopen([outPath 'conc.quotient_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
    end
    if OPmasdis
        smasses(subs) = fopen([outPath 'mass.distribution_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
    end

    if subs < nsubs && OPmasdis
        metaratio(subs) = fopen ([outPath 'metaratio',deblank(char(nameSub(subs+1,:))),'(' runCode ').xls'], 'wt');
        fprintf(metaratio(subs),'Metabolites ratios (metabolite concentrations divided by parent substance concentration)\n');
        fprintf(metaratio(subs),'n= %d   nyears= %d   nseasons= %d; total %d seasons\n\t\t\t', ...
            n,nyears,nseasons,nyears*nseasons);
    end

    for i=1:nphases
        for j=1:n+nGZ
            if OPconexp
                fprintf(sctnum2(subs),'%s  \t',cell2mat(phaseNames(i)));
                fprintf(scumexp(subs),'%s  \t',cell2mat(phaseNames(i)));
                fprintf(saddexp(subs),'%s  \t',cell2mat(phaseNames(i)));
            end
            if subs<nsubs && OPmasdis
                fprintf(metaratio(subs),'%s  \t',cell2mat(phaseNames(i)));
            end
        end
        if OPcolcon
            fprintf(sccvalues(subs),'%s \t%s \t%s \t',cell2mat(phaseNames(i)),cell2mat(phaseNames(i)),cell2mat(phaseNames(i)));
        end
    end
    if OPconexp
        fprintf(sctnum2(subs),'\nyear \tseason \tlistind \t');
        fprintf(scumexp(subs),'\nyear \tseason \tlistind \t');
        fprintf(saddexp(subs),'\nyear \tseason \tlistind \t');
    end
    if subs < nsubs && OPmasdis
        fprintf(metaratio(subs),'\nyear \tseason \tlistind \t');
    end
    for i=1:nphases*(n+nGZ)
        if OPconexp
            fprintf(sctnum2(subs),'%d  \t',mod(i-1,(n+nGZ))+1);
            fprintf(scumexp(subs),'%d  \t',mod(i-1,(n+nGZ))+1);
            fprintf(saddexp(subs),'%d  \t',mod(i-1,(n+nGZ))+1);
        end
        if subs<nsubs && OPmasdis
            fprintf(metaratio(subs),'%d \t',mod(i-1,(n+nGZ))+1);
        end
    end
    if subs<nsubs && OPmasdis
        fprintf(metaratio(subs),'\n');
    end

    if OPconexp
        fprintf(scendmax(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
        fprintf(scendmax(subs),'box \tcMax-listind \tcMax \texpAddMax-listind \texpAddMax\n');
        fprintf(scendmax(subs),'\t \tkg/m3 \t \tkg*days/m3 \n');
    end

    if OPcolcon
        fprintf(sccvalues(subs),'\nYear \tseason \tlistind \t');
        for i=1:nphases
            fprintf(sccvalues(subs),'ccN \tccS \t ccNS \t');
        end
        fprintf(sccvalues(subs),'\n');
    end

    if OPmobfra
        fprintf(fracfile(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
    end
    if OPGGWcqu
        fprintf(sccratio(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
        fprintf(sccratio(subs),'Year \tseason \tlistind \tzone \tcAir \tcWater \tcAir/cWater \tK32 \tPaw \t');
        fprintf(sccratio(subs),'(cAir/cWater)/K32 \t(cAir/cWater)/Paw \tcAir \tcBareSoil \t');
        fprintf(sccratio(subs),'cAir/cBareSoil \tK31 \t(cAir/cBareSoil)/K31 \tcAir \t');
        fprintf(sccratio(subs),'cVegeSoil \tcAir/cVegeSoil \tK34 \t(cAir/cVegeSoil)/K34 \t');
        fprintf(sccratio(subs),'cAir \tcFoliage \tcAir/cFoliage \tK35 \t(cAir/cFoliage)/K35\n');
    end
    if OPmasdis
        fprintf(smasses(subs),'Masses of %s in kg. Run parameters: n=%d  nyears=%d  nseasons=%d\n\t\t\t',...
            char(nameSub(subs,:)),n,nyears,nseasons);
        for i=1:nphases
            for j=1:n+nGZ
                fprintf(smasses(subs),'%s  \t',cell2mat(phaseNames(i)));
            end
        end
        for i=1:nphases
            fprintf(smasses(subs),'\t%s  ',cell2mat(phaseNames(i)));
        end
        fprintf(smasses(subs),'\tTotal \nYear \tseason \tlistind \t');
        for i=1:nphases
            for j=1:n+nGZ
                fprintf(smasses(subs),'%d \t',j);
            end
        end
        for i=1:nphases+1
            fprintf(smasses(subs),'\ttotal ');
        end
        fprintf(smasses(subs),'\n');
    end

    if vegmod ~= 0 && OPmasflu ~= 0
        sleaffall(subs) = fopen([outPath 'leaffall.massflux_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        fprintf(sleaffall(subs),'Name: %s  n=%d  nyears=%d  nseason=%d  emseason=%d\n',...
            char(nameSub(subs,:)),n,nyears,nseasons,1);
        fprintf(sleaffall(subs),'Year \tSeason \tlistind \tBoxnummer \tCveg,alt \tCveg,neu');
        fprintf(sleaffall(subs),'\tCvegsoil,alt  \tCvegsoil,neu \t');
        fprintf(sleaffall(subs),'MassInVegSoil  \tMassInVege  \tTransferMass\n');
    end
    if iceandsnow && OPsnoice
        smtransfersnow(subs) = fopen([outPath 'mass_snowparticle_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
        imtransfersnow(subs) = fopen([outPath 'mass_icemelt_',deblank(char(nameSub(subs,:))),'(' runCode ').xls'], 'wt');
    end

    openfluxfiles;
end

if OPGGWcqu && solveMode==0
    skval = fopen([outPath 'gaussian.k-values(' runCode ').xls'], 'wt');
    fprintf(skval,'Gaussian constants of the boundary value problem for each season\n');
    fprintf(skval,'n= %d   nyears= %d   nseasons= %d; total %d seasons\n', ...
        n,nyears,nseasons,nyears*nseasons);
    fprintf(skval,'season \tlist of k-values\n');
end

if OPcolcon
    jointCC = fopen ([outPath 'jointCC(' runCode ').xls'], 'wt');
    fprintf(jointCC,'Joint-Cold-Condensation\n');
    fprintf(jointCC,'n=%d  nyears=%d  nseason=%d  emseason=%d\nYear \tseason \tlistind \t',...
        n,nyears,nseasons,1);
    for i=1:nphases
        fprintf(jointCC,'%s \t%s \t%s \t',cell2mat(phaseNames(i)),cell2mat(phaseNames(i)),cell2mat(phaseNames(i)));
    end
    fprintf(jointCC,'\n\t\t\t');
    for i=1:nphases
        fprintf(jointCC,'jccN \tjccS \tjccNS \t');
    end
    fprintf(jointCC,'\n');
end

if OPIndi
    arcticCont = fopen ([outPath 'arcticCont(' runCode ').txt'], 'wt');
    fprintf(arcticCont,'Arctic Contamination (Potential) in percent\n');
    fprintf(arcticCont,'This calculation will only be correct if the appropriate ACP emission file is used!!\n');
    fprintf(arcticCont,'          ');
    for subs=1:nsubs
        fprintf(arcticCont,'%s      ',char(nameSub(subs,:)));
    end
    fprintf(arcticCont,'Joint-ACP\n');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function readEmis
% reads the peak_emissions.txt and cont_emissions.txt input files and
% stores the results to the variables peakEmis and contEmis

global n nGZ nphases nseasons nyears nsubs peakEmis contEmis vol nEmis;
global onePeakEm boxNr boxPhase mTot mTot1y mTot10y ice iceandsnow dpy;
global inPath screMsg screCal MIF emBothSoils;

if screMsg
    disp(' ');
    disp('function readEmis: reads and stores peak and continuous emissions');
end

fileNames=['peak_emissions.txt';'cont_emissions.txt'];   % fileNames are stored to make reading more efficient

peakEmis = zeros(nyears*nseasons,(n+nGZ)*nphases,nsubs);
contEmis = zeros(nyears*nseasons,(n+nGZ)*nphases,nsubs);
mTot1y=0;
mTot10y=0;

fileID=zeros(2,1);
for i=1:2                                               % open 1st file 1st, 2nd file 2nd
    if exist([inPath fileNames(i,:)],'file') == 2
        fileID(i) = fopen([inPath fileNames(i,:)],'rt');
    else
        fileID(i) = fopen([MIF fileNames(i,:)],'rt');
    end
    if fileID(i) == -1
        diary off;
        fclose all;        
        error(['Cannot open file ',fileNames(i,:)]);
    else
        fgetl(fileID(i));fgetl(fileID(i));fgetl(fileID(i));fgetl(fileID(i));fgetl(fileID(i));
        nEmis(i) = fscanf(fileID(i),'%d',1);               % number of total emissions
    end

    if nEmis(i) > 0
        if screMsg
            disp2('reading',nEmis(i),'temporal emissions from file',fileNames(i,:));
        end

        % read one emission after the other
        for j=1:nEmis(i)
            season = fscanf(fileID(i),'%f',1);
            zone = fscanf(fileID(i),'%f',1);
            phase  = fscanf(fileID(i),'%f',1);
            subs = fscanf(fileID(i),'%f',1);
            mass = fscanf(fileID(i),'%f',1);

            % some verifications...
            if season ~= floor(season) || zone ~= floor(zone) || phase ~= floor(phase) || subs ~= floor(subs)
                diary off;
                fclose all;                
                error(['readEmis: season, zone, phase or subs are not integer in file ',fileNames(i,:)]);
            end
            if ~isnumeric(mass)
                diary off;
                fclose all;                
                error(['readEmis: mass is not numeric in file ',fileNames(i,:)]);
            end
            if season > nyears*nseasons
                diary off;
                fclose all;                
                error(['readEmis: emission into non-existent season in file ',fileNames(i,:)]);
            end
            if subs > nsubs
                diary off;
                fclose all;                
                error(['readEmis: emission of a non existing substance in file ',fileNames(i,:)]);
            end
            if phase > nphases || (phase == 6 && (ice == 0 && iceandsnow == 0)) || (phase == 7 && iceandsnow == 0)
                diary off;
                fclose all;
                error(['readEmis: emission into non-existent phase in file ',fileNames(i,:)]);
            end
            if zone > n
                diary off;
                fclose all;
                error(['readEmis: emission into non-existent zone in file ',fileNames(i,:)]);
            end
            if subs ~= 1
                warning(['readEmis: emission of a second substance detected in file ',fileNames(i,:)]);
                warning('          problems with the eACP might appear...');
            end
            if phase == 5
                warning(['readEmis: emission to vegetation detected in file ',fileNames(i,:)]);
                warning('          interseasonal vegvol change ignored');
            end

            if vol(phase,zone+1) == 0
                diary off;
                fclose all;
                error(['readEmis: emission into non-existent volume (phase=',num2str(phase),' zone=',num2str(zone+1),') at season ',num2str(season),' detected in file ',fileNames(i,:)]);
            else
                if season <= 10*nseasons            % sum masses that are emitted to calculate eACP1 and eACP10
                    mTot10y=mTot10y+mass;
                    if season <=nseasons
                        mTot1y=mTot1y+mass;
                    end
                end

                if i==1
                    peakEmis(season,(phase-1)*(n+nGZ)+zone,subs) = peakEmis(season,(phase-1)*(n+nGZ)+zone,subs) ...
                        + mass;
                else
                    contEmis(season,(phase-1)*(n+nGZ)+zone,subs) = contEmis(season,(phase-1)*(n+nGZ)+zone,subs) ...
                        + mass / (dpy/nseasons);
                end
            end
        end

        % if emissions should be redistributed between both soil
        % compartments, this calculation is done here (emitted masses into
        % vegsoil or baresoil compartments are proportional to their
        % volumes)
        if emBothSoils
            if screMsg
                disp('readEmis: emission are redistributed between bare and vege soil');
            end
            for j = 1:n
                warning('off','all');   % to avoid warning with div0
                volratio = vol(1,j+1)/vol(4,j+1);
                warning('on','all');
                for season=1:nseasons*nyears
                    if i==1 && (peakEmis(season,j,subs) ~= 0 || peakEmis(season,3*n+j,subs) ~= 0)
                        emasse = peakEmis(season,j,subs) + peakEmis(season,3*n+j,subs);
                        if vol(4,j+1) ~= 0      % div0 could occur otherwise
                            peakEmis(season,j,subs) = volratio*emasse/(1+volratio);
                            peakEmis(season,3*n+j,subs) = emasse / (1+volratio);
                        end
                    elseif i==2 && (contEmis(season,j,subs) ~= 0 || contEmis(season,3*n+j,subs) ~= 0)
                        emasse = contEmis(season,j,subs) + contEmis(season,3*n+j,subs);
                        if vol(4,j+1) ~= 0      % div0 could occur otherwise
                            contEmis(season,j,subs) = volratio*emasse/(1+volratio);
                            contEmis(season,3*n+j,subs) = emasse / (1+volratio);
                        end
                    end
                end
            end
        end

        if screCal
            disp2('emissions from file',fileNames(i,:));
            if i==1
                disp(peakEmis);
            else
                disp(contEmis);
            end
        end
    elseif screMsg
        disp2('no emissions detected in file',fileNames(i,:));
    end
    fclose(fileID(i));
end

if sum(sum(peakEmis(1,:,:)+contEmis(1,:,:))) == 0
    diary off;
    fclose all;    
    error('readEmis: no emissions (peak & continuous) occur in the first season');
end

% mTot is used to calculate persistence
mTot=reshape(sum(peakEmis(1,:,:),2),nsubs,1);

% onePeakEm = 1 if there are only peak emissions to only one zone, only in the first season
% first part of if checks whether emissions occur only in one season
% second part of if checks whether emissions occur only into one zone
if size(nonzeros(sum(sum(peakEmis+contEmis,2),3)),1)>1 || ...
        size(nonzeros(sum(reshape(sum(sum(peakEmis+contEmis,1),3)',n+nGZ,nphases),2)),1)>1
    onePeakEm = 0;
else
    onePeakEm = 1;
    emisbox = mod(find(peakEmis(1,:,1)+contEmis(1,:,1))-1,n)+1;        % for peak emissions, the box into which the emission occurs is relevant (calculation of SpatialRange)
    boxNr = emisbox(1); % this construction is necessary, if one peak emission to two different media in the same zone (=> size of emisbox ~= 1,1)
    emisphase = floor((find(peakEmis(1,:,1)+contEmis(1,:,1))-1)/n)+1;   % dito...
    boxPhase = emisphase(1); 
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setParameters
% this function sets basic parameters. in addition, it checks whether a
% parameters.m file exists in the input directory. in such a case, the
% default parameter values given in this function are overwritten by the
% values inside the file (preparation for uncertainty analysis)

global year firstRun emBothSoils atmHeightTemp diff_hI;
global exposLimit maxExpos foc_S frf_S tsp;
global nphases lenghalfMer t0 TWaterLim hwater hsoil hgas hvegsoil;
global R rho foc fracairsoil fracwsoil rhopart;
global fossusp nFluxes s2d dpy fracpartair;
global SeaPartPolar SeaPartBoreal SeaPartTemperate fracsuspw scavratio;
global SeaPartVelociPolar SeaPartVelociBoreal SeaPartVelociTemperate;
global vdry_S scavratioSnow hice ssa_SF vdry_I wpf rho_SF lex ldep;
global rhoW_243 rhoW_268 t0_kia ddf_I ddf_S deepice rho_I ssa_I;
global fw_I fom_I porosity_I fa_I rho_newS rho_oldS ssa_newS ssa_oldS;
global vdry vleach vrunoff vgasW vwater vgasS vsoilG vsoilW vrain;
global minStabilBS minStabilCon minStabilDec minStabilGras;
global maxStabilBS maxStabilCon maxStabilDec maxStabilGras screMsg;
global dEddyWatScale dEddyAtmScale;

if screMsg
    disp(' ');
    disp('function setParameters: sets some model parameters');
end

year = 1; % counts the simulation years from the beginning
firstRun = true; % flag for first simulated year
% firstRun2 = true; % flag for first simulated year (for function showct)
emBothSoils = true; % emissions into BS are mapped into VS (see calcc0)

exposLimit = 10; % break criteria for exposure summation
maxExpos = 0.0; % container for the largest exposure value in actual season

nphases = 7;
lenghalfMer = 2E9; % (approx.) length of the half meridian, in cm
t0 = 298.15; % reference temperature, in K
TWaterLim = 270; % (virtually) lowest Temperature of water phase, in K
hwater = 200; % depth of water phase, adjusted after Ballschmitter, in m
hsoil = 0.1; % depth of soil compartment, in m
if atmHeightTemp  % height of atmosphere, in m
    hgas = 3000;
else
    hgas = 6000;
end
hvegsoil = hsoil; % depth of vegetation-covered soil
hice = 0.1;

R = 8.31451; % ideal gas constant, in SI units
rho = 2.4; % density of the soil, for conversion of Koc into Ksw etc...
foc = 0.02; % fraction of organic carbon in the bare soil
fracairsoil = 0.2; % volume fraction of air in soil
fracwsoil = 0.3; % volume fraction of water in soil

% xxx the following parameters may be used for a more simplistic 
% calculation of atmospheric transport - however, the function 
% makededdytabj would have to be modified (and the variables be defined 
% globally here and wherever they will be used xxx
% Deddyworld = 4E10; % Deddy for intrahemispheric transport, in cm2/s
% Deddyequat = 5E9; % Deddy for interhemispheric transport, in cm2/s
% eddyeq = 26; % total range around equator with lower Deddy, in degrees latitude
% Deddykonst = 2E10; % constant global average, for isotropic transport, in cm2/s
% DeddyNull = 0.0; % Deddy for simulations without interclimazonic transport

% xxx the following parameters may be used for a more simplistic
% calculation of oceanic particle settling - however, the function makem
% would have to be modified (and the variables be defined globally) xxx
% ulsed = 0.01; % global mean velocity of Ocean particle sedimentation, in m/d
% fOCpart = 0.2; % global mean organic part of sea particles, by Mackay/Paterson
% fWaterPart = 5E-6; % volume fraction of suspended particles in sea, [-]

fossusp = 0.3;          % global mean organic part of sea particles, by Wania
SeaPartPolar = 5E-8;    % volume fraction of sea particles in polar zones, Wania/Mackay
                        % TotSciEnviron 1995
SeaPartBoreal = 1E-7;   % volume fraction of sea particles in boreal zones
SeaPartTemperate = 5E-7;% volume fraction of sea particles between boreal zones
fracsuspw = 1E-7;   % volume fraction of sea particles in ChemRange
                    % SeaPartVelociPolar = 2.046; % polar sea part. dep. velocity, in m/d, Falkowski, Wania
                    % SeaPartVelociBoreal = 2.046; % boreal sea part. dep. vel., in m/d, Falkowski, Wania
                    % SeaPartVelociTemperate = 2.046; % temp. sea part. dep. vel., in m/d, Falkowski, Wania
SeaPartVelociPolar = 1.23; % polar sea part. dep. velocity, in m/d, Falkowski, Butcher
SeaPartVelociBoreal = 1.23; % boreal sea part. dep. vel., in m/d, Falkowski, Butcher
SeaPartVelociTemperate = 1.23; % temp. sea part. dep. vel., in m/d, Falkowski, Butcher

% nAlps = 0.0; % relative position of the alpine zone: 0: no alpine zone; 0<nAlps<=1: alpine

nFluxes = 114; % number of mass fluxes, excluding inputs from parent compound degradation
s2d = 86400; % seconds per day
dpy = 365; % days per year

tsp = 86E-6; % total suspended air particles, in g/m3
rhopart = 2E6; % density of air particles, in g/m3
fracpartair = tsp/rhopart; % dim.less fraction of particles in air
lex=.1; %light extinction by vegetation (veg.soil)
ldep=.0001; %light extinction by penetration into soil; penetration depth =10um, compartment depth=10cm

scavratio = 2E5; % rain scavenging volume ratio
vrain = 2.33E-3; % global mean precipitation, in m/d, ca. 85 cm/yr
                 % this is the default value and will be overwritten if
                 % intermittent rainfall is switched on (in makevraintab)

% Judiths Eis Parameters (readicepars)
vdry_S = 43.2;                   % dry deposition velocity to snow [m/d]
vdry_I = 43.2;                   % dry deposition velocity to ice [m/d]
wpf = 100;                       % wind pumping factor []
scavratioSnow = 1E5;             % snow scavenging ratio
ssa_SF = 80;                     % specific surface area of a snow flake in m2/kg
rho_SF = 910;                    % denstiy of a snow flake in kg/m3
rhoW_243 = 917;                  % water density at -30°C [kg/m3]
rhoW_268 = 917;                  % density of water at -5°C (kg/m3)
t0_kia = 266.35;                 % originally, Roth et al. (2004) measured the snow air partition coefficient at 266.35 K
ddf_I = 0.008;                   % degree day factor of ice [m/d/°C]
ddf_S = 0.005;                   % degree day factor of snow [m/d/°C]
deepice = 0.5/365;               % deposition velocity to deeper ice [m/d]

rho_I = 910;                     % ice density at -45°C [kg/m3]
ssa_I = 10;                      % specific surface of ice [m2/kg]
fw_I = 0.0001;                   % volume fraction of water in ice [-]
fom_I = 4.0e-7;                  % volume fraction of organic carbon in ice [-]
porosity_I = (rhoW_243 - rho_I)/rhoW_243;
fa_I = porosity_I - fw_I;

% Judiths Schnee Parameters (readsnowpars)
rho_newS          = 200;         % density new snow (kg/m3)
rho_oldS          = 400;         % density old snow (kg/m3)
ssa_newS          = 40;          % specific surface area of new snow (m2/kg)
ssa_oldS          = 20;          % specific surface area of old snow (m2/kg)
diff_hI           = 0.1;         % diffusion depts of ice (m) xjudithx
foc_S             = 4.0e-7;      % volume fraction of organic matter in snow
frf_S             = 0.35;        % snowfall retention factor of vegetation

vdry = 260; % dry particle deposition, in m/d (without atmospheric stability)
vleach = 9.4E-4; % water runoff transfer velocity, in m/d
vrunoff = 5.5E-7; % soil runoff transfer velocity, in m/d
vgasW = 72; % substance-indep. transfer velocity for 2film-model aw, water film, in m/d
vwater = 0.72; % substance-indep. transfer velocity for 2film-model aw, air film, in m/d
vgasS = 24; % substance-indep. transfer velocity for 2film-model as, air film, in m/d
vsoilG = 0.16; % subst.-indep. transfer vel. for 2film-model as, air-filled pores
vsoilW = 6.2E-5; % subst.-indep. transfer vel. for 2film-model as, water-filled pores

minStabilBS = 1; % summer factor of atmospheric stability over bare soil
maxStabilBS = 2; % winter factor of atmospheric stability over bare soil
minStabilGras = 1; % summer factor of atmospheric stability over grassland
maxStabilGras = 2; % winter factor of atmospheric stability over grassland
minStabilCon = 1; % summer factor of atmospheric stability over coniferous soil
maxStabilCon = 5; % winter factor of atmospheric stability over coniferous soil
minStabilDec = 1; % summer factor of atmospheric stability over deciduous soil
maxStabilDec = 3; % winter factor of atmospheric stability over deciduous soil

% the following parameters are only used in case of Monte Carlo
% Simulations...
dEddyAtmScale = 1; % scaling factor for atmospheric eddy diffusion
dEddyWatScale = 1; % scaling factor for water eddy diffusion

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cockpitReport
% this function writes a cockpitReport.xls file that summarizes all key
% information and can be evaluated for batch runs

global n nAlps nyears nseasons nsubs vegmod ice iceandsnow timeSteps OPZones;
global persMatrix srMatrix acpMatrix concMatrix mfMatrix vol;
global outPath runCode nameSub onePeakEm nphases;

phaseNames={'b_soil';'water';'atmos';'v_soil';'veget';'ice';'snow'};

fID = fopen([outPath 'cockpitReport(' runCode ').xls'], 'wt');
if fID == -1
    diary off;
    fclose all;    
    error('Cannot create file cockpitReport.xls');
else
    % print header rows of file
    fprintf(fID,'CliMoChem Cockpit Report \nThis run has runCode %s \n',runCode);
    fprintf(fID,'\nRun parameters: \nn \t%d \nnsubs \t%d \nnyears \t%d \n',n,nsubs,nyears);
    fprintf(fID,'nseasons \t%d \nvegmod \t%d \nice \t%d \n',nseasons,vegmod,ice);
    fprintf(fID,'iceandsnow \t%d \nnAlps \t%d \n',iceandsnow,nAlps);

    % print information on persistence
    fprintf(fID,'\nPersistence of all substances [d]\n');
    if onePeakEm
        for i=1:nsubs
            fprintf(fID,'%s \t%1.3g \n',char(nameSub(i,:)),persMatrix(i));
        end
        fprintf(fID,'JointPersistence \t%1.3g \n',persMatrix(nsubs+1));
    else
        for i=1:nsubs+1
            fprintf(fID,'no persistence calculated: more than one peak emission detected\n');
        end
    end

    % print information on spatial range
    fprintf(fID,'\nSpatial Range of all substances (unit: fraction ');
    fprintf(fID,'of half-meridian)\nSubstance \tType_of_SR \t');
    for i=1:nphases
        fprintf(fID,'%s \t',cell2mat(phaseNames(i)));
    end
    fprintf(fID,'total');
    if onePeakEm
        fprintf(fID,'\nOnly one peak emission detected: SR represent fractions of half-meridian');
    else
        fprintf(fID,'\nMore than one peak emission detected: SR represent q2.5percent distances from poles');
    end

    for i=1:nsubs       % sr of the substances
        fprintf(fID,'\n%s \tN-SR \t',char(nameSub(i,:)));
        fprintf(fID,'%1.3g \t',srMatrix(:,i,1));
        fprintf(fID,'\n%s \tS-SR \t',char(nameSub(i,:)));
        fprintf(fID,'%1.3g \t',srMatrix(:,i,2));
        fprintf(fID,'\n%s \tNS-SR \t',char(nameSub(i,:)));
        fprintf(fID,'%1.3g \t',srMatrix(:,i,3));
    end                 % joint sr
    fprintf(fID,'\nJoint-SR \tN-SR \t');
    fprintf(fID,'%1.3g \t',srMatrix(:,nsubs+1,1));
    fprintf(fID,'\nJoint-SR \tS-SR \t');
    fprintf(fID,'%1.3g \t',srMatrix(:,nsubs+1,2));
    fprintf(fID,'\nJoint-SR \tNS-SR \t');
    fprintf(fID,'%1.3g \t',srMatrix(:,nsubs+1,3));

    % print information on arctic contamination potential
    fprintf(fID,'\n\nArctic contamination potential [%%]. Select appropriate emission scenario for correct values!!\n');
    fprintf(fID,'Substance \tmACP-1 \teACP-1 \tmACP-10 \teACP-10 ');
    for i=1:nsubs
        fprintf(fID,'\n%s ',char(nameSub(i,:)));
        fprintf(fID,'\t %1.3g ',acpMatrix(i,1:size(acpMatrix,2)));
    end
    fprintf(fID,'\nJoint-ACP ');
    fprintf(fID,'\t %1.3g ',acpMatrix(nsubs+1,1:size(acpMatrix,2)));

    % print information on concentrations
    fprintf(fID,'\n\nConcentrations [kg/m3]');
    for i=1:length(timeSteps)
        fprintf(fID,'\nTime step: \t%d \n',timeSteps(i));
        fprintf(fID,'Substance \tZone number \t');
        for j=1:nphases
            fprintf(fID,'%s \t',cell2mat(phaseNames(j)));
        end
        for j=1:nsubs
            for k=1:n
                fprintf(fID,'\n%s \t%d',char(nameSub(j,:)),k);
                fprintf(fID,'\t%1.3g ',concMatrix(k,:,j,i));
            end
        end
    end

    % print information on mass distributions (beta)
    mas_dist=zeros(length(timeSteps),nsubs,nphases);
    for i=1:length(timeSteps)
        for j=1:nsubs
            mas_dist(i,j,:) = sum(concMatrix(:,:,j,i).*vol(:,2:n+1)',1);
            mas_dist(i,j,:) = mas_dist(i,j,:)/sum(mas_dist(i,j,:));
        end
    end

    fprintf(fID,'\n\nMass Distributions [%%]');
    for i=1:length(timeSteps)
        fprintf(fID,'\nTime step: \t%d \n',timeSteps(i));
        fprintf(fID,'Substance \t\t');
        for j=1:nphases
            fprintf(fID,'%s \t',cell2mat(phaseNames(j)));
        end
        for j=1:nsubs
            fprintf(fID,'\n%s \t',char(nameSub(j,:)));
            fprintf(fID,'\t%1.3g ',mas_dist(i,j,:));
        end
    end

    % print information on mass fluxes
    mfNames={'Degradation';'Sources';'Depletion';'Transport';'Net_Accumulation'};
    fprintf(fID,'\n\nMassfluxes [kg/season]');
    for i=1:length(timeSteps)
        for j=1:length(OPZones)
            fprintf(fID,'\nTime step: \t%d \tZone number: \t%d \n',timeSteps(i),OPZones(j));
            fprintf(fID,'Substance \tfluxtype \t');
            for k=1:nphases
                fprintf(fID,'%s \t',cell2mat(phaseNames(k)));
            end
            fprintf(fID,'total');
            for k=1:nsubs
                for l=1:5
                    fprintf(fID,'\n%s \t%s',char(nameSub(k,:)),cell2mat(mfNames(l)));
                    fprintf(fID,'\t%1.3g ',mfMatrix(:,k,l,i,j));
                end
            end
        end
    end



    fclose(fID);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function level_III(dyn,q)
% level_III generates the steady-state solution of the model if nseasons is
% set to 1. No steady-state solution exists if nseasons != 1, because of
% varying environmental conditions over the year. The emissions for
% steady-state are taken from the first season of the "continuous
% emissions" input file

global screMsg outPath runCode n nphases nsubs nameSub;

phasename=['b_soil';'water ';'atmos ';'v_soil';'vegeta';'ice   ';'snow  '];

if screMsg == 1
    disp('nseasons == 1 : calculating steady-state solution ');
end

if sum(q) == 0
    if screMsg == 1
        disp('continuous emissions in first season = 0, no steady-state solution exists');
    end

    fID = fopen([outPath 'steady-state(' runCode ').xls'], 'wt');

    if fID == -1
        diary off;
        fclose all;        
        error('Cannot create file steady-state.xls');
    else
        fprintf(fID,'continuous emissions in first season = 0 \n');
        fprintf(fID,'Steady-State solution of the model does not exist!');
        fclose(fID);
    end
else
    % the steady-state solution is calculated here
    stst = inv(-dyn) * q;

    % if size of dyn and q was reduced by substraction inexistent phases
    % (to prevent 0 in the matrix -> singular matrix), stst will be
    % redimensioned here, to obtain the correct dimension as compared to
    % nphases
    if size(stst,2) ~= nsubs*nphases*n
        newstst = zeros(nsubs*nphases*n,1);
        numphases = size(stst,1)/nsubs/n;
        for subs = 1:nsubs
            newstst((subs-1)*nphases*n+1:(subs-1)*nphases*n+n*numphases,1) = ...
                stst((subs-1)*numphases*n+1:subs*numphases*n,1);
        end
    end
    stst = newstst;

    % print steady-state solution to file
    fID = fopen([outPath 'steady-state(' runCode ').xls'], 'wt');
    if fID == -1
        diary off;
        fclose all;
        error('Cannot create file steady-state.xls');
    else
        % print header row of file
        fprintf(fID,'Steady-State solution of the model (concentration in kg/m3): \n \t');

        % printf title lines for columns
        for i=1:nsubs
            for j=1:nphases
                fprintf(fID,'%s %s \t',phasename(j,:),char(nameSub(i,:)));
            end
        end

        % printf stst concentrations
        for i=1:n
            fprintf(fID,'\n%1.0d \t',i);
            for j=1:nsubs
                for k=1:nphases
                    fprintf(fID,'%1.3g \t',stst((j-1)*nphases*n+(k-1)*n+i,1));
                end
            end
        end
        fclose(fID);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function maketdry
% function maketdry reads tdry values, if intermittent rainfall is switched
% on, and writes tdry = 0 otherwise. tdry is the average time between rain
% events

global nseasons n tdry inPath breiten MIF;


% reading tdry from input file
if exist([inPath 'tdryTable.txt'],'file') == 2
    fileID = fopen([inPath 'tdryTable.txt'],'rt');
else
    fileID = fopen([MIF 'tdryTable.txt'],'rt');
end
if fileID == -1
    diary off;
    fclose all;    
    error(['Cannot open file tdryTable.txt']);
else
    tdryIn=zeros(180,12);
    for i = 1:180
        for j = 1:12
            tdryIn(i,j) = fscanf(fileID,'%f',1);
        end
    end
    fclose(fileID);
end

% interpolating to obtain a tdry in the correct nseasons & n
tdry2=zeros(180,nseasons);       % averaging over seasons
for k = 1 : nseasons
    temp = 0;
    for i = (k-1)*12/nseasons + 1 : k*12/nseasons
        temp = temp + tdryIn(:,i);
    end
    tdry2(:,k) = temp/(12/nseasons);
end

tdry = zeros(n,nseasons);
n0t=180;
breiten = 1:n0t;
dummy = n0t/n; % number of lines in TtableEarth to average per lat. zone
if dummy ~= fix(dummy)
    diary off;
    fclose all;    
    error('maketdry: n0t (lines in tdry input file) is incompatible with n (number of zones)');
end

for j = 1:nseasons                      % averaging over zones
    for i = 0:n-1
        dummy2 = 0;
        sumbreiten = 0;
        for k = 1:dummy
            dummy2 = dummy2 + tdry2(i*dummy+k,j)*breiten(i*dummy+k);
            sumbreiten = sumbreiten + breiten(i*dummy+k);
        end
        tdry(i+1,j) = dummy2/sumbreiten; % stores averaged, length-weighted temp
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makesolarrad
%this function reads global solar radiation from solarrad.txt file. It
%calculates zonal and temporal averages for the given number of zones.

global nseasons n inPath breiten solarrad MIF;

solarradIn = zeros(180,12);

% reading solarrad from input file
if exist([inPath 'solarrad.txt'],'file') == 2
    fileID = fopen([inPath 'solarrad.txt'],'rt');
else
    fileID = fopen([MIF 'solarrad.txt'],'rt');
end
if fileID == -1
    diary off;
    fclose all;    
    error(['Cannot open file solarrad.txt']);
else
    for j = 1:12
        for i = 1:180
            solarradIn(i,j) = fscanf(fileID,'%f',1);
        end
    end
    fclose(fileID);
end

% interpolating to obtain a solarrad in the correct nseasons & n
solarrad2=zeros(180,nseasons);       % averaging over seasons
for k = 1 : nseasons
    temp = 0;
    for i = (k-1)*12/nseasons + 1 : k*12/nseasons
        temp = temp + solarradIn(:,i);
    end
    solarrad2(:,k) = temp/(12/nseasons);
end

solarrad = zeros(n,nseasons);
n0t=180;
dummy = n0t/n; % number of lines in solarrad to average per lat. zone
if dummy ~= fix(dummy)
    diary off;
    fclose all;    
    error('makesolarrad: n0t (lines in solarrad input file) is incompatible with n (number of zones)');
end

for j = 1:nseasons                      % averaging over zones
    for i = 0:n-1
        dummy2 = 0;
        sumbreiten = 0;
        for k = 1:dummy
            dummy2 = dummy2 + solarrad2(i*dummy+k,j)*breiten(i*dummy+k);
            sumbreiten = sumbreiten + breiten(i*dummy+k);
        end
        solarrad(i+1,j) = dummy2/sumbreiten; % stores averaged, length-weighted temp
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function makeDeepSeaWaterTab
% this function simulates the generation of deep sea water at certain
% regions in the oceans. In these places, the formation of deep sea water
% can be a more important loss process than particle loss or degradation

global n deepSeaWaterTab vol;

sinks = [10 5 11 10]; % amount of water that sinks in the four regions
% described in Lohmann et al, 2006 in [Sv]

border_up = [80 60 -60 -60];        % upper (northern) border of sink regions
border_dw = [68 50 -85 -80];        % lower (southern) border of sink regions

deepSeaWaterTab = zeros(n,1);

for i=1:n
    iUp = 90-(i-1)*(180/n);         % calculate northern limit of zone i
    iDw = iUp-180/n;                % calculate southern limit of zone i
    for souRegion = 1:length(border_up)
        if (iUp <= border_up(souRegion) && iUp >= border_dw(souRegion)) || ...  % northern part of zone i lies within a sink region
                (iDw <= border_up(souRegion) && iDw >= border_dw(souRegion))         % southern part of zone i lies within a sink region
            % the percentage inside a source region is calculated
            percentage = (min([iUp,border_up(souRegion)])-max([iDw,border_dw(souRegion)])) ...
                /(border_up(souRegion)-border_dw(souRegion));
            % the corresponding quantity is written into deepSeaWaterTab
            deepSeaWaterTab(i) = deepSeaWaterTab(i)+percentage * sinks(souRegion);
        end
    end
end

if sum(sinks)-sum(deepSeaWaterTab) > 10*eps
    diary off;
    fclose all;    
    error('deepSeaWaterTab: mass conservation not guaranteed');
end

% from units of Sv, the deepSeaWaterTab has to be converted into rate
% constants. Thus, the amount in the current deepSeaWaterTab has to be
% devided by the volume of the corresponding compartments, and multiplied
% by 1e9 (km3 to m3)
deepSeaWaterTab = deepSeaWaterTab ./ vol(2,2:n+1)' * 1e9;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function xlsCliMoChem
% this function reads the alternative ctrl_file.txt, created by excel. it
% later sets general parameters that are usually set by the
% CCcontrol.m file. if climochem is run from excel, CCcontrol cannot be
% read, and the parameters have to be set by this function

global atmHeightTemp nAlps nGZ deepSeaWater AeroMod SizeDif;
global noTrans timeSteps OPZones OPconexp OPmasdis OPlogfil OPvegvol;
global OPsnoice OPcolcon OPmasflu OPmobfra OPGGWcqu OPLRTDeg OPIndi screMsg;
global screCal screRes saveVars zipzap aboutFile backupOpt snowseasons;
global vegseasons klok zeitstamp ice iceandsnow;
global calcFluxFlag fluxInTab snowice solveMode n inPath nyears nseasons;
global vegmod interRainFall cOHvariable nsubs startyear;

% opens ctrl_file.txt that is created by excel
fileID = fopen([inPath 'ctrl_file.txt'],'rt');
if fileID == -1
    diary off;
    fclose all;    
    error(['Cannot open file ctrl_file.txt']);
else
    n=fscanf(fileID,'%f',1);
    nyears=fscanf(fileID,'%f',1);
    startyear=fscanf(fileID,'%f',1);
    nseasons=fscanf(fileID,'%f',1);
    vegmod=fscanf(fileID,'%f',1);
    snowice=fscanf(fileID,'%f',1);
    interRainFall=fscanf(fileID,'%f',1);
    cOHvariable=fscanf(fileID,'%f',1);
    partmod=fscanf(fileID,'%f',1);
    nsubs=fscanf(fileID,'%f',1);
    outputs=fscanf(fileID,'%f',1);

    fclose(fileID);
end

solveMode=1;
atmHeightTemp=1;
nAlps = 0;
nGZ = 0;
deepSeaWater = 0;
if partmod == 1
    AeroMod = 1;
    SizeDif = 1;
elseif partmod == 0
    AeroMod = 0;
    SizeDif = 0;
end
noTrans=0;
timeSteps = 1;
OPZones = 5;
OPconexp = 1;
OPmasdis = 1;
OPlogfil = 0;
if outputs == 1
    OPvegvol = 1;
    OPsnoice = 1;
    OPcolcon = 1;
    OPmasflu = -1;
    OPmobfra = 1;
    OPGGWcqu = 1;
    OPLRTDeg = 1;
    OPIndi =1;
elseif outputs == 0
    OPvegvol = 0;
    OPsnoice = 0;
    OPcolcon = 0;
    OPmasflu = 0;
    OPmobfra = 0;
    OPGGWcqu = 0;
    OPLRTDeg = 0;
    OPIndi =0;
end
screMsg = 0;
screCal = 0;
screRes = 0;
saveVars = 0;
zipzap = 1;
aboutFile = 0;
backupOpt = 0;
snowseasons = 12;
vegseasons = 12;

% Starts diary.... do not change this!
klok = clock;
zeitstamp = [num2str(klok(1)) '_' num2str(klok(2)) '_' num2str(klok(3)) '_' ...
    num2str(klok(4)) '_' num2str(klok(5)) '_' num2str(fix(klok(6)))];

ice = false;
iceandsnow = false;
if snowice == 2
    iceandsnow = true;
end
calcFluxFlag = false;
if OPmasflu == -1
    fluxInTab=1:n;
    calcFluxFlag = true;
    OPmasflu=length(fluxInTab);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%