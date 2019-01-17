var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#Welcome-to-Mimi-1",
    "page": "Home",
    "title": "Welcome to Mimi",
    "category": "section",
    "text": ""
},

{
    "location": "#Overview-1",
    "page": "Home",
    "title": "Overview",
    "category": "section",
    "text": "Mimi is a package that provides a component model for integrated assessment models."
},

{
    "location": "#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "Mimi is an installable package. To install Mimi, use the following:Pkg.add(\"Mimi\")For more complete setup instructions, follow the Installation Guide."
},

{
    "location": "#Models-using-Mimi-1",
    "page": "Home",
    "title": "Models using Mimi",
    "category": "section",
    "text": "FUND.jl (currently in beta)\nMimi-DICE-2010.jl (currently in closed beta)\nMimi-DICE-2013.jl (currently in closed beta)\nMimi-RICE.jl\nMimi-SNEASY.jl (currently in closed beta)\nMimi-FAIR.jl (currently in closed beta)\nMimi-PAGE.jl (currently in closed beta)\nMimi-MAGICC.jl (CH4 parts currently in closed beta)\nMimi-HECTOR.jl (CH4 parts currently in closed beta)\nMimi-CIAM.jl (currently in closed beta)\nMimi-BRICK.jl (currently in closed beta)"
},

{
    "location": "installation/#",
    "page": "Installation Guide",
    "title": "Installation Guide",
    "category": "page",
    "text": ""
},

{
    "location": "installation/#Installation-Guide-1",
    "page": "Installation Guide",
    "title": "Installation Guide",
    "category": "section",
    "text": "This guide will briefly explain how to install julia and Mimi."
},

{
    "location": "installation/#Installing-julia-1",
    "page": "Installation Guide",
    "title": "Installing julia",
    "category": "section",
    "text": "Mimi requires the programming language julia to run. You can download the current release from the julia download page. You should download and install the command line version from that page."
},

{
    "location": "installation/#Installing-Mimi-1",
    "page": "Installation Guide",
    "title": "Installing Mimi",
    "category": "section",
    "text": "Once julia is installed, start julia and you should see a julia command prompt. To install the Mimi package, issue the following command:julia> Pkg.add(\"Mimi\")You only have to run this command once on your machine.As Mimi gets improved we will release new versions of the package. To make sure you always have the latest version of Mimi installed, you can run the following command at the julia prompt:julia> Pkg.update()This will update all installed packages to their latest version (not just the Mimi package)."
},

{
    "location": "installation/#Using-Mimi-1",
    "page": "Installation Guide",
    "title": "Using Mimi",
    "category": "section",
    "text": "When you start a new julia command prompt, Mimi is not yet loaded into that julia session. To load Mimi, issue the following command:julia> using MimiYou will have to run this command every time you want to use Mimi in julia. You would typically also add using Mimi to the top of any julia code file that for example defines Mimi components."
},

{
    "location": "installation/#Editor-support-1",
    "page": "Installation Guide",
    "title": "Editor support",
    "category": "section",
    "text": "There are various editors around that have julia support:IJulia adds julia support to the jupyter (formerly IPython) notebook system.\nJuno adds julia specific features to the Atom editor. It currently is the closest to a fully featured julia IDE.\nSublime, VS Code, Emacs and many other editors all have julia extensions that add various levels of support for the julia language."
},

{
    "location": "installation/#Getting-started-1",
    "page": "Installation Guide",
    "title": "Getting started",
    "category": "section",
    "text": "The best way to get started with Mimi is to work through the Tutorials Intro. The examples/tutorial folder in the Mimi github repository has julia code files that completely implement the example described in the tutorial.The Mimi github repository also has links to various models that are based on Mimi, and looking through their code can be instructive.Finally, when in doubt, ask your question in the Mimi gitter chatroom or send an email to David Anthoff (<anthoff@berkeley.edu>) and ask for help. Don\'t be shy about either option, we would much prefer to be inundated with lots of questions and help people out than people give up on Mimi!"
},

{
    "location": "userguide/#",
    "page": "User Guide",
    "title": "User Guide",
    "category": "page",
    "text": ""
},

{
    "location": "userguide/#User-Guide-1",
    "page": "User Guide",
    "title": "User Guide",
    "category": "section",
    "text": ""
},

{
    "location": "userguide/#Overview-1",
    "page": "User Guide",
    "title": "Overview",
    "category": "section",
    "text": "See the Tutorials for in-depth examples of Mimi\'s functionality.This guide is organized into six main sections for understanding how to use Mimi.Defining components\nConstructing a model\nRunning the model\nAccessing results\nPlotting and the Explorer UI\nAdvanced topics"
},

{
    "location": "userguide/#Defining-Components-1",
    "page": "User Guide",
    "title": "Defining Components",
    "category": "section",
    "text": "Any Mimi model is made up of at least one component, so before you construct a model, you need to create your components.A component can have any number of parameters and variables. Parameters are data values that will be provided to the component as input, and variables are values that the component will calculate in the run_timestep function when the model is run. The index of a parameter or variable determines the number of dimensions that parameter or variable has. They can be scalar values and have no index, such as parameter \'c\' in the example below. They can be one-dimensional, such as the variable \'A\' and the parameters \'d\' and \'f\' below. They can be two dimensional such as variable \'B\' and parameter \'e\' below. Note that any index other than \'time\' must be declared at the top of the component, as shown by regions = Index() below.The user must define a run_timestep function for each component. We define a component in the following way:using Mimi\n\n@defcomp MyComponentName begin\n  regions = Index()\n\n  A = Variable(index = [time])\n  B = Variable(index = [time, regions])\n\n  c = Parameter()\n  d = Parameter(index = [time])\n  e = Parameter(index = [time, regions])\n  f = Parameter(index = [regions])\n\n  function run_timestep(p, v, d, t)\n    v.A[t] = p.c + p.d[t]\n    for r in d.regions\n      v.B[t, r] = p.f[r] * p.e[t, r]\n    end\n  end\n\nend\nThe run_timestep function is responsible for calculating values for each variable in that component.  Note that the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined. You can access each parameter, variable, or dimension using dot notation as shown above.  The fourth argument is an AbstractTimestep, i.e., either a FixedTimestep or a VariableTimestep, which represents which timestep the model is at.The API for using the fourth argument, represented as t in this explanation, is described in this document under Advanced Topics:  Timesteps and available functions. To access the data in a parameter or to assign a value to a variable, you must use the appropriate index or indices (in this example, either the Timestep or region or both)."
},

{
    "location": "userguide/#Constructing-a-Model-1",
    "page": "User Guide",
    "title": "Constructing a Model",
    "category": "section",
    "text": "The first step in constructing a model is to set the values for each index of the model. Below is an example for setting the \'time\' and \'regions\' indexes. The time index expects either a numerical range or an array of numbers.  If a single value is provided, say \'100\', then that index will be set from 1 to 100. Other indexes can have values of any type.mymodel = Model()\nset_dimension!(mymodel, :time, 1850:2200)\nset_dimension!(mymodel, :regions, [\"USA\", \"EU\", \"LATAM\"])\nA Note on Time Indexes: It is important to note that the values used for the time index are the start times of the timesteps.  If the range or array of time values has a uniform timestep length, the model will run through the last year of the range with a last timestep period length consistent with the other timesteps.  If the time values are provided as an array with non-uniform timestep lengths, the model will run through the last year in the array with a last timestep period length assumed to be one. The next step is to add components to the model. This is done by the following syntax:add_comp!(mymodel, ComponentA, :GDP)\nadd_comp!(mymodel, ComponentB; first=2010)\nadd_comp!(mymodel, ComponentC; first=2010, last=2100)\nThe first argument to add_comp! is the model, the second is the name of the ComponentId defined by @defcomp. If an optional third symbol is provided (as in the first line above), this will be used as the name of the component in this model. This allows you to add multiple versions of the same component to a model, with different names. You can also have components that do not run for the full length of the model. You can specify custom first and last times with the optional keyword arguments as shown above. If no first or last time is provided, the component will assume the first or last time of the model\'s time index values that were specified in set_dimension!.The next step is to set the values for all the parameters in the components. Parameters can either have their values assigned from external data, or they can internally connect to the values from variables in other components of the model.To make an external connection, the syntax is as follows:set_param!(mymodel, :ComponentName, :parametername, 0.8) # a scalar parameter\nset_param!(mymodel, :ComponentName, :parametername2, rand(351, 3)) # a two-dimensional parameter\nTo make an internal connection, the syntax is as follows.  connect_param!(mymodel, :TargetComponent=>:parametername, :SourceComponent=>:variablename)\nconnect_param!(mymodel, :TargetComponent=>:parametername, :SourceComponent=>:variablename)If you wish to delete a component that has already been added, do the following:delete!(mymodel, :ComponentName)This will delete the component from the model and remove any existing connections it had. Thus if a different component was previously connected to this component, you will need to connect its parameter(s) to something else."
},

{
    "location": "userguide/#Running-a-Model-1",
    "page": "User Guide",
    "title": "Running a Model",
    "category": "section",
    "text": "After all components have been added to your model and all parameters have been connected to either external values or internally to another component, then the model is ready to be run. Note: at each timestep, the model will run the components in the order you added them. So if one component is going to rely on the value of another component, then the user must add them to the model in the appropriate order.run(mymodel)\n"
},

{
    "location": "userguide/#Accessing-Results-1",
    "page": "User Guide",
    "title": "Accessing Results",
    "category": "section",
    "text": "After a model has been run, you can access the results (the calculated variable values in each component) in a few different ways.You can use the getindex syntax as follows:mymodel[:ComponentName, :VariableName] # returns the whole array of values\nmymodel[:ComponentName, :VariableName][100] # returns just the 100th value\nIndexing into a model with the name of the component and variable will return an array with values from each timestep. You can index into this array to get one value (as in the second line, which returns just the 100th value). Note that if the requested variable is two-dimensional, then a 2-D array will be returned.You can also get data in the form of a dataframe, which will display the corresponding index labels rather than just a raw array. The syntax for this is:getdataframe(mymodel, :ComponentName=>:Variable) # request one variable from one component\ngetdataframe(mymodel, :ComponentName=>(:Variable1, :Variable2)) # request multiple variables from the same component\ngetdataframe(mymodel, :Component1=>:Var1, :Component2=>:Var2) # request variables from different components\n"
},

{
    "location": "userguide/#Plotting-and-the-Explorer-UI-1",
    "page": "User Guide",
    "title": "Plotting and the Explorer UI",
    "category": "section",
    "text": "Mimi provides support for plotting using VegaLite and VegaLite.jl within the Mimi Explorer UI, and the LightGraphs and MetaGraphs for the plot_comp_graph function described below.In order to view a DAG representing the component ordering and relationships, use the plot_comp_graph function to view a plot and optionally save it to a file.run(m)\nplot_comp_graph(m; filename = \"MyFilePath.png\")(Image: Plot Component Graph Example)Other plotting support is provided by the Explorer UI, rooted in VegaLite.  The explore function allows the user to view and explore the variables and parameters of a model run.  The explorer can be used in two primary ways.In order to invoke the explorer UI and explore all of the variables and parameters in a model, simply call the function explore with the model run as the required argument, and a window title as an optional keyword argument, as shown below.  This will produce a new browser window containing a selectable list of parameters and variables, organized by component, each of which produces a graphic.  The exception here being that if the parameter or variable is a single scalar value, the value will appear alongside the name in the left-hand list. run1 = run(my_model)\n explore(run1, title = \"run1 results\")(Image: Explorer Model Example)Alternatively, in order to view just one parameter or variable, call the function explore as below to return a plot object and automatically display the plot in a viewer, assuming explore is the last command executed.  This call will return the type VegaLite.VLSpec, which you may interact with using the API described in the VegaLite.jl documentation.  For example, VegaLite.jl plots can be saved as PNG, SVG, PDF and EPS files. You can save a plot by calling the save function.run1 = run(my_model)\np = explore(run1, component1, parameter1)\nsave(\"figure.svg\", p)(Image: Explorer Single Plot Example)"
},

{
    "location": "userguide/#Advanced-Topics-1",
    "page": "User Guide",
    "title": "Advanced Topics",
    "category": "section",
    "text": ""
},

{
    "location": "userguide/#Timesteps-and-available-functions-1",
    "page": "User Guide",
    "title": "Timesteps and available functions",
    "category": "section",
    "text": "An AbstractTimestep i.e. a FixedTimestep or a VariableTimestep is a type defined within Mimi in \"src/time.jl\". It is used to represent and keep track of time indices when running a model.In the run_timestep functions which the user defines, it may be useful to use any of the following functions, where t is an AbstractTimestep object:is_first(t) # returns true or false, true if t is the first timestep to be run\nis_last(t) # returns true or false, true if t is the last timestep to be run\ngettime(t) # returns the year represented by timestep t\nis_time(t, s) # Return true or false, true if the current time (year) for t is y\nis_timestep(t, y) # rReturn true or false, true if t timestep is step s.The API details for AbstractTimestep object t are as follows:you may index into a variable or parameter with [t] or [t +/- x] as usual\nto access the time value of t (currently a year) as a Number, use gettime(t)\nuseful functions for commonly used conditionals are is_first(t),is_last(t), is_time(t, s), and is_timestep(t, y) as listed above\nto access the index value of t as a Number representing the position in the time array, use t.t.  Users are encouraged to avoid this access, and instead use the options listed above or a separate counter variable. each time the function gets called. "
},

{
    "location": "userguide/#Parameter-connections-between-different-length-components-1",
    "page": "User Guide",
    "title": "Parameter connections between different length components",
    "category": "section",
    "text": "As mentioned earlier, it is possible for some components to start later or end sooner than the full length of the model. This presents potential complications for connecting their parameters. If you are setting the parameters to external values, then the provided values just need to be the right size for that component\'s parameter. If you are making an internal connection, this can happen in one of two ways:A shorter component is connected to a longer component. In this case, nothing additional needs to happen. The shorter component will pick up the correct values it needs from the longer component.\nA longer component is connected to a shorter component. In this case, the shorter component will not have enough values to supply to the longer component. In order to make this connection, the user must also provide an array of backup data for the parameter to default to when the shorter component does not have values to give. Do this in the following way:backup = rand(100) # data array of the proper size\nconnect_param!(mymodel, :LongComponent=>:parametername, :ShortComponent=>:variablename, backup)Note: for now, to avoid discrepancy with timing and alignment, the backup data must be the length of the whole component\'s first to last time, even though it will only be used for values not found in the shorter component."
},

{
    "location": "userguide/#More-on-parameter-indices-1",
    "page": "User Guide",
    "title": "More on parameter indices",
    "category": "section",
    "text": "As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model\'s indexes. A parameter can also have an index specified in the following ways:@defcomp MyComponent begin\n  p1 = Parameter(index=[4]) # an array of length 4\n  p2::Array{Float64, 2} = Parameter() # a two dimensional array of unspecified length\nendIn both of these cases, the parameter\'s values are stored of as an array (p1 is one dimensional, and p2 is two dimensional). But with respect to the model, they are considered \"scalar\" parameters, simply because they do not use any of the model\'s indices (namely \'time\', or \'regions\')."
},

{
    "location": "userguide/#Updating-an-external-parameter-1",
    "page": "User Guide",
    "title": "Updating an external parameter",
    "category": "section",
    "text": "When set_param! is called, it creates an external parameter by the name provided, and stores the provided scalar or array value. It is possible to later change the value associated with that parameter name using the functions described below. If the external parameter has a :time dimension, use the optional argument update_timesteps=true to indicate that the time keys (i.e., year labels) associated with the parameter should be updated in addition to updating the parameter values.update_param!(mymodel, :parametername, newvalues) # update values only \nupdate_param!(mymodel, :parametername, newvalues, update_timesteps=true) # also update time keysNote: newvalues must be the same size and type (or be able to convert to the type) of the old values stored in that parameter."
},

{
    "location": "userguide/#Setting-parameters-with-a-dictionary-1",
    "page": "User Guide",
    "title": "Setting parameters with a dictionary",
    "category": "section",
    "text": "In larger models it can be beneficial to set some of the external parameters using a dictionary of values. To do this, use the following function:set_leftover_params!(mymodel, parameters)Where parameters is a dictionary of type Dict{String, Any} where the keys are strings that match the names of the unset parameters in the model, and the values are the values to use for those parameters."
},

{
    "location": "userguide/#Using-NamedArrays-for-setting-parameters-1",
    "page": "User Guide",
    "title": "Using NamedArrays for setting parameters",
    "category": "section",
    "text": "When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model\'s index values for those dimensions. Examples of this can be found in \"test/testparameterlabels.jl\"."
},

{
    "location": "userguide/#The-internal-\'build\'-function-and-model-instances-1",
    "page": "User Guide",
    "title": "The internal \'build\' function and model instances",
    "category": "section",
    "text": "When you call the run function on your model, first the internal build function is called, which produces a ModelInstance, and then the ModelInstance is run. A model instance is an instantiated version of the model you have designed where all of the component constructors have been called and all of the data arrays have been allocated. If you wish to create and run multiple versions of your model, you can use the intermediate build function and store the separate ModelInstances. This may be useful if you want to change some parameter values, while keeping the model\'s structure mostly the same. For example:instance1 = Mimi.build(mymodel)\nrun(instance1)\n\nupdate_param!(mymodel, paramname, newvalue)\ninstance2 = Mimi.build(mymodel)\nrun(instance2)\n\nresult1 = instance1[:Comp, :Var]\nresult2 = instance2[:Comp, :Var]Note that you can retrieve values from a ModelInstance in the same way previously shown for indexing into a model."
},

{
    "location": "userguide/#The-init-function-1",
    "page": "User Guide",
    "title": "The init function",
    "category": "section",
    "text": "The init function can optionally be called within @defcomp and before run_timestep.  Similarly to run_timestep, this function is called with parameters init(p, v, d), where the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined.   If defined for a specific component, this function will run before the timestep loop, and should only be used for parameters or variables without a time index e.g. to compute the values of scalar variables that only depend on scalar parameters. Note that when using init, it may be necessary to add special handling in the run_timestep function for the first timestep, in particular for difference equations.  A skeleton @defcomp script using both run_timestep and init would appear as follows:@defcomp component1 begin\n\n    # First define the state this component will hold\n    savingsrate = Parameter()\n\n    # Second, define the (optional) init function for the component\n    function init(p, v, d)\n    end\n\n    # Third, define the run_timestep function for the component\n    function run_timestep(p, v, d, t)\n    end\n\nend"
},

{
    "location": "tutorials/tutorial_main/#",
    "page": "Tutorials Intro",
    "title": "Tutorials Intro",
    "category": "page",
    "text": ""
},

{
    "location": "tutorials/tutorial_main/#Introduction-1",
    "page": "Tutorials Intro",
    "title": "Introduction",
    "category": "section",
    "text": "The following tutorials target Mimi users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the Welcome to Mimi documentation, including the User Guide, and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the Julia language, though expertise is not required.If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our Mimi.jl/dev gitter chat room.  We welcome your feedback."
},

{
    "location": "tutorials/tutorial_main/#Terminology-1",
    "page": "Tutorials Intro",
    "title": "Terminology",
    "category": "section",
    "text": "The following terminology is used throughout the documentation.Application Programming Interface (API):  The public classes, methods, and functions provided by Mimi to facilitate construction of custom scripts and work with existing models. Function documentation provided in \"docstrings\" in the Reference define the Mimi API in more detail."
},

{
    "location": "tutorials/tutorial_main/#Available-Tutorials-1",
    "page": "Tutorials Intro",
    "title": "Available Tutorials",
    "category": "section",
    "text": "Run an Existing Model\nTutorial 1: Run an Existing Model steps through the tasks to download, run, and view the results of a registered model such as FUND.  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.\nModify an Existing Model\nTutorial 2: Modify an Existing Model builds on Tutorial 1, showing how to modify an existing model such as DICE.\nCreate a Model\nTutorial 3: Constructing A One-Region Model takes a step beyond using registered models, explaining how to create a model from scratch.\nMonte Carlo Simulation\nTutorial 4: Monte Carlo Simulation (MCS) Support explores Mimi\'s Monte Carlo Simulation support, using both the simple 2-Region tutorial model and FUND examples."
},

{
    "location": "tutorials/tutorial_main/#Requirements-and-Initial-Setup-1",
    "page": "Tutorials Intro",
    "title": "Requirements and Initial Setup",
    "category": "section",
    "text": "These tutorials require Julia v1.0.0 and Mimi v0.6.0, or later. You will also need to use Github and thus download Git.To use the following tutorials, follow the steps below.Download Git here.\nDownload the latest version of Julia here, making sure that your downloaded version is v1.0.0 or later.\nOpen a Julia REPL, and enter ] to enter the Pkg REPL mode, and then type add Mimi to install the latest tagged version of Mimi, which must be version 0.6.0 or later.pkg> add MimiWe also recommend that you frequently update your packages and requirements using the update command, which can be abbreviated up:pkg> upYou are now ready to begin the tutorials!"
},

{
    "location": "tutorials/tutorial_main/#",
    "page": "1 Run an Existing Model",
    "title": "1 Run an Existing Model",
    "category": "page",
    "text": ""
},

{
    "location": "tutorials/tutorial_main/#Introduction-1",
    "page": "1 Run an Existing Model",
    "title": "Introduction",
    "category": "section",
    "text": "The following tutorials target Mimi users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the Welcome to Mimi documentation, including the User Guide, and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the Julia language, though expertise is not required.If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our Mimi.jl/dev gitter chat room.  We welcome your feedback."
},

{
    "location": "tutorials/tutorial_main/#Terminology-1",
    "page": "1 Run an Existing Model",
    "title": "Terminology",
    "category": "section",
    "text": "The following terminology is used throughout the documentation.Application Programming Interface (API):  The public classes, methods, and functions provided by Mimi to facilitate construction of custom scripts and work with existing models. Function documentation provided in \"docstrings\" in the Reference define the Mimi API in more detail."
},

{
    "location": "tutorials/tutorial_main/#Available-Tutorials-1",
    "page": "1 Run an Existing Model",
    "title": "Available Tutorials",
    "category": "section",
    "text": "Run an Existing Model\nTutorial 1: Run an Existing Model steps through the tasks to download, run, and view the results of a registered model such as FUND.  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.\nModify an Existing Model\nTutorial 2: Modify an Existing Model builds on Tutorial 1, showing how to modify an existing model such as DICE.\nCreate a Model\nTutorial 3: Constructing A One-Region Model takes a step beyond using registered models, explaining how to create a model from scratch.\nMonte Carlo Simulation\nTutorial 4: Monte Carlo Simulation (MCS) Support explores Mimi\'s Monte Carlo Simulation support, using both the simple 2-Region tutorial model and FUND examples."
},

{
    "location": "tutorials/tutorial_main/#Requirements-and-Initial-Setup-1",
    "page": "1 Run an Existing Model",
    "title": "Requirements and Initial Setup",
    "category": "section",
    "text": "These tutorials require Julia v1.0.0 and Mimi v0.6.0, or later. You will also need to use Github and thus download Git.To use the following tutorials, follow the steps below.Download Git here.\nDownload the latest version of Julia here, making sure that your downloaded version is v1.0.0 or later.\nOpen a Julia REPL, and enter ] to enter the Pkg REPL mode, and then type add Mimi to install the latest tagged version of Mimi, which must be version 0.6.0 or later.pkg> add MimiWe also recommend that you frequently update your packages and requirements using the update command, which can be abbreviated up:pkg> upYou are now ready to begin the tutorials!"
},

{
    "location": "tutorials/tutorial_main/#",
    "page": "2 Modfiy an Existing Model",
    "title": "2 Modfiy an Existing Model",
    "category": "page",
    "text": ""
},

{
    "location": "tutorials/tutorial_main/#Introduction-1",
    "page": "2 Modfiy an Existing Model",
    "title": "Introduction",
    "category": "section",
    "text": "The following tutorials target Mimi users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the Welcome to Mimi documentation, including the User Guide, and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the Julia language, though expertise is not required.If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our Mimi.jl/dev gitter chat room.  We welcome your feedback."
},

{
    "location": "tutorials/tutorial_main/#Terminology-1",
    "page": "2 Modfiy an Existing Model",
    "title": "Terminology",
    "category": "section",
    "text": "The following terminology is used throughout the documentation.Application Programming Interface (API):  The public classes, methods, and functions provided by Mimi to facilitate construction of custom scripts and work with existing models. Function documentation provided in \"docstrings\" in the Reference define the Mimi API in more detail."
},

{
    "location": "tutorials/tutorial_main/#Available-Tutorials-1",
    "page": "2 Modfiy an Existing Model",
    "title": "Available Tutorials",
    "category": "section",
    "text": "Run an Existing Model\nTutorial 1: Run an Existing Model steps through the tasks to download, run, and view the results of a registered model such as FUND.  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.\nModify an Existing Model\nTutorial 2: Modify an Existing Model builds on Tutorial 1, showing how to modify an existing model such as DICE.\nCreate a Model\nTutorial 3: Constructing A One-Region Model takes a step beyond using registered models, explaining how to create a model from scratch.\nMonte Carlo Simulation\nTutorial 4: Monte Carlo Simulation (MCS) Support explores Mimi\'s Monte Carlo Simulation support, using both the simple 2-Region tutorial model and FUND examples."
},

{
    "location": "tutorials/tutorial_main/#Requirements-and-Initial-Setup-1",
    "page": "2 Modfiy an Existing Model",
    "title": "Requirements and Initial Setup",
    "category": "section",
    "text": "These tutorials require Julia v1.0.0 and Mimi v0.6.0, or later. You will also need to use Github and thus download Git.To use the following tutorials, follow the steps below.Download Git here.\nDownload the latest version of Julia here, making sure that your downloaded version is v1.0.0 or later.\nOpen a Julia REPL, and enter ] to enter the Pkg REPL mode, and then type add Mimi to install the latest tagged version of Mimi, which must be version 0.6.0 or later.pkg> add MimiWe also recommend that you frequently update your packages and requirements using the update command, which can be abbreviated up:pkg> upYou are now ready to begin the tutorials!"
},

{
    "location": "tutorials/tutorial_main/#",
    "page": "3 Create a Model",
    "title": "3 Create a Model",
    "category": "page",
    "text": ""
},

{
    "location": "tutorials/tutorial_main/#Introduction-1",
    "page": "3 Create a Model",
    "title": "Introduction",
    "category": "section",
    "text": "The following tutorials target Mimi users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the Welcome to Mimi documentation, including the User Guide, and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the Julia language, though expertise is not required.If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our Mimi.jl/dev gitter chat room.  We welcome your feedback."
},

{
    "location": "tutorials/tutorial_main/#Terminology-1",
    "page": "3 Create a Model",
    "title": "Terminology",
    "category": "section",
    "text": "The following terminology is used throughout the documentation.Application Programming Interface (API):  The public classes, methods, and functions provided by Mimi to facilitate construction of custom scripts and work with existing models. Function documentation provided in \"docstrings\" in the Reference define the Mimi API in more detail."
},

{
    "location": "tutorials/tutorial_main/#Available-Tutorials-1",
    "page": "3 Create a Model",
    "title": "Available Tutorials",
    "category": "section",
    "text": "Run an Existing Model\nTutorial 1: Run an Existing Model steps through the tasks to download, run, and view the results of a registered model such as FUND.  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.\nModify an Existing Model\nTutorial 2: Modify an Existing Model builds on Tutorial 1, showing how to modify an existing model such as DICE.\nCreate a Model\nTutorial 3: Constructing A One-Region Model takes a step beyond using registered models, explaining how to create a model from scratch.\nMonte Carlo Simulation\nTutorial 4: Monte Carlo Simulation (MCS) Support explores Mimi\'s Monte Carlo Simulation support, using both the simple 2-Region tutorial model and FUND examples."
},

{
    "location": "tutorials/tutorial_main/#Requirements-and-Initial-Setup-1",
    "page": "3 Create a Model",
    "title": "Requirements and Initial Setup",
    "category": "section",
    "text": "These tutorials require Julia v1.0.0 and Mimi v0.6.0, or later. You will also need to use Github and thus download Git.To use the following tutorials, follow the steps below.Download Git here.\nDownload the latest version of Julia here, making sure that your downloaded version is v1.0.0 or later.\nOpen a Julia REPL, and enter ] to enter the Pkg REPL mode, and then type add Mimi to install the latest tagged version of Mimi, which must be version 0.6.0 or later.pkg> add MimiWe also recommend that you frequently update your packages and requirements using the update command, which can be abbreviated up:pkg> upYou are now ready to begin the tutorials!"
},

{
    "location": "tutorials/tutorial_main/#",
    "page": "4 MCS Functionality",
    "title": "4 MCS Functionality",
    "category": "page",
    "text": ""
},

{
    "location": "tutorials/tutorial_main/#Introduction-1",
    "page": "4 MCS Functionality",
    "title": "Introduction",
    "category": "section",
    "text": "The following tutorials target Mimi users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the Welcome to Mimi documentation, including the User Guide, and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the Julia language, though expertise is not required.If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our Mimi.jl/dev gitter chat room.  We welcome your feedback."
},

{
    "location": "tutorials/tutorial_main/#Terminology-1",
    "page": "4 MCS Functionality",
    "title": "Terminology",
    "category": "section",
    "text": "The following terminology is used throughout the documentation.Application Programming Interface (API):  The public classes, methods, and functions provided by Mimi to facilitate construction of custom scripts and work with existing models. Function documentation provided in \"docstrings\" in the Reference define the Mimi API in more detail."
},

{
    "location": "tutorials/tutorial_main/#Available-Tutorials-1",
    "page": "4 MCS Functionality",
    "title": "Available Tutorials",
    "category": "section",
    "text": "Run an Existing Model\nTutorial 1: Run an Existing Model steps through the tasks to download, run, and view the results of a registered model such as FUND.  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.\nModify an Existing Model\nTutorial 2: Modify an Existing Model builds on Tutorial 1, showing how to modify an existing model such as DICE.\nCreate a Model\nTutorial 3: Constructing A One-Region Model takes a step beyond using registered models, explaining how to create a model from scratch.\nMonte Carlo Simulation\nTutorial 4: Monte Carlo Simulation (MCS) Support explores Mimi\'s Monte Carlo Simulation support, using both the simple 2-Region tutorial model and FUND examples."
},

{
    "location": "tutorials/tutorial_main/#Requirements-and-Initial-Setup-1",
    "page": "4 MCS Functionality",
    "title": "Requirements and Initial Setup",
    "category": "section",
    "text": "These tutorials require Julia v1.0.0 and Mimi v0.6.0, or later. You will also need to use Github and thus download Git.To use the following tutorials, follow the steps below.Download Git here.\nDownload the latest version of Julia here, making sure that your downloaded version is v1.0.0 or later.\nOpen a Julia REPL, and enter ] to enter the Pkg REPL mode, and then type add Mimi to install the latest tagged version of Mimi, which must be version 0.6.0 or later.pkg> add MimiWe also recommend that you frequently update your packages and requirements using the update command, which can be abbreviated up:pkg> upYou are now ready to begin the tutorials!"
},

{
    "location": "faq/#",
    "page": "FAQ",
    "title": "FAQ",
    "category": "page",
    "text": ""
},

{
    "location": "faq/#Frequently-asked-questions-1",
    "page": "FAQ",
    "title": "Frequently asked questions",
    "category": "section",
    "text": ""
},

{
    "location": "faq/#What\'s-up-with-the-name?-1",
    "page": "FAQ",
    "title": "What\'s up with the name?",
    "category": "section",
    "text": "The name is probably an acronym for \"Modular Integrated Modeling Interface\", but we are not sure. What is certain is that it came up during a dinner that Bob, David and Sol had in 2015. David thinks that Bob invented the name, Bob doesn\'t remember and Sol thinks the waiter might have come up with it (although we can almost certainly rule that option out). It certainly is better than the previous name \"IAMF\". We now use \"Mimi\" purely as a name of the package, not as an acronym."
},

{
    "location": "faq/#How-do-I-use-a-multivariate-distribution-for-a-parameter-within-a-component?-1",
    "page": "FAQ",
    "title": "How do I use a multivariate distribution for a parameter within a component?",
    "category": "section",
    "text": "You might want to use a multivariate distribution to capture the covariance between estimated coefficient parameters.  For example, an estimated polynomial can be represented as a multivariate Normal distribution, with a variance-covariance matrix.  To use this, define the parameter in the component with a vector type, like here:@defcomp example begin\n    cubiccoeffs::Vector{Float64} = Parameter()\nendThen in the model construction, set the parameter with a multivariate distribution (here the parameters are loaded from a CSV file):cubicparams = readdlm(\"../data/cubicparams.csv\", \',\')\nset_param!(m, :example, :cubiccoeff, MvNormal(squeeze(cubicparams[1,:], 1), cubicparams[2:4,:]))Here, ../data/cubicparams.csv is a parameter definition file that looks something like this:# Example estimated polynomial parameter\n# First line: linear, quadratic, cubic\n# Lines 2-4: covariance matrix\n-3.233303,1.911123,-.1018884\n1.9678593,-.57211657,.04413228\n-.57211657,.17500949,-.01388863\n.04413228,-.01388863,.00111965"
},

{
    "location": "faq/#How-do-I-use-component-references?-1",
    "page": "FAQ",
    "title": "How do I use component references?",
    "category": "section",
    "text": "Component references allow you to write cleaner model code when connecting components.  The add_comp! function returns a reference to the component that you just added:mycomponent = add_comp!(model, MyComponent)If you want to get a reference to a component after the add_comp! call has been made, you can construct the reference as:mycomponent = ComponentReference(model, :MyComponent)You can use this component reference in place of the set_param! and connect_param! calls."
},

{
    "location": "faq/#References-in-place-of-set_param!-1",
    "page": "FAQ",
    "title": "References in place of set_param!",
    "category": "section",
    "text": "The line set_param!(model, :MyComponent, :myparameter, myvalue) can be written as mycomponent[:myparameter] = myvalue, where mycomponent is a component reference."
},

{
    "location": "faq/#References-in-place-of-connect_param!-1",
    "page": "FAQ",
    "title": "References in place of connect_param!",
    "category": "section",
    "text": "The line connect_param!(model, :MyComponent, :myparameter, :YourComponent, :yourparameter) can be written as mycomponent[:myparameter] = yourcomponent[:yourparameter], where mycomponent and yourcomponent are component references."
},

{
    "location": "reference/#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference/#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": "@defcomp\n@defmcs\nMarginalModel\nModel\nadd_comp!  \ncomponents \nconnect_param!\ncreate_marginal_model\ndisconnect_param!\nexplore\ngenerate_trials!\ngetdataframe\ngettime\nget_param_value\nget_var_value\nhasvalue\nis_first\nis_last\nis_time\nis_timestep\nload_comps\nmodeldef\nname\nnew_comp\nparameters\nplot_comp_graph\nreplace_comp! \nrun_mcs\nset_dimension! \nset_leftover_params! \nset_param! \nvariables  \nupdate_param!\nupdate_params!"
},

{
    "location": "integrationguide/#",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Integration Guide: Port to v0.5.0",
    "category": "page",
    "text": ""
},

{
    "location": "integrationguide/#Integration-Guide:-Porting-Mimi-Models-from-v0.4.0-to-v0.5.0-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Integration Guide:  Porting Mimi Models from v0.4.0 to v0.5.0",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#Overview-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Overview",
    "category": "section",
    "text": "The release of Mimi v0.5.0 is a breaking release, necessitating the adaptation of existing models\' syntax and structure in order for those models to run on this new version.  This guide provides an overview of the steps required to get most models using the v0.4.0 API working with v0.5.0.  It is not a comprehensive review of all changes and new functionalities, but a guide to the minimum steps required to port old models between versions.  For complete information on the new version and its functionalities, see the full documentation.This guide is organized into six main sections, each descripting an independent set of changes that can be undertaken in any order desired.  For clarity, these sections echo the organization of the userguide.Defining components\nConstructing a model\nRunning the model\nAccessing results\nPlotting\nAdvanced topicsA Note on Function Naming: There has been a general overhaul on function names, especially those in the explicity user-facing API, to be consistent with Julia conventions and the conventions of this Package.  These can be briefly summarized as follows:use _ for readability\nappend all functions with side-effects, i.e., non-pure functions that return a value but leave all else unchanged with a !\nthe commonly used terms component, variable, and parameter are shortened to comp, var, and param\nfunctions that act upon a component, variable, or parameter are often written in the form [action]_[comp/var/param]"
},

{
    "location": "integrationguide/#Defining-Components-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Defining Components",
    "category": "section",
    "text": "The run_timestep function is now contained by the @defcomp macro, and takes the parameters p, v, d, t, referring to Parameters, Variables, and Dimensions of the component you defined.  The fourth argument is an AbstractTimestep, i.e., either a FixedTimestep or a VariableTimestep.  Similarly, the optional init function is also contained by @defcomp, and takes the parameters p, v, d.  Thus, as described in the user guide, defining a single component is now done as follows:In this version, the fourth argument (t below) can no longer always be used simply as an Int. Indexing with t is still permitted, but special care must be taken when comparing t with conditionals or using it in arithmatic expressions.  The full API as described later in this document in Advanced Topics:  Timesteps and available functions.  Since differential equations are commonly used as the basis for these models\' equations, the most commonly needed change will be changing if t == 1 to if is_first(t)@defcomp component1 begin\n\n    # First define the state this component will hold\n    savingsrate = Parameter()\n\n    # Second, define the (optional) init function for the component\n    function init(p, v, d)\n    end\n\n    # Third, define the run_timestep function for the component\n    function run_timestep(p, v, d, t)\n    end\n\nend"
},

{
    "location": "integrationguide/#Constructing-a-Model-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Constructing a Model",
    "category": "section",
    "text": "In an effort to standardize the function naming protocol within Mimi, and to streamline it with the Julia convention, several function names have been changed.  The table below lists a subset of these changes, focused on the exported API functions most commonly used in model construction.  Old Syntax New Syntax\naddcomponent! add_comp!\nconnectparameter connect_param!\nsetleftoverparameters set_leftover_params!\nsetparameter set_param!\nadddimension add_dimension!\nsetindex set_dimension!Changes to various optional keyword arguments:add_comp!:  Previously the optional keyword arguments start and stop could be used to specify times for components that do not run for the full length of the model. These arguments are now first and last respectively.add_comp!(mymodel, ComponentC; first=2010, last=2100)"
},

{
    "location": "integrationguide/#Running-a-Model-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Running a Model",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#Accessing-Results-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Accessing Results",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#Plotting-and-the-Explorer-UI-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Plotting and the Explorer UI",
    "category": "section",
    "text": "This release of Mimi does not include the plotting functionality previously offered by Mimi.  While the previous files are still included, the functions are not exported as efforts are made to simplify and improve the plotting associated with Mimi.  The new version does, however, include a new UI tool that can be used to visualize model results.  This explore function is described in the User Guide under Advanced Topics."
},

{
    "location": "integrationguide/#Advanced-Topics-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Advanced Topics",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#Timesteps-and-available-functions-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Timesteps and available functions",
    "category": "section",
    "text": "As previously mentioned, some relevant function names have changed.  These changes were made to eliminate ambiguity.  For example, the new naming clarifies that is_last returns whether the timestep is on the last valid period to be run, not whether it has run through that period already.  This check can still be achieved with is_finished, which retains its name and function.  Below is a subset of such changes related to timesteps and available functions.Old Syntax New Syntax\nisstart is_first\nisstop is_lastAs mentioned in earlier in this document, the fourth argument in run_timestep is an AbstractTimestep i.e. a FixedTimestep or a VariableTimestep and is a type defined within Mimi in \"src/time.jl\".  In this version, the fourth argument (t below) can no longer always be used simply as an Int. Defining the AbstractTimestep object as t, indexing with t is still permitted, but special care must be taken when comparing t with conditionals or using it in arithmatic expressions.  Since differential equations are commonly used as the basis for these models\' equations, the most commonly needed change will be changing if t == 1 to if is_first(t).  There are also new useful functions including is_time(t, y) and is_timestep(t, s).The full API:you may index into a variable or parameter with [t] or [t +/- x] as usual\nto access the time value of t (currently a year) as a Number, use gettime(t)\nuseful functions for commonly used conditionals are is_first(t),is_last(t), is_time(t, y), and is_timestep(t, s)as listed above\nto access the index value of t as a Number representing the position in the time array, use t.t.  Users are encouraged to avoid this access, and instead use the options listed above or a separate counter variable. each time the function gets called.  "
},

{
    "location": "integrationguide/#Parameter-connections-between-different-length-components-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Parameter connections between different length components",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#More-on-parameter-indices-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "More on parameter indices",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#Updating-an-external-parameter-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Updating an external parameter",
    "category": "section",
    "text": "To update an external parameter, use the functions update_param! and udpate_params! (previously known as update_external_parameter and update_external_parameters, respectively.)  Their calling signatures are:update_params!(md::ModelDef, parameters::Dict; update_timesteps = false)\nupdate_param!(md::ModelDef, name::Symbol, value; update_timesteps = false)For external parameters with a :time dimension, passing update_timesteps=true indicates that the time keys (i.e., year labels) should also be updated in addition to updating the parameter values."
},

{
    "location": "integrationguide/#Setting-parameters-with-a-dictionary-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Setting parameters with a dictionary",
    "category": "section",
    "text": "The function set_leftover_params! replaces the function setleftoverparameters."
},

{
    "location": "integrationguide/#Using-NamedArrays-for-setting-parameters-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "Using NamedArrays for setting parameters",
    "category": "section",
    "text": ""
},

{
    "location": "integrationguide/#The-internal-\'build\'-function-and-model-instances-1",
    "page": "Integration Guide: Port to v0.5.0",
    "title": "The internal \'build\' function and model instances",
    "category": "section",
    "text": ""
},

]}
