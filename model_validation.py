# coding: utf-8

# ## Model SetUp and Validation Plotting

# ### Script Summary:

# Script to setup CliMoChem model and then extract and plot results after run. Follow steps outlined below. All
# functions must be defined in sequential order. General Input Parameters section contains changeable location of the
#  CliMoChem input folders (for generating input), output folders (containing model raw results data), location of
# Excel sheet (containing emissions inventory data and environmental measurements), and settings of what to plot and
# whether to run the model decoupled (separated run) or with all substances (combined run). The output are Bokeh plot
#  files with resulting concentrations across compartments, zones, and substances (as defined in the plotting cells
# at the end of the script). Before generating the model input files, you need to create the folder structure in
# advance (copy and paste the 'blank_ready_multi'). The Excel sheet must be manually set for 50% use and disposal,
# saved, input generated, and then repeated for 10% use and disposal. For questions, contact Justin Boucher (
# justin.boucher@chem.ethz.ch).

# ### 1) Set General Input Parameters

# In[18]:

# INPUTS REQUIRED FOR MODEL PREPARATION AND RESULTS EXTRACTION FUNCTIONS
import pandas as pd

# CliMoChem output folders and settings:
lower_slow_foldername = 'lower_slow_test1'  # location lower scenario CliMoChem model output (root folder)
lower_fast_foldername = 'lower_fast_test1'
higher_slow_foldername = 'higher_slow_test1'  # location higher scenario CliMoChem model output (root folder)
higher_fast_foldername = 'higher_fast_test1'

runcode = 'Test1'  # runcode set during CliMoChem run in Matlab

# todo(change these to os.path style imports)
input_excel_path = '/Users/justin/Documents/PFSA Project/'  # location of the master Excel file (containing folder)
excel_filename = 'PFSA_inventory_8a.xlsx'  # name of the master Excel file
climochem_files_path = '/Users/justin/Documents/PFSA Project/Model Runs'  # directory of the climochem folders (
# higher and lower)

# todo(set these generically with os)
climochem_foldername = '/oct25_noPOSF_multi_on_1/'
climochem_second_foldername = '/oct25_noPOSF_multi_on_1_lower/'  # location of the lower bound results folders for
# the second lower scenario

# What is the start and end year to model? (This needs to also be set in CCcontrol.m)
# todo(these should be wrapped in a class).
start_year = 1958
end_year = 2030

# todo(these should also be wrapped in the class).
# Plot Armitage's results as well?
plot_armitage = 'no'  # Can be 'yes' or 'no'
# Highlight yearly median environmental measurement value?
plot_medianvals = 'no'  # Can be 'yes' (medians & env data), 'yes_only' (just medians) or 'no' (just env)

plot_env_simple = 'yes'  # If'yes', then all environmental data are plotted in black (ie no color differentiation
# among sample locations)
show_gridlines = 'no'  # If 'no', grid lines will be removed from the plot

average_annualy = 'no'  # Average the model concentration results on an annual basis? (To smoothen the curve and
# remove seasonality)
plot_standard = 'yes'  # If yes, scenarios then for PFOS: higher/fast & lower(50%)(10%)/slow, and for xFOSA/Es:
# higher/slow & lower(50%)(10%)/fast plotted. If 'no', then settings below considered.
# If 'no' above, then:
show_fast_scenarios = 'yes'  # If 'no', the fast scenarios will not be plotted and the slow scenarios will be renamed
#  simply 'high' and 'low'
plot_second_scenario = 'yes'  # If 'yes', then the model results from using a second lower bound of use&disposal
# releases will be plotted as well

show_lessthan_loq = 'no'  # If 'yes', then plot environmental measurement values that are <LOQ and label other values
#  as "Env Measurement"
plot_zoomed = 'custom'  # If set to 'yes' will be plotted with zoomed in axes to show environmental data, if "no" the
#  zoomed out, if anything else then user can zoom in/out in browser
show_border = 'no'  # If set to 'no', the upper and right border lines on the plot will be removed
snow_ice_on = 'yes'  # If set to 'no', then the fofs for the snow and ice compartments will be removed (still need to
#  manually update cccontrol.m file)

# Run model separately for POSF, PFOS, and xFOSA/Es?
sep_run = 'yes'  # Can be 'yes' model should be run decoupled) or 'no' (to run all substances together)
# If yes:
sep_substance = 'noPOSF'  # substance to run in model (PFOS, POSF, xFOSA/Es, or noPOSF (runs all except POSF))

# ### 2) Run Inventory Extraction/Produce CliMoChem Inputs (Skip if only reviewing results)

# In[49]:

# todo(wrap gen_inputs in the class function, this will simplify the method call)
# todo(figure out a way to iterate combinations, if need be).
# Gen inputs for each scenario combination (lower inventory/slow degredation scenario, etc)
gen_inputs('lower', 'slow', lower_slow_foldername, climochem_files_path, climochem_foldername, input_excel_path,
           excel_filename, start_year, end_year, sep_run, sep_substance)
gen_inputs('lower', 'fast', lower_fast_foldername, climochem_files_path, climochem_foldername, input_excel_path,
           excel_filename, start_year, end_year, sep_run, sep_substance)
gen_inputs('higher', 'slow', higher_slow_foldername, climochem_files_path, climochem_foldername, input_excel_path,
           excel_filename, start_year, end_year, sep_run, sep_substance)
gen_inputs('higher', 'fast', higher_fast_foldername, climochem_files_path, climochem_foldername, input_excel_path,
           excel_filename, start_year, end_year, sep_run, sep_substance)


# ### Defines CliMoChem Input Generator Function

# In[2]:

