% CCcontrol.m: CliMoChem Control File
% This script file controls general parameters for CliMoChem runs
% and is called by CliMoChem

%%% SOLVER MODE %%%
% the new solver mode used direct matrix inversion and multiplication,
% whereas the old mode is based on a sum construction of elements in the
% matrix
% the new mode is faster and allows the inclusion of continuous emissions,
% but the old mode is better tested
% specify 1 for the new mode, 0 for the old mode
solveMode = 1;

%%% BASIC SIMULATION PARAMETERS %%%
% Specify number of zones for simulation (must be divisor of 360)
n = 10;

% Specify duration of simulation, for correct cockpitReport file, at least 
% 10 years is required (years)
nyears = 73;

% Specify the starting year (eg. 1960). This will correspond to the first
% year of emissions in the emission files, and will be printed in the mass,
% concentrations, exposition, and massflux files
startyear = 1958;

% Specify number of seasons per year. Possible inputs are 1, 4, or 12.
nseasons = 12;

%%% COMPARTMENTS %%%
% Do you want to run CliMoChem using reduced atmospheric height (3000m) and
% decreased temperatures for processes in the atmospheric compartment
% (yes=1, no=0)?
atmHeightTemp=1;

% Do you want to include a vegetation compartment (no=0, zonal av.=1
% only grass = 2, only dec. forest=3, only con.forest=4, global av.=5)?
vegmod = 1;

% Do you want to include an permanent ice only (specify 1), ice and
% seasonal snow (specify 2) or nor ice neither seasonal snow (specify 0)?
snowice = 2;

% How many alpine REGIONS do you want to include (0 or 1)? 
nAlps = 0;

% How many alpine ZONES do you want to include (0, 1, or 2)?
nGZ = 0;

% Do you want to correct for intermittent rainfall (yes=1, no=0)?
interRainFall = 1;

% Do you want to use constant OH concentration (0), Beyer OH concentration (1) or Spivakovski (2)?
cOHvariable = 2;

% Do you want to switch deepsea-water formation into account (yes =1, no = 0)?
deepSeaWater = 1;

% Aerosol ppLFER Module (0 = Koa spLFER, 1 = ppLFER)
AeroMod = 0; 
% Aerosol size differentiation (0 = one size fraction, 1 = two size fractions)
SizeDif = 0;

% special debugging switch that removes transport accross zones (1 = 
% without transport, 0 = with transport)
noTrans=0;

%%% SUBSTANCES %%%
% Number of compounds that are calculated simultaneously (parent compound &
% metabolites, 1 means no metabolites)
nsubs = 5;


%%% OUTPUT TO FILES %%%
% for which time steps should concentrations and massfluxes be plotted in
% the cockpitReport.xls file? (create column-vector)
timeSteps = 1:1:24; %[12,24,36,48,60,72,84,96,108,120]; %(Previously defined as)

% for which zones should summarized massfluxes be plotted in the
% cockpitReport.xls file? (create column-vector)
OPZones = [1,2,3,4,5,6,7,8,9,10];

% XXXX Introduce Plausibility Check for timeSteps and OPZones (below)

% for all the different options below, output files may be plotted or not...

% Vegetation Parameters & Types, Volumes, new peak emissions
OPvegvol = 1;

% Snow / Ice Parameters & Types, Volumes
OPsnoice = 1;

% concentrations, expositions (add & cum), seasonal maxima
OPconexp = 1;

% mass distribution, metabolite ratio
OPmasdis = 1;

% cold condensation & joint cold condensation
OPcolcon = 1;

% massfluxes and leaffall-massfluxes
% Storage of Massfluxes: number of zonal fluxes to be stored (0 = no fluxes 
% calculated, -1 = fluxes in all zones to be calculated)
% if 0, no leaffall-massfluxes are stored
OPmasflu = -1;

% Compartment numbers of boxes to be plotted (add further lines if necessary,
% leave empty if no (or all) fluxes are to be calculated)
fluxInTab = [];

% mobile fraction (maybe merge with indicators)
OPmobfra = 1;

% gauss-k-values, GGWpara, conc-quotient, precipitat, surface_types
OPGGWcqu = 1;

% LRTvsDegrad
OPLRTDeg = 1;

% Indicators (persistence, spatial range, acp)
OPIndi = 1;

% log-files (including diary !!!)
OPlogfil = 1;


%%% SCREEN OUTPUTS %%%
% Display all messages on screen (yes=1, no=0)?
screMsg = 1;

% Display intermediate results on screen (yes=1, no=0)?
screCal = 0;

% Display results on screen (yes=1, no=0)?
screRes = 0;

% Save all variables in .mat file (yes=1, no=0)?
saveVars = 1;

%%% ZIPPING OF LOGFILES, VARFILES, MFILES %%%
% This flag controls whether the files in the logvars directory shall be
% be zipped (1 = zip and delete original folder) or not (0 = do not zip and
% keep the logvars folder) 
zipzap = 1;

% about.txt file
% if you don't want to write a descriptive text into the about.txt file,
% specify 0 here (NOT RECOMMENDED, YOU WILL GET A MESS W/O ABOUT.TXT!!!)
aboutFile = 0;

% backup of logfile
% if you would like to create a backup of your logfile (including the
% program, CCcontrol, logfile and input directory), specify 1
backupOpt = 0;

% specify folder for backups
% backupPath = 'C:\Urs\CliMoChem\backups\fluoro';


%%% end of control parameters
%%% do not change what is written below
%%% this is used for consistency check for massfluxes, snow and ice and
%%% others...

