readme1st.txt CliMoChem v2.0												(23.03.2007)
==============================

==============================
CliMoChem as a function:
Launch CliMoChem in the Matlab command line as follows :      climochem_2('runPath','runCode','MIF');
- runPath is the (full) path of where the run should be executed (excluding inputs\). If your input files are located in 
	c:\thats_me\my_data\testrun\inputs\, then runPath should be c:\thats_me\my_data\testrun\. An ouput folder will be
	created in the runPath directory.
- runCode is a code that you can give to your run to identify files from this run later on. This code is added in () to 
	each output file before the extension (.txt or .xls).
- MIF is the path of the Master Input Files: if a given input file cannot be found in the input folder, CliMoChem will try 
	to find it in the MIF. This is mainly used for batch runs to save disk space.
If runCode is omitted, CliMoChem randomly generates such a path. If runPath is omitted, CliMoChem tries to run in the same
	directory as the program file, and breaks if no inputs directory can be found.
CCcontrol.m is used to specify the most important settings of CliMoChem. CCcontrol must be found in the inputs folder - 
	explanations to the CCcontrol.m file are given as comments in the file itself.
At the beginning of each run, CliMoChem asks you for a brief description of this run. This description will be plotted into
	the about.txt file that is stored in the runPath, together with some information about calculation time, path, and
	other information that can be added in the future. (This feature can be switched of in the ccControl.m file.)
==============================

==============================
For further questions, contact Linus Becker (linus.becker@chem.ethz.ch) or Urs Schenker (urs.schenker@chem.ethz.ch)
==============================