def gen_inputs(inventory_scenario, degredation_scenario, output_foldername, climochem_files_path, climochem_foldername,
               input_excel_path, excel_filename, start_year, end_year, sep_run, sep_substance):
    # 1) Generate 'cont_emissions.txt'
    # Import trade data from Excel workbook file

    # Assign workbook location
    # todo(don't assign a path, use an input - make simpler)
    data_in = pd.ExcelFile(input_excel_path + excel_filename)

    # Change the pandas display option so that all text in a column/value is visible
    pd.set_option('display.max_colwidth', -1)
    pd.set_option('display.max_columns', None)

    sheet_name = 'POSF Emiss by Zone'

    # Parse imported raw Excel file, skip first rows, define header lables
    # Define the start and end columns to be imported from the sheet. Needs updated in Excel sheet columns added/removed
    # todo(seperate function in the API)
    emiss = data_in.parse(sheetname=sheet_name, header=0, skiprows=15, skip_footer=4, index_col=0,
                          parse_cols="FM:IO", parse_dates=False, date_parser=False, na_values=['NA'], thousands=None,
                          # chunksize=None,
                          convert_float=False, has_index_names=False, converters=None)

    # emiss

    # Identify dataframe columns representing lower secenario results
    # todo(seperate function in the API)
    selected_columns = [1.0, 2.0]  # include the first two columns defining the actual year and year index number
    selected_columns.extend([col for col in emiss.columns if inventory_scenario in emiss.loc[
        'scenario', col]])  # identify columns with the appropriate inventory secenario (lower or higher)

    # Create dataframe with just selected scenario results
    emiss_scenario = emiss[selected_columns]
    # emiss_scenario

    # Initiate blank dataframe to collect results
    output_frame = pd.DataFrame()

    # Convert start and end year to row index for isolating the mass values
    start_index = start_year - 1958 + 4
    end_index = end_year - 1958 + 5

    # todo(Ask justin why he used a while loop?)
    # todo(Move information that trails line to above line)
    i = 2  # start i on the third column (ie first column of actual data)
    while i < len(selected_columns):
        col_name = selected_columns[i]

        j = start_index  # start j at the first year entry

        while j < end_index:  # iterate through each year (row) and create 12 monthly rows

            # Create new data set for addition to data frame
            prev_seasons = (emiss_scenario[2][j] - 1) * 12  # identify number of previous months already included
            # print prev_seasons
            months = range(1, 13)  # define range from 1 to 12
            season = [x + prev_seasons for x in
                      months]  # add previous months to range from 1 to 12 and append to output list

            # [row index name, col index name], # duplicate 12 times to
            zone_num = [emiss_scenario.loc['zone_num', col_name]] * 12
            # represent each month of the year
            phase_num = [emiss_scenario.loc['phase_num', col_name]] * 12
            subst_num = [emiss_scenario.loc['subst_num', col_name]] * 12
            mass = [emiss_scenario[col_name][j] * 1000 / 12] * 12  # converted to kg and divided by 12 # to distribute
            #  throughout year

            # Create a dataframe with the data for this section
            temp_frame = pd.DataFrame(
                {'season': season, 'zone_num': zone_num, 'phase_num': phase_num, 'subst_num': subst_num, 'mass': mass})
            # print temp_frame
            # Append the data to main output dataframe
            output_frame = output_frame.append(temp_frame, ignore_index=True, verify_integrity=False)

            j = j + 1

        i = i + 1
    # output_frame

    # Remove all rows with a mass value of 0kg
    # output_frame_clean_a = output_frame[output_frame.mass != 0]  #CAN DEACTIVATE REMOVAL OF ZERO EMISSION ENTRIES
    output_frame_clean_a = output_frame

    # If running model individually for PFOS, POSF, or xFOSA/Es, remove all other emissions from input file:
    # todo(better ways to argparse - outside code?)
    if sep_run == 'yes':
        if sep_substance == 'POSF':
            sep_substance_num = [1]
        if sep_substance == 'PFOS':
            sep_substance_num = [2]
        if sep_substance == 'xFOSA/Es':
            sep_substance_num = [3, 4]
        if sep_substance == 'noPOSF':
            sep_substance_num = [2, 3, 4]

        output_frame_clean = output_frame_clean_a[output_frame_clean_a['subst_num'].isin(sep_substance_num)]
    else:
        output_frame_clean = output_frame_clean_a

    # Total number of emissions (needed as first line in CliMoChem input data file):
    num_emiss = str(len(output_frame_clean.index))

    # !!!USE OF ENTRY OVERWRITE WITHOUT .LOC?! Maybe OK.
    # Convert all values to integers (except the mass values, they remain as floats to keep accuracy and are not
    # rounded)
    # output_frame_clean[['season','zone_num','phase_num','subst_num','mass']] = output_frame_clean[['season',
    # 'zone_num','phase_num','subst_num','mass']].astype(int) #old method that was removing mass value's decimal place
    # todo(Justin - explain?)
    output_frame_clean[['season', 'zone_num', 'phase_num', 'subst_num']] = output_frame_clean[
        ['season', 'zone_num', 'phase_num', 'subst_num']].astype(int)

    # Rearrange column order to match CliMoChem input
    output_frame_clean = output_frame_clean[['season', 'zone_num', 'phase_num', 'subst_num', 'mass']]

    # Define intro text to be written in output file
    # todo(use 'textwrap' package for easier printing)

    text = "Continuous emissions in kg per season. Emissions are homogeneously distributed over the seasons.\n" + \
           "\n" + "Beware: Either a peak or a continuous emission has to occur in the 1st season!\n" + "Syntax: first " \
                                                                                                       "" \
                                                                                                       "" \
                                                                                                       "line gives " \
                                                                                                       "number of " \
                                                                                                       "emissions, " \
                                                                                                       "then\n" + \
           "Season\tZone\tPhase\tSubstance\tMass/Season \n" + "\n" + num_emiss + "\n"  # Print the number of total
    # emissions included in the input file

    # Create text file with intro text

    with open(climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'cont_emissions.txt',
              "w") as text_file:
        text_file.write(text)

    # Open created txt results file and append the reults data frame to it
    output_frame_clean.to_csv(
        climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'cont_emissions.txt', sep='\t',
        index=False, mode='a', header=False)
    # output_frame_clean



    # 2) Generate 'subs_prop.txt'
    sheet_name = 'Subst Prop and FOFS'

    # Parse imported raw Excel file, skip first rows, define header lables
    # Define the start and end columns to be imported from the sheet. Needs updated in Excel sheet columns added/removed

    # Extract the lower secenario values if lower scenario selected
    if degredation_scenario == 'slow':

        sub_props = data_in.parse(sheetname=sheet_name, header=None, skiprows=24, skip_footer=133, index_col=None,
                                  parse_cols="C:Y", parse_dates=False, date_parser=False, na_values=['NA'],
                                  thousands=None,
                                  # chunksize=None,
                                  convert_float=False, has_index_names=False, converters=None)

        # Write frame to a text file
        sub_props.to_csv(climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'subs_prop.txt',
                         sep='\t', index=False, mode='w', header=False)

    # Extract the lower secenario values if higher scenario selected
    elif degredation_scenario == 'fast':

        sub_props = data_in.parse(sheetname=sheet_name, header=None, skiprows=33, skip_footer=124, index_col=None,
                                  parse_cols="C:Y", parse_dates=False, date_parser=False, na_values=['NA'],
                                  thousands=None,
                                  # chunksize=None,
                                  convert_float=False, has_index_names=False, converters=None)

        # Write frame to a text file
        sub_props.to_csv(climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'subs_prop.txt',
                         sep='\t', index=False, mode='w', header=False)
    # sub_props


    # 3) Generate 'fofs.txt'
    sheet_name = 'Subst Prop and FOFS'

    # Parse imported raw Excel file, skip first rows, define header lables
    # Define the start and end columns to be imported from the sheet. Needs updated in Excel sheet columns added/removed

    # Extract the higher secenario values if lower scenario selected
    if degredation_scenario == 'slow':

        fofs_in = data_in.parse(sheetname=sheet_name, header=None, skiprows=70, skip_footer=53, index_col=None,
                                parse_cols="F:I", parse_dates=False, date_parser=False, na_values=['NA'],
                                thousands=None,
                                # chunksize=None,
                                convert_float=False, has_index_names=False, converters=None)

    # Extract the higher secenario values if higher scenario selected
    elif degredation_scenario == 'fast':

        fofs_in = data_in.parse(sheetname=sheet_name, header=None, skiprows=114, skip_footer=9, index_col=None,
                                parse_cols="F:I", parse_dates=False, date_parser=False, na_values=['NA'],
                                thousands=None,
                                # chunksize=None,
                                convert_float=False, has_index_names=False, converters=None)
    # fofs_in




    # If running model for individual substances, filter to include only needed fofs:
    # todo(better argparse & figure out what these are)
    if sep_run == 'yes':
        # Create a new combined column defined as the #Parent Substance and #Daughter Substance as a single number:
        fofs_in[4] = fofs_in[0].map(int).map(str) + fofs_in[1].map(int).map(str)
        # fofs_in
        if sep_substance == 'POSF':
            sep_substance_fofs = ['12']
        if sep_substance == 'PFOS':
            sep_substance_fofs = []
        if sep_substance == 'xFOSA/Es':
            sep_substance_fofs = ['43', '42', '35', '32',
                                  '52']  # (ie 43 = parent substance 4(xFOSE) to daughter substance 3(xFOSA))
        if sep_substance == 'noPOSF':
            sep_substance_fofs = ['43', '42', '35', '32', '52']
        fofs = fofs_in[fofs_in[4].isin(sep_substance_fofs)]
        # Delete the created column 4
        fofs = fofs.drop(4, 1)

    else:
        fofs = fofs_in

    # fofs

    # If snow and ice is turned off, remove the snow and ice compartments (#6 and 7) from the fofs input file
    if snow_ice_on == 'no':
        fofs = fofs[fofs[2].isin([1, 2, 3, 4, 5])]

    # Define/state number of fractions in file
    num_fofs = str(len(fofs.index))

    # Convert chemical IDs to integers
    fofs[[0, 1, 2]] = fofs[[0, 1, 2]].astype(int)

    text = "fractions of formation\n" + "#_of_fofs_given\n" + "#_of_parent_compound\t#_of_daughter_compound\t#_phase " \
                                                              "fof\n" + "\n" + num_fofs + "\n\n"

    # Create text file with intro text
    with open(climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'fofs.txt', "w") as text_file:
        text_file.write(text)

    # Append frame to the text file
    fofs.to_csv(climochem_files_path + climochem_foldername + output_foldername + '/MIF/' + 'fofs.txt', sep=' ',
                index=False, mode='a', header=False)

    # Print confirmation message to user
    message = 'Success: ' + inventory_scenario + "/" + degredation_scenario + ' scenario cont_emissions.txt, ' \
                                                                              'subs_prop.txt, and fofs.txt files ' \
                                                                              'written to MIF folder.'
    print message
    # todo(shouldn't this return something?)


# ### Defines CliMoChem Results Extract Function

# In[3]:

def model_extract(climochem_files_path, climochem_foldername, foldername, runcode, substance, compartment, zone):
    # Need to add space to these indexes because climochem ouput generates unneeded spaces
    compartment = compartment + '  '
    zone = zone + '  '

    # Set import folder path containing Excel sheet with raw input data
    import_path = climochem_files_path + climochem_foldername + foldername

    # Set export folder path containing the CliMoChem files for use by the model
    export_path = climochem_files_path + climochem_foldername + foldername

    # Set day of the month to assume CliMoChem results represent
    month_day = '15'

    # Change the pandas display option so that all text in a column/value is visible
    pd.set_option('display.max_colwidth', -1)
    pd.set_option('display.max_columns', None)

    # read in file, it's actually a csv file tab delimited although it's marked as being a xls file
    data_in = pd.read_csv(import_path + '/outputs/c(t).numeric2_' + substance + '(' + runcode + ').xls', sep='\t',
                          engine='python', skiprows=1, header=None)

    # data_in

    # !!! FIXED - USE OF ENTRY OVERWRITE WITHOUT .LOC?!
    # reset first three cells to match lower index for defining the multi index dataframe
    data_in.ix[0, 0] = 'year'  # data_in[0][0] = 'year'
    data_in.ix[0, 1] = 'season'  # data_in[1][0] = 'season'
    data_in.ix[0, 2] = 'listind'  # data_in[2][0] = 'listind'

    # Create tuples from first two rows defining the indexes
    arrays = [data_in.loc[0, :], data_in.loc[1, :]]
    tuples = list(zip(*arrays))

    # Define multiindex
    index = pd.MultiIndex.from_tuples(tuples, names=['compartment', 'zone'])

    # Drop first two rows of index values in initial data frame and re-create frame assigning multi index as the columns
    results = data_in.loc[2:, :]
    results.columns = index

    # data_in

    # Extract desired data by compartment and zone into new frame for plotting
    # Define compartment and zone, note that there must be 2 spaces after each index name
    selected = pd.concat([results['year'], results['season'], results[(compartment, zone)]], axis=1)

    # Create column defining the date, assuming day = 15th of the month
    selected['date'] = (month_day + '-' + selected['season '] + '-' + selected['year '])

    # !!! FIXED - USE OF ENTRY OVERWRITE WITHOUT .LOC?!
    # Run trough each row and remove the extra spaces in the date strings column
    for x in selected['date'].index:
        selected.ix[x, 'date'] = selected.ix[x, 'date'].replace(' ',
                                                                '')  # selected['date'][x] = selected['date'][
        # x].replace(' ','')

    # Convert date column to being date time object
    selected['date'] = pd.to_datetime(selected['date'])
    # selected



    # !!!FIXED - use of to_numeric now applied
    # Convert CliMoChem concentration (kg/m3) to units from environmental measurements (pg/L for ocean and snow,
    # pg/m3 for air, pg/g soil for soil)
    # First needed to convert the values that were imported as strings to float values
    if compartment == 'water  ' or compartment == 'snow  ':
        selected[compartment, zone] = pd.to_numeric(selected[compartment, zone]) / 1000 / (1 * 10 ** (-15))
        # selected[compartment,zone] = selected[compartment,zone].convert_objects(convert_numeric=True) /1000 /(
        # 1*10**(-15))

    if compartment == 'atmos  ' or compartment == 'veget  ':  # assuming vegetation can have same units as atmosphere
        #  just for reviewing results
        selected[compartment, zone] = pd.to_numeric(selected[compartment, zone]) / (1 * 10 ** (-15))
        # selected[compartment,zone] = selected[compartment,zone].convert_objects(convert_numeric=True) /(1*10**(-15))

    if compartment == 'v_soil  ' or compartment == 'b_soil  ':
        selected[compartment, zone] = pd.to_numeric(selected[compartment, zone]) * (1E+15) * (1E-3) * 1 / 1200
        # selected[compartment,zone] = selected[compartment,zone].convert_objects(convert_numeric=True) *(1E+15)*(
        # 1E-3)*1/1200

    return selected


