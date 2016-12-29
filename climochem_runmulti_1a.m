%Run through all of the scenario folders in order as set below:

function climochem_runmulti_1a(start_runs)

if (start_runs=='y')
    climochem_MultiAutoRun1c('oct25_POSF_multi_on_1','oct25_POSF_multi_on_1_lower','y');

    climochem_MultiAutoRun1c('oct25_PFOS_multi_on_1','oct25_PFOS_multi_on_1_lower','y');

    climochem_MultiAutoRun1c('oct25_all_multi_on_1','oct25_all_multi_on_1_lower','y');

    climochem_MultiAutoRun1c('oct25_xFOSAEs_multi_on_1','oct25_xFOSAEs_multi_on_1_lower','y');
    
    disp('CliMoChem successfully run for all SETS of lower and higher scenarios.');

else
    disp('Cancelled.');
end; 