% number of seasons in the input files for vegetation and snow parameters
snowseasons = 12;
vegseasons = 12;

if OPlogfil
    % Starts diary.... do not change this!
    klok = clock;
    zeitstamp = [num2str(klok(1)) '_' num2str(klok(2)) '_' num2str(klok(3)) '_' ...
        num2str(klok(4)) '_' num2str(klok(5)) '_' num2str(fix(klok(6)))];

    % specify path for logfiles
    mkdir([outPath,'logvars(',runCode,')']);
    logvars=[outPath 'logvars(',runCode,')'];
    % logfile.start
    diaryname = [logvars filesep 'CliMoChemRun-' zeitstamp '.log'];
    diary(diaryname);
    disp(' ');
    disp2('Logfile-Name:', diaryname);
elseif backupOpt
    error('unable to copy backupfile if OPlogfile un-selected');
end

% dirs
if ~exist(inPath,'dir')
    error('CCcontrol.m: Cannot find folder %s',inPath);
end
if ~exist(outPath,'dir')
    warning('CCcontrol.m: outPath folder %s not found, I''ll try to create it',...
        outPath);
    mkdir(outPath);
end

% n
if (mod(180,n) ~= 0) || (floor(n) ~= n) || n < 0
    error('CCcontrol.m: number of zones (n) must be a positive integer factor of 180');
end
 
% nyears
if floor(nyears) ~= nyears || nyears < 0
    error('CCcontrol.m: number of simulation years (nyears) must be a positive integer.');
end

% nseasons
if nseasons == 1 || nseasons == 4 || nseasons ==12
    disp2('running program with',nseasons,'season(s)');
else
    error('CCcontrol.m: number of seasons per year (nseasons) must either be 1, 4 or 12.');
end

% vegmod
if ~sum(find([1:6]==vegmod+1))
    error('CCcontrol.m: vegmod parameter must be either 0,1,2,3,4, or 5.');
end

% snowice
if snowice ~= 0 && snowice ~= 2
    error('CCcontrol.m: snowice parameter must be either 0 or 2.');
end

ice = false;
iceandsnow = false;
if snowice == 0
    if screMsg
        disp('CCcontrol.m: calculations without ice and snow');
    end
elseif snowice == 1
    ice = true;
    if screMsg
        disp('CCcontrol.m: calculations with permanent ice cover only');
    end
elseif snowice == 2
    iceandsnow = true;
    if screMsg
        disp('CCcontrol.m: calculations with permanent ice and seasonal snow cover');
    end
end

% nAlps & nGZ
if ~sum(find([1:2]==nAlps+1))
    error('CCcontrol.m: nAlps parameter must be either 0 or 1.');
end
if ~sum(find([1:3]==nGZ+1))
    error('CCcontrol.m: nGZ parameter must be either 0, 1, or 2.');
end

% interRainFall
if ~sum(find([1:2]==interRainFall+1))
    error('CCcontrol.m: interRainFall parameter must be either 0 or 1.');
end

% cOHvariable
if ~sum(find([1:3]==cOHvariable+1))
    error('CCcontrol.m: cOHvariable parameter must be either 0, 1, or 2.');
end
if screMsg
    if cOHvariable == 0
        disp('CCcontrol.m: calculations with constant OH radical concentrations');
    elseif cOHvariable == 1
        disp('CCcontrol.m: calculations with Beyer OH radical concentrations');
    else
        disp('CCcontronl.m: calculations with Spivakovski OH radical concentrations');
    end
end 

% AeroMod and SizeDif
% Initially by CGoetz, 2size aerosols can only be calculated with ppLFER.
% There is no fundamental reason why this could not be modified, and it
% would be fairly simple to do (in define phiCoarse and phiFine in
% makeaerosolppLFER even if ~AeroMod
if ~AeroMod && SizeDif
    error('CCcontrol.m: cannot take into account 2 size aerosols without ppLFER.');
end

% nsubs
if floor(nsubs) ~= nsubs || nsubs < 0
    error('CCcontrol.m: number of substances (nsubs) must be a positive integer.');
end

% OPmasflu & fluxInTab
if ~sum(find([1:n+2]==OPmasflu+2))
    error('CCcontrol.m: OPmasflu must be either -1, 0 or a positive integer <= n.');
end

if OPmasflu > 0 && size(fluxInTab,2) ~= OPmasflu
    error('CCcontrol.m: fluxInTab badly sized: must contain OPmasflu columns.');
end

calcFluxFlag = false;
if OPmasflu == -1
    fluxInTab=1:n;
    calcFluxFlag = true;
    OPmasflu=length(fluxInTab);
else
    if OPmasflu~=0 && length(fluxInTab)~=OPmasflu
        error('CCcontrol.m: number of fluxes specified is not equal to the number of fluxes to be calculated');
    end
    for i=1:OPmasflu
        if fluxInTab(OPmasflu) > n
            error('CCcontrol.m: unable to calculate fluxes for zones > n');
        end
        calcFluxFlag = true;
    end
    fluxInTab = unique(fluxInTab);	% remove doublettes & sort
end

% screMsg, screCal, screRes
if ~sum(find([1:2]==screMsg+1))
    error('CCcontrol.m: screMsg parameter must be either 0 or 1.');
end
if ~sum(find([1:2]==screCal+1))
    error('CCcontrol.m: screCal parameter must be either 0 or 1.');
end
if ~sum(find([1:2]==screRes+1))
    error('CCcontrol.m: screRes parameter must be either 0 or 1.');
end

if (n+nGZ)*nphases > 250
    xlsprints=0;
end