# ### Defines Armitage CliMoChem Results Extract Function

# In[4]:

def armitage_extract(climochem_files_path, runcode, substance, compartment, zone):
    # Need to add space to these indexes because climochem ouput generates unneeded spaces
    compartment = compartment + '  '
    # zone = zone + '' #no extra spaces needed for zone

    # Set import folder path containing Excel sheet with raw input data
    import_path = climochem_files_path + '/armitage_results/model_config'

    # Set day of the month to assume CliMoChem results represent
    month_day = '1'

    # Change the pandas display option so that all text in a column/value is visible
    pd.set_option('display.max_colwidth', -1)
    pd.set_option('display.max_columns', None)

    # read in file, it's actually a csv file tab delimited although it's marked as being a xls file
    data_in = pd.read_csv(import_path + '/c(t).numeric2_' + substance + '(' + runcode + ').txt', sep='\t',
                          engine='python', skiprows=1, header=None)
    # data_in

    # !!!FIXED - USE OF ENTRY OVERWRITE WITHOUT .LOC?!
    # reset first three cells to match lower index for defining the multi index dataframe
    data_in.ix[0, 0] = 'year'
    data_in.ix[0, 1] = 'season'
    data_in.ix[0, 2] = 'listind'

    # Create tuples from first two rows defining the indexes
    arrays = [data_in.loc[0, :], data_in.loc[1, :]]
    tuples = list(zip(*arrays))

    # Define multiindex
    index = pd.MultiIndex.from_tuples(tuples, names=['compartment', 'zone'])

    # Drop first two rows of index values in initial data frame and re-create frame assigning multi index as the columns
    results = data_in.loc[2:, :]
    results.columns = index
    # results


    # Extract desired data by compartment and zone into new frame for plotting
    # Define compartment and zone, note that there must be 2 spaces after each index name
    selected = pd.concat([results['year'], results['season'], results[(compartment, zone)]], axis=1)
    # selected


    # Need to reassign season number to numerical month values (February, May, August, November)
    # Create empty month column to hold mapped values (just used 0)
    selected['month'] = 0
    # Replace values to match month
    selected.loc[selected['season '] == '1', 'month'] = '2'
    selected.loc[selected['season '] == '2', 'month'] = '5'
    selected.loc[selected['season '] == '3', 'month'] = '8'
    selected.loc[selected['season '] == '4', 'month'] = '11'
    # selected


    # Create column defining the date, assuming day = 15th of the month
    selected['date'] = (month_day + '-' + selected['month'] + '-' + selected['year '])

    # !!!FIXED-USE OF ENTRY OVERWRITE WITHOUT .LOC?!
    # Run trough each row and remove the extra spaces in the date strings column
    for x in selected['date'].index:
        selected.ix[x, 'date'] = selected.ix[x, 'date'].replace(' ', '')

    # Convert date column to being date time object
    selected['date'] = pd.to_datetime(selected['date'])
    # selected

    # !!!Should use the to_numeric method instead.
    # Convert CliMoChem concentration (kg/m3) to units from environmental measurements (pg/L for ocean,
    # pg/m3 for air, pg/g for soil)
    # First needed to convert the values that were imported as strings to float values
    if compartment == 'water  ':
        selected[compartment, zone] = selected[compartment, zone].convert_objects(convert_numeric=True) / 1000 / (
            1 * 10 ** (-15))

    if compartment == 'atmos  ':
        selected[compartment, zone] = selected[compartment, zone].convert_objects(convert_numeric=True) / (
            1 * 10 ** (-15))
    # selected

    return selected


# In[5]:

# Helpful to generate text for copying and pasting the year distributions into Excel
# for i in range(1960,2051):
#     print i
#     print i
#     print i
#     print i


# ### Defines Env Data Extract and Plotting Function

# In[14]:

def generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                  excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                  higher_fast_foldername, runcode, substance, compartment, zone, plot_armitage, plot_medianvals, titles,
                  legend, yaxis_title):
    # Import environmental data from Excel workbook file

    # Assign workbook location
    data_in = pd.ExcelFile(input_excel_path + excel_filename)

    # Change the pandas display option so that all text in a column/value is visible
    pd.set_option('display.max_colwidth', -1)
    pd.set_option('display.max_columns', None)

    # Parse imported raw Excel file, skip first rows, define header lables
    ocean_table_all = data_in.parse(sheetname='PEC_ocean', header=0, skiprows=2, skip_footer=0, index_col=None,
                                    parse_cols=None, parse_dates=True, date_parser=True, na_values=['NA'],
                                    thousands=None,
                                    # chunksize=None,
                                    convert_float=False, converters=None)  # has_index_names=False,

    air_table_all = data_in.parse(sheetname='PEC_air', header=0, skiprows=2, skip_footer=0, index_col=None,
                                  parse_cols=None, parse_dates=True, date_parser=True, na_values=['NA'], thousands=None,
                                  # chunksize=None,
                                  convert_float=False, converters=None)  # has_index_names=False

    # Filter to only plot certain zones:
    all_zones = range(1, 11)
    northern = range(1, 6)
    southern = range(6, 11)
    zone_list = [int(zone)]  # add desired zones here or link to input zone
    ocean_table_int = ocean_table_all[ocean_table_all['climochem_zone'].isin(zone_list)]
    air_table_int = air_table_all[air_table_all['climochem_zone'].isin(zone_list)]
    # air_table

    # Remove any environmental data points chosen to be excluded in the Excel sheet if exclude column for that
    # species contains a "yes"

    #todo(put in method - better argparse)
    if substance == 'xFOSAs':
        if any(air_table_int['exclude_xFOSAs'].isin(['yes', 'hard_yes'])):
            air_table_int1 = air_table_int[air_table_int.exclude_xFOSAs != 'yes']
            air_table = air_table_int1[air_table_int1.exclude_xFOSAs != 'hard_yes']
        else:
            air_table = air_table_int

    elif substance == 'xFOSEs':
        if any(air_table_int['exclude_xFOSEs'].isin(['yes', 'hard_yes'])):
            air_table_int1 = air_table_int[air_table_int.exclude_xFOSEs != 'yes']
            air_table = air_table_int1[air_table_int1.exclude_xFOSEs != 'hard_yes']
        else:
            air_table = air_table_int

    elif substance == 'PFOS':
        if any(ocean_table_int['exclude_PFOS'].isin(['yes', 'hard_yes'])):
            ocean_table_int1 = ocean_table_int[ocean_table_int.exclude_PFOS != 'yes']
            ocean_table = ocean_table_int1[ocean_table_int1.exclude_PFOS != 'hard_yes']
        else:
            ocean_table = ocean_table_int

    elif substance == 'xFOSAEs':
        if any(air_table_int['exclude_xFOSEs'].isin(['yes', 'hard_yes'])):
            air_table_int1 = air_table_int[air_table_int.exclude_xFOSEs != 'yes']
            air_table_int2 = air_table_int1[air_table_int1.exclude_xFOSEs != 'hard_yes']
            air_table_int3 = air_table_int2[air_table_int2.exclude_xFOSAs != 'yes']
            air_table = air_table_int3[air_table_int3.exclude_xFOSAs != 'hard_yes']
        else:
            air_table = air_table_int

    # Set plot titles
    # Only show the plot title for each plot if turned on
    if titles == 'on':
        # Set text for the plot titles using defined zone ranges
        zone_names = {'1': 'Zone 1 (72°-90°N)', '2': 'Zone 2 (54°-72°N)', '3': 'Zone 3 (36°-54°N)',
                      '4': 'Zone 4 (18°-36°N)', '5': 'Zone 5 (0°-18°N)', '6': 'Zone 6 (18°S-0°)',
                      '7': 'Zone 7 (36°-18°S)', '8': 'Zone 8 (54°-36°S)', '9': 'Zone 9 (72°-54°S)',
                      '10': 'Zone 10 (90°-72°S)'}
        plot_title = zone_names[zone]

    else:
        plot_title = ''

    x_axis_title = 'Year'
    # x_axis_title = ''

    if compartment == 'atmos' or compartment == 'veget':
        y_axis_unit = '[pg/m3]'
    elif compartment == 'v_soil' or compartment == 'b_soil':
        y_axis_unit = '[pg/g]'
    else:
        y_axis_unit = '[pg/L]'

    if yaxis_title == 'on':
        if compartment == 'atmos':
            y_axis_title = substance + ' Concentration in Air ' + y_axis_unit
        elif compartment == 'water':
            y_axis_title = substance + ' Concentration in Water ' + y_axis_unit
        elif compartment == 'b_soil':
            y_axis_title = substance + ' Concentration in b_Soil ' + y_axis_unit
        elif compartment == 'v_soil':
            y_axis_title = substance + ' Concentration in v_Soil ' + y_axis_unit
        elif compartment == 'ice':
            y_axis_title = substance + ' Concentration in Ice ' + y_axis_unit
        elif compartment == 'snow':
            y_axis_title = substance + ' Concentration in Snow ' + y_axis_unit
        elif compartment == 'veget':
            y_axis_title = substance + ' Concentration in Vegetation ' + y_axis_unit
        else:
            y_axis_title = substance + ' Concentration ' + y_axis_unit
    else:
        y_axis_title = ''


    #todo(get rid of remnant code - what's valuable?)
        # No longer ever summing xFOSAs and xFOSEs together, so this section ignored:

    #     #If total xFOSA/Es should be plotted (substance = 'xFOSAEs'), then extract separately from CliMoChem
    # results and sum together
    #     if substance == 'xFOSAEs':
    #         lower_results_xFOSAs = model_extract(climochem_files_path, climochem_foldername, lower_foldername,
    # runcode, 'xFOSAs', compartment, zone)
    #         lower_results_xFOSEs = model_extract(climochem_files_path, climochem_foldername, lower_foldername,
    # runcode, 'xFOSEs', compartment, zone)
    #         higher_results_xFOSAs = model_extract(climochem_files_path, climochem_foldername, higher_foldername,
    # runcode, 'xFOSAs', compartment, zone)
    #         higher_results_xFOSEs = model_extract(climochem_files_path, climochem_foldername, higher_foldername,
    # runcode, 'xFOSEs', compartment, zone)

    #         #Copy xFOSAs and xFOSEs dataframes as templates to hold totals results
    #         lower_results = lower_results_xFOSAs.copy(deep=True)
    #         higher_results = higher_results_xFOSAs.copy(deep=True)
    #         #Sum xFOSA and xFOSE results together into the new dataframe
    #         lower_results[compartment+'  ', zone+'  '] = lower_results_xFOSAs[compartment+'  ', zone+'  '] +
    # lower_results_xFOSEs[compartment+'  ', zone+'  ']
    #         higher_results[compartment+'  ', zone+'  '] = higher_results_xFOSAs[compartment+'  ', zone+'  '] +
    # higher_results_xFOSEs[compartment+'  ', zone+'  ']

    # Extact CliMoChem results using function
    # Extract lower inventory scneario results
    #todo(results should be generated outside code and imported, so you can loop - reorg)
    lower_slow_results = model_extract(climochem_files_path, climochem_foldername, lower_slow_foldername, runcode,
                                       substance, compartment, zone)
    lower_fast_results = model_extract(climochem_files_path, climochem_foldername, lower_fast_foldername, runcode,
                                       substance, compartment, zone)

    # Extract higher inventory scenario results
    higher_slow_results = model_extract(climochem_files_path, climochem_foldername, higher_slow_foldername, runcode,
                                        substance, compartment, zone)
    higher_fast_results = model_extract(climochem_files_path, climochem_foldername, higher_fast_foldername, runcode,
                                        substance, compartment, zone)

    # If set, extarct the results of the second lower scenario (change in use and disposal release amount)
    if plot_second_scenario == 'yes':
        lower_slow_second_results = model_extract(climochem_files_path, climochem_second_foldername,
                                                  lower_slow_foldername, runcode, substance, compartment, zone)
        lower_fast_second_results = model_extract(climochem_files_path, climochem_second_foldername,
                                                  lower_fast_foldername, runcode, substance, compartment, zone)

    # Use bokeh to create interactive plot
    #todo(move imports up top)
    from bokeh.plotting import figure, show, output_file, ColumnDataSource
    from bokeh.models import HoverTool, BoxZoomTool, ResetTool, PanTool, WheelZoomTool

    # output_file(file_title, title = plot_title)

    # Define which environmental data to plot depending on whether ocean or atmosphere is desired.
    # IF anything other thanan PFOS/WATER OR xFOSAEs/ATMOSPHERE is selected, environmental data should not/cannot be
    # plotted

    if (substance == 'PFOS' and compartment == 'water') or (substance == 'xFOSAs' and compartment == 'atmos') or (
                    substance == 'xFOSEs' and compartment == 'atmos') or (
                    substance == 'xFOSAEs' and compartment == 'atmos'):

        if compartment == 'water':
            selected_table = ocean_table
        else:
            selected_table = air_table

        # If the median values are set to be plotted, then calculate them
        if (plot_medianvals == 'yes') or (plot_medianvals == 'yes_only'):

            # Identify the unique sampling years included in the environmental data for this zone
            years = selected_table['sampling_time'].dt.year.unique()
            # years

            # Create empty lists to collect results
            medians = []
            median_dates = []

            # Loop through measurements for each year to calculate the median value
            for i in years:
                # Select only measurements in the table for the specific year, select the concentrations,
                # and calculate the median
                median_value = selected_table[selected_table['sampling_time'].dt.year.isin([i])][substance].median()
                # median_value

                # Save median to series for output and later plotting
                medians.append(median_value)
                # medians

                # Select start of period range in list, order chronologically using .head()
                ordered_times = selected_table[selected_table['sampling_time'].dt.year.isin([i])][
                    'sampling_time'].head().reset_index()
                # Calculate median time in the range of env measurements = start time + (end time - start time)/2
                median_time = ordered_times['sampling_time'][0] + (
                    (ordered_times['sampling_time'][len(ordered_times) - 1] - ordered_times['sampling_time'][0]) / 2)
                # median_time
                # Save date to series for output and later plotting (CURRENTLY IS A TIMESTAMP, CHECK TO SEE IF THIS
                # CAUSES ERRORS)
                median_dates.append(median_time)
                # median_dates

                # convert to datetime series for plotting

                # median_dates_plot = [dt.datetime(x.year,x.month,x.day,x.hour,x.minute,x.second) for x in median_dates]
                # print medians
                # print median_dates

        # Define separate colors for each of the environmental data by ocean/sampling location, create new column in
        # selected_table
        # If env data should be plotted simply, then all environmental data will be plotted as black (#000000),
        # else follow set colors by ocean location
        if plot_env_simple == 'yes':
            colormap = {'atlantic': '#000000', 'arctic': '#000000', 'north_sea': '#000000', 'pacific': '#000000',
                        'southern': '#000000', 'baltic_sea': '#000000', 'land': '#000000', 'indian': '#000000'}
        else:
            colormap = {'atlantic': '#60BD68', 'arctic': '#F15854', 'north_sea': '#B2912F', 'pacific': '#5DA5DA',
                        'southern': '#B276B2', 'baltic_sea': '#DECF3F', 'land': '#4D4D4D', 'indian': 'purple'}
        selected_table['color'] = selected_table['ocean'].map(lambda x: colormap[x])

        # SPECIAL SHAPE PLOTTING START FOR ENV MEASUREMENT DATA
        # Create different tables for each of the separate environmental shapes to plot (good measurements,
        # ok measurements (values missing), gas only, or gas and particulate measurements)

        if substance == 'PFOS':
            selected_good_all = selected_table[selected_table.d_PFOS == 1]
            # selected_pfos_missing = selected_table[selected_table.d_PFOS == "0/1"]
        if substance == 'xFOSAs':
            selected_good_all = selected_table.loc[
                (selected_table.d_xFOSA == 1) & (selected_table.meas_type == "gas&particulate")]
            selected_good_gas = selected_table.loc[(selected_table.d_xFOSA == 1) & (selected_table.meas_type == "gas")]
            selected_ok_all = selected_table.loc[
                (selected_table.d_xFOSA == "0/1") & (selected_table.meas_type == "gas&particulate")]
            selected_ok_gas = selected_table.loc[
                (selected_table.d_xFOSA == "0/1") & (selected_table.meas_type == "gas")]
        if substance == 'xFOSEs':
            selected_good_all = selected_table.loc[
                (selected_table.d_xFOSE == 1) & (selected_table.meas_type == "gas&particulate")]
            selected_good_gas = selected_table.loc[(selected_table.d_xFOSE == 1) & (selected_table.meas_type == "gas")]
            selected_ok_all = selected_table.loc[
                (selected_table.d_xFOSE == "0/1") & (selected_table.meas_type == "gas&particulate")]
            selected_ok_gas = selected_table.loc[
                (selected_table.d_xFOSE == "0/1") & (selected_table.meas_type == "gas")]

        # Define data source for x and y, and also define items desired for the hover box
        source_good_all = ColumnDataSource(
            data=dict(
                x=selected_good_all["sampling_time"],
                y=selected_good_all[substance],
                zone=selected_good_all["climochem_zone"],
                ref=selected_good_all["Reference"],
                loc=selected_good_all["ocean"],
                samp=selected_good_all["Sample Nr."],
                conc=selected_good_all[substance],
                date=selected_good_all["sampling_time"].map(lambda x: x.strftime('%d-%m-%Y'))
                # get sampling time in text format
            )
        )

        if substance == "xFOSAs" or substance == "xFOSEs":
            source_good_gas = ColumnDataSource(
                data=dict(
                    x=selected_good_gas["sampling_time"],
                    y=selected_good_gas[substance],
                    zone=selected_good_gas["climochem_zone"],
                    ref=selected_good_gas["Reference"],
                    loc=selected_good_gas["ocean"],
                    samp=selected_good_gas["Sample Nr."],
                    conc=selected_good_gas[substance],
                    date=selected_good_gas["sampling_time"].map(lambda x: x.strftime('%d-%m-%Y'))
                    # get sampling time in text format
                )
            )

            source_ok_all = ColumnDataSource(
                data=dict(
                    x=selected_ok_all["sampling_time"],
                    y=selected_ok_all[substance],
                    zone=selected_ok_all["climochem_zone"],
                    ref=selected_ok_all["Reference"],
                    loc=selected_ok_all["ocean"],
                    samp=selected_ok_all["Sample Nr."],
                    conc=selected_ok_all[substance],
                    date=selected_ok_all["sampling_time"].map(lambda x: x.strftime('%d-%m-%Y'))
                    # get sampling time in text format
                )
            )

            source_ok_gas = ColumnDataSource(
                data=dict(
                    x=selected_ok_gas["sampling_time"],
                    y=selected_ok_gas[substance],
                    zone=selected_ok_gas["climochem_zone"],
                    ref=selected_ok_gas["Reference"],
                    loc=selected_ok_gas["ocean"],
                    samp=selected_ok_gas["Sample Nr."],
                    conc=selected_ok_gas[substance],
                    date=selected_ok_gas["sampling_time"].map(lambda x: x.strftime('%d-%m-%Y'))
                    # get sampling time in text format
                )
            )

        # Setup hover option, define names of plot objects that the HoverTool should be active for
        hover = HoverTool(names=["good_all", "good_gas", "ok_all", "ok_gas", "median"],
                          tooltips=[
                              ("Date", "@date"),
                              ("Conc.", "@conc"),
                              ("Zone", "@zone"),
                              ("Reference", "@ref"),
                              ("Location", "@loc"),
                              ("Sample#", "@samp"),
                          ]
                          )

        # Define interactive tools to use
        # tools = [BoxZoomTool(), ResetTool(),PanTool(),hover, save] #WheelZoomTool(), turned off
        tools = 'pan,box_zoom,reset,hover,save,wheel_zoom'

        # Setup the bokeh figure to plot the environmental data
        p = figure(title=plot_title, x_axis_type="datetime", tools=tools)

        # Plot the median values as black squares if they are to be plotted, or just the environmental data as
        # circles if not

        if substance == "PFOS":
            if plot_medianvals == 'yes':
                p.square(median_dates, medians, color='#000000', name='median', legend="Median Env Meas",
                         fill_alpha=0.2, size=10)
                if show_lessthan_loq == 'yes':
                    good_all_name = ">LOQ Value"
                else:
                    good_all_name = "Measured"
                p.circle('x', 'y', color=selected_good_all['color'], name='good_all', source=source_good_all,
                         legend=good_all_name, fill_alpha=0.2, size=10)

            elif plot_medianvals == 'yes_only':
                p.square(median_dates, medians, color='#000000', name='median', legend="Median Env Meas",
                         fill_alpha=0.2, size=10)

            else:
                if show_lessthan_loq == 'yes':
                    good_all_name = ">LOQ Value"
                else:
                    good_all_name = "Measured"
                p.circle('x', 'y', color=selected_good_all['color'], name='good_all', source=source_good_all,
                         legend=good_all_name, fill_alpha=0.2, size=10)

        # Depending on whether <LOQ environmntal values are set to be plotted, plot env values and put appropriate
        # name in the legend
        elif substance == "xFOSAs" or substance == "xFOSEs":
            if plot_medianvals == 'yes':
                p.square(median_dates, medians, color='#000000', name='median', legend="Median Env Meas",
                         fill_alpha=0.2, size=10)
                if show_lessthan_loq == 'yes':
                    p.triangle('x', 'y', color=selected_ok_all['color'], name='ok_all', source=source_ok_all,
                               legend="<LOQ Value", fill_alpha=0.2, size=10)
                    p.triangle('x', 'y', color=selected_ok_gas['color'], name='ok_gas', source=source_ok_gas,
                               legend="<LOQ (Gas Only)", fill_alpha=0.0, size=10)
                    good_all_name = '>LOQ Value'
                    good_ok_name = '>LOQ (Gaseous Only)'
                else:
                    good_all_name = 'Measured (Gaseous & Particulate)'
                    good_ok_name = 'Measured (Gaseous Only)'
                p.circle('x', 'y', color=selected_good_all['color'], name='good_all', source=source_good_all,
                         legend=good_all_name, fill_alpha=0.2, size=10)
                p.circle('x', 'y', color=selected_good_gas['color'], name='good_gas', source=source_good_gas,
                         legend=good_ok_name, fill_alpha=0.0, size=10)

            elif plot_medianvals == 'yes_only':
                p.square(median_dates, medians, color='#000000', name='median', legend="Median Env Meas",
                         fill_alpha=0.2, size=10)

            else:
                if show_lessthan_loq == 'yes':
                    p.triangle('x', 'y', color=selected_ok_all['color'], name='ok_all', source=source_ok_all,
                               legend="<LOQ Value", fill_alpha=0.2, size=10)
                    p.triangle('x', 'y', color=selected_ok_gas['color'], name='ok_gas', source=source_ok_gas,
                               legend="<LOQ (Gas Only)", fill_alpha=0.0, size=10)
                    good_all_name = '>LOQ Value'
                    good_ok_name = '>LOQ (Gaseous Only)'
                else:
                    good_all_name = 'Measured (Gaseous & Particulate)'
                    good_ok_name = 'Measured (Gaseous Only)'
                p.circle('x', 'y', color=selected_good_all['color'], name='good_all', source=source_good_all,
                         legend=good_all_name, fill_alpha=0.2, size=10)
                # UPDATED: now field measurements that are only gaseous are triangles
                p.cross('x', 'y', color=selected_good_gas['color'], name='good_gas', source=source_good_gas,
                        legend=good_ok_name, fill_alpha=0.0, size=10)

        message = "Zone " + zone + " environmental data plotted."
        env_data_var = 'yes'  # environmental data available, flag used later to count points

    else:
        # Define interactive tools to use
        tools2 = [BoxZoomTool(), ResetTool(), PanTool(), WheelZoomTool()]
        p = figure(title=plot_title, x_axis_type="datetime", tools=tools2)
        env_data_var = 'no'  # environmental data available, flag used later to count point

        message = "Zone " + zone + ": no environmental data available to be plotted."

    # Count and print the number of environmental data points plotted (if relevant):
    if env_data_var == 'yes':
        if substance == "xFOSAs" or substance == "xFOSEs":
            num_env_points = len(selected_good_gas["sampling_time"]) + len(selected_good_all["sampling_time"])
        elif substance == "PFOS":
            num_env_points = len(selected_good_all["sampling_time"])

        print "Number of env points plotted = " + str(num_env_points)

    # Configure figure, set title, x axis type, and tools to be used
    p.xaxis.axis_label = x_axis_title
    p.yaxis.axis_label = y_axis_title

    # Plot the CliMoChem result lower and higher scenarios
    # Can average the annual concentration of the model results in order to remove seasonality and produce a smoother
    #  curve.
    # Result then plotted on July 2 of the year (representative of the middle of the year)
    if average_annualy == 'yes':
        higher_fast_date, higher_fast_conc = annual_average(higher_fast_results)
        lower_slow_date, lower_slow_conc = annual_average(lower_slow_results)
        lower_slow_second_date, lower_slow_second_conc = annual_average(lower_slow_second_results)
        higher_slow_date, higher_slow_conc = annual_average(higher_slow_results)
        lower_fast_date, lower_fast_conc = annual_average(lower_fast_results)
        lower_fast_second_date, lower_fast_second_conc = annual_average(lower_fast_second_results)
        print 'Avg scenarios made'

    else:
        higher_fast_date = higher_fast_results['date']
        lower_slow_date = lower_slow_results['date']
        lower_slow_second_date = lower_slow_second_results['date']
        higher_slow_date = higher_slow_results['date']
        lower_fast_date = lower_fast_results['date']
        lower_fast_second_date = lower_fast_second_results['date']

        higher_fast_conc = higher_fast_results[compartment + '  ', zone + '  ']
        lower_slow_conc = lower_slow_results[compartment + '  ', zone + '  ']
        lower_slow_second_conc = lower_slow_second_results[compartment + '  ', zone + '  ']
        higher_slow_conc = higher_slow_results[compartment + '  ', zone + '  ']
        lower_fast_conc = lower_fast_results[compartment + '  ', zone + '  ']
        lower_fast_second_conc = lower_fast_second_results[compartment + '  ', zone + '  ']
        print 'Non average scenarios made'

    # Set line wideth for all lines:
    width_val = 4

    # Standard scenarios to plot are: higher/fast, lower(50%)/slow, and lower(10%)/slow
    if plot_standard == 'yes':
        # Plot higher/fast and lower/slow scenarios for PFOS:
        if substance == 'PFOS':
            p.line(higher_fast_date, higher_fast_conc, name='higher/fast', legend="High", color='#F15854',
                   line_width=width_val)  # "Higher/Fast"
            p.line(lower_slow_date, lower_slow_conc, name='lower/slow', legend="Medium", color='#5DA5DA',
                   line_width=width_val)  # "Lower(50%)/Slow"
            p.line(lower_slow_second_date, lower_slow_second_conc, name="lower_slow_second", legend="Low",
                   color='#5D61DA', line_width=width_val)  # "Lower(10%)/Slow"

        # Plot higher/slow and lower/fast scenarios for xFOSA/Es:
        elif (substance == 'xFOSAs') or (substance == 'xFOSEs'):
            p.line(higher_slow_date, higher_slow_conc, name='higher/slow', legend="High", color='#F15854',
                   line_width=width_val)  # "Higher/Slow"
            p.line(lower_fast_date, lower_fast_conc, name='lower/fast', legend="Medium", color='#5DA5DA',
                   line_width=width_val)  # "Lower(50%)/Fast"
            p.line(lower_fast_second_date, lower_fast_second_conc, name="lower_fast_second", legend="Low",
                   color='#5D61DA', line_width=width_val)  # "Lower(10%)/Fast"

        else:
            print "Only PFOS and xFOSA/Es can be plotted with these settings. Results no longer accurate. See " \
                  "plotting function code."

    # Otherwise, specific options set come into effect
    else:
        # The higher/fast, lower/fast scenarios can not be plotted based on the settings
        if show_fast_scenarios == 'yes':
            p.line(higher_fast_date, higher_fast_conc, name='higher/fast', legend="Higher/Fast", color='#F15854',
                   line_width=width_val, line_dash=[3])
            p.line(lower_fast_date, lower_fast_conc, name='lower/fast', legend="Lower/Fast", color='#5DA5DA',
                   line_width=width_val, line_dash=[3])
            higher_slow_name = 'Higher/Slow'
            lower_slow_name = 'Lower/Slow(50%)'
        else:
            higher_slow_name = 'Higher'
            lower_slow_name = 'Lower(50%)'  # Should be "Lower(50%) when plotting both lower scenarios

        p.line(higher_slow_date, higher_slow_conc, name=higher_slow_name, legend=higher_slow_name, color='#F15854',
               line_width=width_val)
        p.line(lower_slow_date, lower_slow_conc, name=lower_slow_name, legend=lower_slow_name, color='#5DA5DA',
               line_width=width_val)

        # Plot the second lower scenario (if set to do so) from the set folder source
        if plot_second_scenario == 'yes' and show_fast_scenarios == 'yes':
            p.line(lower_slow_second_date, lower_slow_second_conc, name="lower_slow_second", legend="Lower/Slow(10%)",
                   color='#5D61DA', line_width=width_val)
            p.line(lower_fast_second_date, lower_fast_second_conc, name="lower_fast_second", legend="Lower/Fast(10%)",
                   color='#5D61DA', line_width=width_val, line_dash=[3])

        if plot_second_scenario == 'yes' and show_fast_scenarios == 'no':
            p.line(lower_slow_second_date, lower_slow_second_conc, name="lower_slow_second", legend="Lower(10%)",
                   color='#5D61DA', line_width=width_val)

    # Plot the results from the Armitage study (if desired)
    if plot_armitage == 'yes':
        armitage_pfos_direct = armitage_extract(climochem_files_path, 'PFOS1new', 'PFOS', compartment, zone)
        armitage_pfos_degraded = armitage_extract(climochem_files_path, 'POSF5new', 'PFOS', compartment, zone)
        armitage_xFOSA = armitage_extract(climochem_files_path, 'POSF5new', 'xFOSA', compartment, zone)
        armitage_xFOSE = armitage_extract(climochem_files_path, 'POSF5new', 'xFOSE', compartment, zone)

        # Create copy of data frame to hold total values
        armitage_xFOSAEs_total = armitage_xFOSA.copy(deep=True)
        armitage_pfos_total = armitage_pfos_direct.copy(deep=True)

        # !!!USE OF ENTRY OVERWRITE WITHOUT .LOC?!
        # Sum appropriate columns to create new total dataframes as an option for graphing
        armitage_xFOSAEs_total[compartment + '  ', zone] = armitage_xFOSA[compartment + '  ', zone] + armitage_xFOSE[
            compartment + '  ', zone]
        armitage_pfos_total[compartment + '  ', zone] = armitage_pfos_direct[compartment + '  ', zone] + \
                                                        armitage_pfos_degraded[compartment + '  ', zone]

        # Define which armitage results to plot
        if substance == 'PFOS':
            p.line(armitage_pfos_total['date'], armitage_pfos_total[compartment + '  ', zone], name='armitage',
                   legend="Armitage et al.", color='#60BD68', line_width=width_val)  # pink line
        elif substance == 'xFOSAEs':
            p.line(armitage_xFOSAEs_total['date'], armitage_xFOSAEs_total[compartment + '  ', zone], name='armitage',
                   legend="Armitage et al.", color='#60BD68', line_width=width_val)  # green line
        elif substance == 'xFOSAs':
            p.line(armitage_xFOSA['date'], armitage_xFOSA[compartment + '  ', zone], name='armitage',
                   legend="Armitage et al.", color='#60BD68', line_width=width_val)  # green line
        elif substance == 'xFOSEs':
            p.line(armitage_xFOSE['date'], armitage_xFOSE[compartment + '  ', zone], name='armitage',
                   legend="Armitage et al.", color='#60BD68', line_width=width_val)  # green line

    # Define location of the legend
    if legend == 'on':
        p.legend.orientation = "vertical"
        # Remove border around the legend box by setting 'none'
        p.legend.border_line_color = None
        p.legend.location = "top_left"
    else:
        p.legend.location = None

    # Set zoom level of the plots and fix the axes to show the desired ranges for publication
    # Need to convert the year of the desired range into milliseconds in order to be understand by Bokeh
    import datetime
    epoch = datetime.datetime.utcfromtimestamp(0)

    def unix_time_millis(year):
        dt = datetime.datetime(year, 1, 1, 0, 1, 0)
        return (dt - epoch).total_seconds() * 1000.0

    zoom_lower = unix_time_millis(2004)  # set year here for range
    zoom_upper = unix_time_millis(2012)  # set year here for range
    standard_lower = unix_time_millis(1960)  # set year here for range
    standard_upper = unix_time_millis(2040)  # set year here for range

    from bokeh.models import Range1d, FixedTicker
    if plot_zoomed == 'yes':
        p.x_range = Range1d(zoom_lower, zoom_upper)
        # p.y_range = Range1d(0,)
        p.xaxis[0].ticker = FixedTicker(ticks=[unix_time_millis(x) for x in range(2004, 2014,
                                                                                  1)])  # Set tick marks every 10
        # years within set range here
    elif plot_zoomed == 'no':
        p.x_range = Range1d(standard_lower, standard_upper)
        # p.y_range = Range1d(0,)
        p.xaxis[0].ticker = FixedTicker(ticks=[unix_time_millis(x) for x in range(1960, 2040,
                                                                                  10)])  # Set tick marks every 10
        # years within set range here

    # Change the plot border thickness (not the axes lines)
    if show_border == 'no':
        p.outline_line_width = 0
        p.outline_line_alpha = 0

    # Remove the grid lines from being plotted if set
    if show_gridlines == 'no':
        p.xgrid.grid_line_color = None
        p.ygrid.grid_line_color = None

    # Trying to edit the date label on the plot, but this still is not working.
    from bokeh.models import DatetimeTickFormatter
    # Format x axis labels
    DatetimeTickFormatter(
        formats=dict(
            hours=["%B %Y"],
            days=["%B %Y"],
            months=["%B %Y"],
            years=["%B %Y"],
        )
    )

    selected_font = "cambria"

    # Font sizes on chart:
    p.xaxis.axis_label_text_font_size = "25pt"
    p.yaxis.axis_label_text_font_size = "25pt"
    p.title_text_font_size = "27pt"
    p.xaxis.major_label_text_font_size = "25pt"
    p.yaxis.major_label_text_font_size = "25pt"

    p.xaxis.axis_label_text_font = selected_font
    p.yaxis.axis_label_text_font = selected_font
    p.title_text_font = selected_font
    p.xaxis.major_label_text_font = selected_font
    p.yaxis.major_label_text_font = selected_font

    # Set axes and labels to being black
    p.xaxis.axis_line_color = "#000000"
    p.yaxis.axis_line_color = "#000000"
    p.xaxis.major_label_text_color = "#000000"
    p.yaxis.major_label_text_color = "#000000"
    p.xaxis.axis_label_text_color = "#000000"
    p.yaxis.axis_label_text_color = "#000000"
    p.title_text_color = "#000000"
    p.axis.minor_tick_line_color = "#000000"
    p.axis.major_tick_line_color = "#000000"

    # Set the number of desired ticks for the axes
    p.yaxis[0].ticker.desired_num_ticks = 4
    p.xaxis[0].ticker.desired_num_ticks = 5

    # return the bokeh plot object, can then view directly using the command show()
    print message
    return p


