% parameters initialises CliMoChem by assigning some variables.
% Many of the environmental and model parameters are set here

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