# ### Function to Calculate the Annual Average Values for the Model Results 

# In[7]:

# Input is the results dataframe as output from the model extraction function
def annual_average(results):
    # Group by year and calculate the average value for each year
    mean_results = results.groupby('year ').mean().reset_index()

    # Set to plot every annual mean on July 2 since this is the middle of the average year
    mean_results['mean_date'] = mean_results['year '] + '-07-02'

    # !!!FIXED - USE OF ENTRY OVERWRITE WITHOUT .LOC?!
    # Remove the extra space in the year parameter so that it can have the correct date format
    for x in range(0, len(mean_results['mean_date'])):
        mean_results.ix[x, 'mean_date'] = mean_results.ix[x, 'mean_date'].replace(" ",
                                                                                  "")  # mean_results['mean_date'][x]
        #  = mean_results['mean_date'][x].replace(" ", "")

    # !!!USE OF ENTRY OVERWRITE WITHOUT .LOC?! ok?
    # Convert date column to being date time object
    mean_results['mean_date_time'] = pd.to_datetime(mean_results['mean_date'])

    # Reset the name of the concentration column so the results can be generically exported
    mean_results.columns = ['year', 'mean_conc', 'mean_date', 'mean_date_time']

    return mean_results['mean_date_time'], mean_results['mean_conc']


# ### 3) Run CliMoChem Model in Matlab

# ### 4) Call Results Functions and Show Plots for All Zones

# ### All Zones w/ SVG Output

# Note to remember: Need to add "?svg=1" to the end of the file name in the browser bar. Also need to include
# "mode="inline" in the outputfile(). Installed and built the branch of Bokeh (0.11.1-62-g4c7244f) from Sarah Bird in
#  order to use her export to svg function (https://github.com/bokeh/bokeh/pull/3867). First plot is Zone 1 with the
# legend visible.

# In[21]:

from bokeh.io import output_file, show, vplot

substance_list = 'xFOSAs'  # substance data to plot (PFOS (water), POSF (no env data), xFOSAs (atmos),
# xFOSEs (atmos), or xFOSAEs (atmos))
compartment_list = 'atmos'  # soil compartment options are "b_soil" and "v_soil", snow compartment is "snow",
# atomosphere is "atmos", oceans are "water"
average_annualy = 'no'

# Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
# titles = 'off'
# legend = 'off'
# yaxis_title = 'off'

# Set the zones to be plotted (once above and once below):
zone_a = 1
zone_b = 2
zone_c = 3
zone_d = 4
zone_e = 5
zone_f = 6
zone_g = 7
zone_h = 8
zone_i = 9
zone_j = 10

# Show all plots in a gridded view
# Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
# https://github.com/bokeh/bokeh/issues/3841)
from bokeh.io import gridplot, output_file, show

output_file(climochem_files_path + climochem_foldername + substance_list + "_" + compartment_list + "_svg.html",
            mode="inline")

#todo(make a loop)
p1_legend = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                          excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                          higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_a), plot_armitage,
                          plot_medianvals, 'on', 'on', 'on')
p1 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_a), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p2 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_b), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p3 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_c), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p4 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_d), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p5 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_e), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p6 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_f), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p7 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_g), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p8 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_h), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p9 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_i), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p10 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                    excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                    higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_j), plot_armitage,
                    plot_medianvals, 'on', 'off', 'on')

s = vplot(p1_legend, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10)
show(s)

print substance_list + ' plots made.'

# ### All Zones for SI Screenshot

# In[29]:

from bokeh.io import output_file, show, gridplot

substance_list = 'PFOS'  # substance data to plot (PFOS (water), POSF (no env data), xFOSAs (atmos), xFOSEs (atmos),
# or xFOSAEs (atmos))
compartment_list = 'water'  # soil compartment options are "b_soil" and "v_soil", snow compartment is "snow",
# atomosphere is "atmos", oceans are "water"
average_annualy = 'no'

# Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
# titles = 'off'
# legend = 'off'
# yaxis_title = 'off'

# Set the zones to be plotted (once above and once below):
zone_a = 1
zone_b = 2
zone_c = 3
zone_d = 4
zone_e = 5
zone_f = 6
zone_g = 7
zone_h = 8
zone_i = 9
zone_j = 10

# Show all plots in a gridded view
# Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
# https://github.com/bokeh/bokeh/issues/3841)
from bokeh.io import gridplot, output_file, show

output_file(
    climochem_files_path + climochem_foldername + substance_list + "_" + compartment_list + "_allZones_Screenshot.html")

# p1_legend = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
# input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
# higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_a), plot_armitage, plot_medianvals,
# 'on','on','on')
p1 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_a), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p2 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_b), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p3 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_c), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p4 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_d), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p5 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_e), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p6 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_f), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p7 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_g), plot_armitage,
                   plot_medianvals, 'on', 'off', 'on')
p8 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_h), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p9 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                   excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                   higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_i), plot_armitage,
                   plot_medianvals, 'on', 'off', 'off')
p10 = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                    excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                    higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_j), plot_armitage,
                    plot_medianvals, 'on', 'off', 'on')

s = gridplot([[p1, p2, p3], [p4, p5, p6], [p7, p8, p9], [p10]])
# s = gridplot([[p7,p8,p9],[p10]]) #used to show remaining PFOS plots
show(s)

print substance_list + ' plots made.'

# ### - Single Run:

# In[13]:

# If doing a single substance run for plotting, which substance is this?
substance = 'PFOS'  # substance data to plot (PFOS (water), POSF (no env data), xFOSAs (atmos), xFOSEs (atmos),
# or xFOSAEs (atmos))
# Which compartment?
compartment = 'water'  # soil compartment options are "b_soil" and "v_soil", snow compartment is "snow", atomosphere
# is "atmos", oceans are "water"
titles = 'on'
yaxis_title = 'on'
legend = 'on'
# Create a dictionary to collect the resulting bokeh plots (p)
# Loop through all zones and create plots for each
p = dict()

# Call loop, remember function syntax: generate_plot(lower_foldername, higher_foldername, runcode, substance,
# compartment, zone)
for x in range(1, 11):
    p[x] = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                         excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                         higher_fast_foldername, runcode, substance, compartment, str(x), plot_armitage,
                         plot_medianvals, titles
    p[x] = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                         excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                         higher_fast_foldername, runcode, substance, compartment, str(x), plot_armitage,
                         plot_medianvals, titles
    p[x] = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                         excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                         higher_fast_foldername, runcode, substance, compartment, str(x), plot_armitage,
                         plot_medianvals, titles, legend, yaxis_title)

    # Show all plots in a gridded view
    from bokeh.io import gridplot, output_file, show

    output_file(climochem_files_path + climochem_foldername + substance + "_" + compartment + ".html")
    f = gridplot([[p[1], p[2]], [p[3], p[4]], [p[5], p[6]], [p[7], p[8]],
                  [p[9], p[10]]])  # p1..p3 represent each zone's bokeh plot
    show(f)

    # ### - Auto 2 Level Plot for Zooming-in on Same Zones:

    # In[ ]:

    if sep_substance == 'noPOSF':
        substance_list = ['PFOS']
    # ,'xFOSAs','xFOSEs']
    compartment_list = ['water']
    # ,'atmos','atmos']

    i = 0
while i < len(substance_list):
    # Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
    # titles = 'off'
    # legend = 'off'
    # yaxis_title = 'off'

    # Set the zones to be plotted (once above and once below):
    zone_a = 1
    zone_b = 3
    zone_c = 4

    # Show all plots in a gridded view
    # Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
    # https://github.com/bokeh/bokeh/issues/3841)
    from bokeh.io import gridplot, output_file, show

    output_file(
        climochem_files_path + climochem_foldername + substance_list[i] + "_" + compartment_list[i] + "_134.html")

    f = gridplot([[generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                 input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                 higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                 compartment_list[i], str(zone_a), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_b), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_c), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                   ], [
                      generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                    input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                    higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                    compartment_list[i], str(zone_a), plot_armitage, plot_medianvals, 'off', 'off',
                                    'on')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_b), plot_armitage, plot_medianvals, 'off', 'off',
                                      'off')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_c), plot_armitage, plot_medianvals, 'off', 'off',
                                      'off')
                  ]])  # p1..p3 represent each zone's bokeh plot

    show(f)

    print substance_list[i] + ' plots made.'
    i = i + 1

# ### - Auto PFOS Plots Zones 1-6:

# In[10]:

if sep_substance == 'noPOSF':
    substance_list = ['PFOS']
    compartment_list = ['water']

i = 0
while i < len(substance_list):
    # Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
    # titles = 'off'
    # legend = 'off'
    # yaxis_title = 'off'

    # Set the zones to be plotted (once above and once below):
    zone_a = 1
    zone_b = 2
    zone_c = 3
    zone_d = 4
    zone_e = 5
    zone_f = 6

    # Show all plots in a gridded view
    # Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
    # https://github.com/bokeh/bokeh/issues/3841)
    from bokeh.io import gridplot, output_file, show

    output_file(
        climochem_files_path + climochem_foldername + substance_list[i] + "_" + compartment_list[i] + "_1-6.html",
        mode="inline")

    f = gridplot([[generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                 input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                 higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                 compartment_list[i], str(zone_a), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_b), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_c), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                   ], [
                      generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                    input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                    higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                    compartment_list[i], str(zone_d), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_e), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                      , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                      input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                      higher_slow_foldername, higher_fast_foldername, runcode, substance_list[i],
                                      compartment_list[i], str(zone_f), plot_armitage, plot_medianvals, 'on', 'off',
                                      'off')
                  ]])  # p1..p3 represent each zone's bokeh plot

    show(f)

    print substance_list[i] + ' plots made.'
    i = i + 1

# ### - Auto xFOSAs and xFOSEs Plots Zones 1,3,5:

# In[19]:

if sep_substance == 'noPOSF':
    substance_list = ['xFOSAs', 'xFOSEs']
    compartment_list = ['atmos', 'atmos']

# Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
# titles = 'off'
# legend = 'off'
# yaxis_title = 'off'

# Set the zones to be plotted (once above and once below):
zone_a = 1
zone_b = 3
zone_c = 5

# Show all plots in a gridded view
# Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
# https://github.com/bokeh/bokeh/issues/3841)
from bokeh.io import gridplot, output_file, show

output_file(climochem_files_path + climochem_foldername + "_avg=" + average_annualy + "_xFOSAEs_135_svg.html",
            mode="inline")

f = gridplot([[generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[0], compartment_list[0], str(zone_a),
                             plot_armitage, plot_medianvals, 'on', 'off', 'on')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[0], compartment_list[0], str(zone_b),
                             plot_armitage, plot_medianvals, 'on', 'off', 'off')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[0], compartment_list[0], str(zone_c),
                             plot_armitage, plot_medianvals, 'on', 'off', 'off')
               ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[1],
                                compartment_list[0], str(zone_a), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[1],
                                  compartment_list[0], str(zone_b), plot_armitage, plot_medianvals, 'on', 'off', 'off')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[1],
                                  compartment_list[0], str(zone_c), plot_armitage, plot_medianvals, 'on', 'off', 'off')
              ]])  # p1..p3 represent each zone's bokeh plot

show(f)

print 'All plots made.'

# ### - All zones (1-10) Formatted:

# In[37]:


substance_list = 'xFOSAs'  # PFOS, xFOSAs,xFOSEs
compartment_list = 'atmos'
average_annualy = 'no'

# Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
# titles = 'off'
# legend = 'off'
# yaxis_title = 'off'

# Set the zones to be plotted (once above and once below):
zone_a = 1
zone_b = 2
zone_c = 3
zone_d = 4
zone_e = 5
zone_f = 6
zone_g = 7
zone_h = 8
zone_i = 9
zone_j = 10

# Show all plots in a gridded view
# Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
# https://github.com/bokeh/bokeh/issues/3841)
from bokeh.io import gridplot, output_file, show

output_file(climochem_files_path + climochem_foldername + substance_list + "_" + compartment_list + "_1-10_svg.html")

f = gridplot([[generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_a),
                             plot_armitage, plot_medianvals, 'on', 'off', 'on')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_b),
                             plot_armitage, plot_medianvals, 'on', 'off', 'off')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list, compartment_list, str(zone_c),
                             plot_armitage, plot_medianvals, 'on', 'off', 'off')
               ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                compartment_list, str(zone_d), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                  compartment_list, str(zone_e), plot_armitage, plot_medianvals, 'on', 'off', 'off')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                  compartment_list, str(zone_f), plot_armitage, plot_medianvals, 'on', 'off', 'off')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                compartment_list, str(zone_g), plot_armitage, plot_medianvals, 'on', 'off', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                  compartment_list, str(zone_h), plot_armitage, plot_medianvals, 'on', 'off', 'off')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                  compartment_list, str(zone_i), plot_armitage, plot_medianvals, 'on', 'off', 'off')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list,
                                compartment_list, str(zone_j), plot_armitage, plot_medianvals, 'on', 'off', 'on')
              ]])  # p1..p3 represent each zone's bokeh plot

show(f)

print substance_list + ' plots made.'

# ### - Auto substance concentrations by media (as a check):

# In[ ]:

substance_list = ['xFOSAs', 'xFOSEs', 'PFOS', 'xFOSAs', 'xFOSEs', 'PFOS', 'xFOSAs', 'xFOSEs', 'PFOS', 'xFOSAs',
                  'xFOSEs', 'PFOS', 'xFOSAs', 'xFOSEs', 'PFOS', 'xFOSAs', 'xFOSEs', 'PFOS', 'xFOSAs', 'xFOSEs', 'PFOS']
compartment_list = ['atmos', 'atmos', 'atmos', 'b_soil', 'b_soil', 'b_soil', 'v_soil', 'v_soil', 'v_soil', 'water',
                    'water', 'water', 'snow', 'snow', 'snow', 'ice', 'ice', 'ice', 'veget', 'veget', 'veget']

# Currently legends set to be off, y axis title only in far left plots, and plot titles only along top plots
# titles = 'off'
# legend = 'off'
# yaxis_title = 'off'

# Set the zones to be plotted (once above and once below):
zone_a = 3

# Show all plots in a gridded view
# Have to call function each time to display a plot twice on the same grid (Bokeh limiation:
# https://github.com/bokeh/bokeh/issues/3841)
from bokeh.io import gridplot, output_file, show

output_file(climochem_files_path + climochem_foldername + "_avg=" + average_annualy + "_atmos&soil.html")

f = gridplot([[generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[0], compartment_list[0], str(zone_a),
                             plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[1], compartment_list[1], str(zone_a),
                             plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  ,
               generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[2], compartment_list[2], str(zone_a),
                             plot_armitage, plot_medianvals, 'on', 'on', 'on')
               ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[3],
                                compartment_list[3], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[4],
                                  compartment_list[4], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[5],
                                  compartment_list[5], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[6],
                                compartment_list[6], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[7],
                                  compartment_list[7], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[8],
                                  compartment_list[8], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[9],
                                compartment_list[9], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[10],
                                  compartment_list[10], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[11],
                                  compartment_list[11], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[12],
                                compartment_list[12], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[13],
                                  compartment_list[13], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[14],
                                  compartment_list[14], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[15],
                                compartment_list[15], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[16],
                                  compartment_list[16], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[17],
                                  compartment_list[17], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ], [
                  generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                higher_slow_foldername, higher_fast_foldername, runcode, substance_list[18],
                                compartment_list[18], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[19],
                                  compartment_list[19], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
                  , generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername,
                                  input_excel_path, excel_filename, lower_slow_foldername, lower_fast_foldername,
                                  higher_slow_foldername, higher_fast_foldername, runcode, substance_list[20],
                                  compartment_list[20], str(zone_a), plot_armitage, plot_medianvals, 'on', 'on', 'on')
              ]])  # p1..p3 represent each zone's bokeh plot

show(f)

print 'All plots made.'

# ### - Auto Plot for Separated Model Run:

# In[ ]:

# Define substance and compartments to loop through
# snow compartment is "snow"
if sep_substance == 'POSF':
    substance_list = ['PFOS', 'PFOS', 'POSF', 'POSF']
    compartment_list = ['water', 'atmos', 'water', 'atmos']
if sep_substance == 'PFOS':
    substance_list = ['PFOS', 'PFOS']
    compartment_list = ['water', 'atmos']
if sep_substance == 'xFOSA/Es':
    substance_list = ['PFOS', 'PFOS', 'xFOSAs', 'xFOSEs']
    compartment_list = ['water', 'atmos', 'atmos', 'atmos']
if sep_substance == 'noPOSF':
    substance_list = ['PFOS', 'xFOSAs', 'xFOSEs']
    compartment_list = ['water', 'atmos', 'atmos']

titles = 'on'
yaxis_title = 'on'
legend = 'on'

i = 0
while i < len(substance_list):

    # Create a dictionary to collect the resulting bokeh plots (p)
    # Loop through all zones and create plots for each
    p = dict()

    # Call loop, remember function syntax: generate_plot(lower_foldername, higher_foldername, runcode, substance,
    # compartment, zone)
    for x in range(1, 11):
        p[x] = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[i], compartment_list[i], str(x),
                             plot_armitage, plot_medianvals, titles, legend, yaxis_title)

    # Show all plots in a gridded view
    from bokeh.io import gridplot, output_file, show

    output_file(climochem_files_path + climochem_foldername + substance_list[i] + "_" + compartment_list[i] + ".html")
    f = gridplot([[p[1], p[2]], [p[3], p[4]], [p[5], p[6]], [p[7], p[8]],
                  [p[9], p[10]]])  # p1..p3 represent each zone's bokeh plot
    show(f)
    print substance_list[i] + ' plots made.'
    i = i + 1

# ### - Auto Plot for Combined Model Run:

# In[ ]:

# Define substance and compartments to loop through
# substance_list = ['PFOS','PFOS']
substance_list = ['xFOSAs', 'xFOSEs']  # Removed plotting POSF in atmosphere and water, as well as PFOS in atmosphere
# compartment_list = ['b_soil','v_soil']
compartment_list = ['atmos', 'atmos']  # snow compartment is "snow"
titles = 'on'
yaxis_title = 'on'
legend = 'on'
# 'PFOS','xFOSAs','xFOSEs',
# 'water','atmos','atmos',


i = 0
while i < len(substance_list):

    # Create a dictionary to collect the resulting bokeh plots (p)
    # Loop through all zones and create plots for each
    p = dict()

    # Call loop, remember function syntax: generate_plot(lower_foldername, higher_foldername, runcode, substance,
    # compartment, zone)
    for x in range(1, 11):
        p[x] = generate_plot(climochem_files_path, climochem_foldername, climochem_second_foldername, input_excel_path,
                             excel_filename, lower_slow_foldername, lower_fast_foldername, higher_slow_foldername,
                             higher_fast_foldername, runcode, substance_list[i], compartment_list[i], str(x),
                             plot_armitage, plot_medianvals, titles, legend, yaxis_title)

    # Show all plots in a gridded view
    from bokeh.io import gridplot, output_file, show

    output_file(climochem_files_path + climochem_foldername + substance_list[i] + "_" + compartment_list[i] + ".html")
    f = gridplot([[p[1], p[2]], [p[3], p[4]], [p[5], p[6]], [p[7], p[8]],
                  [p[9], p[10]]])  # p1..p3 represent each zone's bokeh plot
    show(f)
    print substance_list[i] + ' plots made.'
    i = i + 1


# In[ ]:




# In[ ]:
