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
    "text": "The best way to get started with Mimi is to work through the Tutorial. The examples/tutorial folder in the Mimi github repository has julia code files that completely implement the example described in the tutorial.The Mimi github repository also has links to various models that are based on Mimi, and looking through their code can be instructive.Finally, when in doubt, ask your question in the Mimi gitter chatroom or send an email to David Anthoff (<anthoff@berkeley.edu>) and ask for help. Don\'t be shy about either option, we would much prefer to be inundated with lots of questions and help people out than people give up on Mimi!"
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
    "text": "See the Tutorial for in depth examples of one-region and multi-region models.This guide is organized into six main sections for understanding how to use Mimi.Defining components\nConstructing a model\nRunning the model\nAccessing results\nPlotting and the Explorer UI\nAdvanced topics"
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
    "location": "tutorial/#",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "page",
    "text": ""
},

{
    "location": "tutorial/#Tutorial-1",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "section",
    "text": ""
},

{
    "location": "tutorial/#Constructing-A-One-Region-Model-1",
    "page": "Tutorial",
    "title": "Constructing A One-Region Model",
    "category": "section",
    "text": "In this example, we will construct a stylized model of the global economy and its changing greenhouse gas emission levels through time. The overall strategy will involve creating components for the economy and emissions separately, and then defining a model where the two components are coupled together.There are two main steps to creating a component, both within the  @defcomp macro which defines a component:List the parameters and variables.\nUse the run_timestep function run_timestep(p, v, d, t) to set the equations of that component.Starting with the economy component, each variable and parameter is listed. If either variables or parameters have a time-dimension, that must be set with (index=[time]).using Mimi\n\n@defcomp grosseconomy begin\n	YGROSS	= Variable(index=[time])	#Gross output\n	K	= Variable(index=[time])	#Capital\n	l	= Parameter(index=[time])	#Labor\n	tfp	= Parameter(index=[time])	#Total factor productivity\n	s	= Parameter(index=[time])	#Savings rate\n	depk	= Parameter()			#Depreciation rate on capital - Note that it has no time index\n	k0	= Parameter()			#Initial level of capital\n	share	= Parameter()			#Capital share\nNext, the run_timestep function must be defined along with the various equations of the grosseconomy component. In this step, the variables and parameters are linked to this component and must be identified as either a variable or a parameter in each equation. For this example, v will refer to variables while p refers to parameters.It is important to note that t below is an AbstractTimestep, and the specific API for using this argument are described in detail in the userguide in Advanced Topics:  Timesteps and available functions. 	function run_timestep(p, v, d, t)\n		#Define an equation for K\n		if is_first(t)\n			#Note the use of v. and p. to distinguish between variables and parameters\n			v.K[t] 	= p.k0	\n		else\n			v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5\n		end\n\n		#Define an equation for YGROSS\n		v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)\n	end\nendNext, the the component for greenhouse gas emissions must be created.  Although the steps are the same as for the grosseconomy component, there is one minor difference. While YGROSS was a variable in the grosseconomy component, it now enters the emissions component as a parameter. This will be true for any variable that becomes a parameter for another component in the model.@defcomp emissions begin\n	E 	= Variable(index=[time])	#Total greenhouse gas emissions\n	sigma	= Parameter(index=[time])	#Emissions output ratio\n	YGROSS	= Parameter(index=[time])	#Gross output - Note that YGROSS is now a parameter\n\n	function run_timestep(p, v, d, t)\n\n		#Define an equation for E\n		v.E[t] = p.YGROSS[t] * p.sigma[t]	#Note the p. in front of YGROSS\n	end\nendWe can now use Mimi to construct a model that binds the grosseconomy and emissions components together in order to solve for the emissions level of the global economy over time. In this example, we will run the model for twenty periods with a timestep of five years between each period.Once the model is defined, set_dimension! is used to set the length and interval of the time step.\nWe then use add_comp! to incorporate each component that we previously created into the model.  It is important to note that the order in which the components are listed here matters.  The model will run through each equation of the first component before moving onto the second component.\nNext, set_param! is used to assign values to each parameter in the model, with parameters being uniquely tied to each component. If population was a parameter for two different components, it must be assigned to each one using set_param! two different times. The syntax is set_param!(model_name, :component_name, :parameter_name, value)\nIf any variables of one component are parameters for another, connect_param! is used to couple the two components together. In this example, YGROSS is a variable in the grosseconomy component and a parameter in the emissions component. The syntax is connect_param!(model_name, :component_name_parameter, :parameter_name, :component_name_variable, :variable_name), where :component_name_variable refers to the component where your parameter was initially calculated as a variable.\nFinally, the model can be run using the command run(model_name).\nTo access model results, use model_name[:component, :variable_name].\nTo observe model results in a graphical form ,use explore(model_name) to open the UI window, or use explore(model_name, :component_name, :variable_name) or explore(model_name, :component_name, :parameter_name) to plot a specific parameter or variable.module my_model\n\nusing Mimi\n\nexport m\n\nm = Model()\n\nset_dimension!(m, :time, collect(2015:5:2110))\n\n#Order matters here. If the emissions component were defined first, the model would not run.\nadd_comp!(my_model, grosseconomy)  \nadd_comp!(my_model, emissions)\n\n#Set parameters for the grosseconomy component\nset_param!(my_model, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])\nset_param!(my_model, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])\nset_param!(my_model, :grosseconomy, :s, ones(20).* 0.22)\nset_param!(my_model, :grosseconomy, :depk, 0.1)\nset_param!(my_model, :grosseconomy, :k0, 130.)\nset_param!(my_model, :grosseconomy, :share, 0.3)\n\n#Set parameters for the emissions component\nset_param!(my_model, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])\nconnect_param!(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)  \n#Note that connect_param! was used here.\n\nend #end module\nNow we can run the model and examine the results:#Run model\nusing my_model\nrun(m)\n\n#Check model results\nm[:emissions, :E]\n\n#Plot model results\nexplore(m, :emissions, :E)\n\n#Observe all model result graphs in UI\nexplore(m)\n\n"
},

{
    "location": "tutorial/#Constructing-A-Multi-Region-Model-1",
    "page": "Tutorial",
    "title": "Constructing A Multi-Region Model",
    "category": "section",
    "text": "We can now modify our two-component model of the globe to include multiple regional economies.  Global greenhouse gas emissions will now be the sum of regional emissions. The modeling approach is the same, with a few minor adjustments:When using @defcomp, a regions index must be specified. In addition, for variables that have a regional index it is necessary to include (index=[regions]). This can be combined with the time index as well, (index=[time, regions]).\nIn the run_timestep function, unlike the time dimension, regions must be specified and looped through in any equations that contain a regional variable or parameter.\nset_dimension! must be used to specify your regions in the same way that it is used to specify your timestep.\nWhen using set_param! for values with a time and regional dimension, an array is used.  Each row corresponds to a time step, while each column corresponds to a separate region. For regional values with no timestep, a vector can be used. It is often easier to create an array of parameter values before model construction. This way, the parameter name can be entered into set_param! rather than an entire equation.\nWhen constructing regionalized models with multiple components, it is often easier to save each component as a separate file and to then write a function that constructs the model.  When this is done, using Mimi must be speficied for each component. This approach will be used here.To create a three-regional model, we will again start by constructing the grosseconomy and emissions components, making adjustments for the regional index as needed.  Each component should be saved as a separate file.using Mimi\n\n@defcomp grosseconomy begin\n	regions = Index()	#Note that a regional index is defined here\n\n	YGROSS	= Variable(index=[time, regions])	#Gross output\n	K 	= Variable(index=[time, regions])	#Capital\n	l 	= Parameter(index=[time, regions])	#Labor\n	tfp	= Parameter(index=[time, regions])	#Total factor productivity\n	s 	= Parameter(index=[time, regions])	#Savings rate\n	depk	= Parameter(index=[regions])	#Depreciation rate on capital - Note that it only has a region index\n	k0	= Parameter(index=[regions])	#Initial level of capital\n	share	= Parameter()	#Capital share\n\n	function run_timestep(p, v, d, t)\n		\n		#Note that the regional dimension is used below and parameters and \n		variables are indexed by \'r\'\n\n		#Define an equation for K\n		for r in d.regions\n			if is_first(t)\n				v.K[t,r] = p.k0[r]\n			else\n				v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5\n			end\n		end\n\n		#Define an equation for YGROSS\n		for r in d.regions\n			v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)\n		end\n	end\nendSave this component as **grosseconomy.jl**_using Mimi	#Make sure to call Mimi again\n\n@defcomp emissions begin\n	regions	=	Index()	#The regions index must be specified for each component\n\n	E		= Variable(index=[time, regions])	#Total greenhouse gas emissions\n	E_Global		= Variable(index=[time])		#Global emissions (sum of regional emissions)\n	sigma		= Parameter(index=[time, regions])	#Emissions output ratio\n	YGROSS		= Parameter(index=[time, regions])	#Gross output - Note that YGROSS is now a parameter\n\n	function run_timestep(p, v, d, t)\n\n		#Define an eqation for E\n		for r in d.regions\n			v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]\n		end\n\n		#Define an equation for E_Global\n		for r in d.regions\n			v.E_Global[t] = sum(v.E[t,:])\n		end\n	end\nendSave this component as emissions.jlLet\'s create a file with all of our parameters that we can call into our model.  This will help keep things organized as the number of components and regions increases. Each column refers to parameter values for a region, reflecting differences in initial parameter values and growth rates between the three regions.l = Array(Float64,20,3)\nfor t in 1:20\n	l[t,1] = (1. + 0.015)^t *2000\n	l[t,2] = (1. + 0.02)^t * 1250\n	l[t,3] = (1. + 0.03)^t * 1700\nend\n\ntfp = Array(Float64,20,3)\nfor t in 1:20\n	tfp[t,1] = (1 + 0.06)^t * 3.2\n	tfp[t,2] = (1 + 0.03)^t * 1.8\n	tfp[t,3] = (1 + 0.05)^t * 2.5\nend\n\ns = Array(Float64,20,3)\nfor t in 1:20\n	s[t,1] = 0.21\n	s[t,2] = 0.15\n	s[t,3] = 0.28\nend\n\ndepk = [0.11, 0.135 ,0.15]\nk0 	 = [50.5, 22., 33.5]\n\nsigma = Array(Float64,20,3)\nfor t in 1:20\n	sigma[t,1] = (1. - 0.05)^t * 0.58\n	sigma[t,2] = (1. - 0.04)^t * 0.5\n	sigma[t,3] = (1. - 0.045)^t * 0.6\nendSave this file as **regionparameters.jl**_The final step is to create a module.module my_model\n\nusing Mimi\n\nexport m \n\ninclude(\"region_parameters.jl\")\ninclude(\"gross_economy.jl\")\ninclude(\"emissions.jl\")\n\nm = Model()\n\nset_dimension!(m, :time, collect(2015:5:2110))\nset_dimension!(m, :regions, [\"Region1\", \"Region2\", \"Region3\"])	 #Note that the regions of your model must be specified here\n\nadd_comp!(m, grosseconomy)\nadd_comp!(m, emissions)\n\nset_param!(m, :grosseconomy, :l, l)\nset_param!(m, :grosseconomy, :tfp, tfp)\nset_param!(m, :grosseconomy, :s, s)\nset_param!(m, :grosseconomy, :depk,depk)\nset_param!(m, :grosseconomy, :k0, k0)\nset_param!(m, :grosseconomy, :share, 0.3)\n\n#set parameters for emissions component\nset_param!(my_model, :emissions, :sigma, sigma)\nconnect_param!(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)\n\nend #end module\nSave this file as **mymodel.jl**_We can now run the model and evaluate the results.using Mimi\n\ninclude(\"my_model.jl\")\nusing my_model\n\nrun(m)\n\n#Check results\nm[:emissions, :E_Global]\n\n#Observe model result graphs\nexplore(m)\n"
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
    "location": "reference/#Mimi.@defcomp",
    "page": "Reference",
    "title": "Mimi.@defcomp",
    "category": "macro",
    "text": "defcomp(comp_name::Symbol, ex::Expr)\n\nDefine a Mimi component comp_name with the expressions in ex.  The following  types of expressions are supported:\n\ndimension_name = Index()   # defines a dimension\nparameter = Parameter(index = [dimension_name], units = \"unit_name\", default = default_value)    # defines a parameter with optional arguments\nvariable = Variable(index = [dimension_name], units = \"unit_name\")    # defines a variable with optional arguments\ninit(p, v, d)              # defines an init function for the component\nrun_timestep(p, v, d, t)   # defines a run_timestep function for the component\n\nParses a @defcomp definition, converting it into a series of function calls that create the corresponding ComponentDef instance. At model build time, the ModelDef (including its ComponentDefs) will be converted to a runnable model.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.MarginalModel",
    "page": "Reference",
    "title": "Mimi.MarginalModel",
    "category": "type",
    "text": "MarginalModel\n\nA Mimi Model whose results are obtained by subtracting results of one base Model  from those of another marginal Modelthat has a difference ofdelta`.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.Model",
    "page": "Reference",
    "title": "Mimi.Model",
    "category": "type",
    "text": "Model\n\nA user-facing API containing a ModelInstance (mi) and a ModelDef (md).   This Model can be created with the optional keyword argument number_type indicating the default type of number used for the ModelDef.  If not specified the Model assumes a number_type of Float64.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.add_comp!",
    "page": "Reference",
    "title": "Mimi.add_comp!",
    "category": "function",
    "text": "add_comp!(md::ModelDef, comp_def::ComponentDef; first=nothing, last=nothing, before=nothing, after=nothing)\n\nAdd the component indicated by comp_def to the model indcated by md. The component is added at the  end of the list unless one of the keywords, first, last, before, after. If the comp_name differs from that in the comp_def, a copy of comp_def is made and assigned the new name.\n\n\n\n\n\nadd_comp!(md::ModelDef, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name, \n    first=nothing, last=nothing, before=nothing, after=nothing)\n\nAdd the component indicated by comp_id to the model indicated by md. The component is added at the end of  the list unless one of the keywords, first, last, before, after. If the comp_name differs from that in the comp_def, a copy of comp_def is made and assigned the new name.\n\n\n\n\n\nadd_comp!(mi::ModelInstance, ci::ComponentInstance)\n\nAdd the component ci to the ModelInstance mi\'s list of components, and add the first and last of mi to the ends of the firsts and lasts lists of  mi, respectively.\n\n\n\n\n\nadd_comp!(m::Model, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name;\n    first=nothing, last=nothing, before=nothing, after=nothing)\n\nAdd the component indicated by comp_id to the model indicated by m. The component is added at the end of  the list unless one of the keywords, first, last, before, after. If the comp_name differs from that in the comp_id, a copy of comp_id is made and assigned the new name.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.components",
    "page": "Reference",
    "title": "Mimi.components",
    "category": "function",
    "text": "components(mi::ModelInstance)\n\nReturn an iterator on the components in model instance mi.\n\n\n\n\n\ncomponents(m::Model)\n\nReturn an iterator on the components in model m.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.connect_param!",
    "page": "Reference",
    "title": "Mimi.connect_param!",
    "category": "function",
    "text": "connect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)\n\nConnect a parameter param_name in the component comp_name of model md to the external parameter ext_param_name. \n\n\n\n\n\nconnect_param!(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, \n    src_comp_name::Symbol, src_var_name::Symbol backup::Union{Nothing, Array}=nothing; \n    ignoreunits::Bool=false, offset::Int=0)\n\nBind the parameter dst_par_name of one component dst_comp_name of model md to a variable src_var_name in another component src_comp_name of the same model using backup to provide default values and the ignoreunits flag to indicate the need to check match units between the two.  The offset argument indicates the offset between the destination  and the source ie. the value would be 1 if the destination component parameter  should only be calculated for the second timestep and beyond.\n\n\n\n\n\nconnect_param!(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, \n    backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)\n\nBind the parameter dst[2] of one component dst[1] of model md to a variable src[2] in another component src[1] of the same model using backup to provide default values and the ignoreunits flag to indicate the need to check match units between the two.  The offset argument indicates the offset between the destination and the source ie. the value would be 1 if the destination  component parameter should only be calculated for the second timestep and beyond.\n\n\n\n\n\nconnect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)\n\nConnect two components as connect_param!(dst, dst_name, src, src_name).\n\n\n\n\n\nconnect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)\n\nConnect two components with the same name as connect_param!(dst, src, name).\n\n\n\n\n\nconnect_param!(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, \n    src_var_name::Symbol, backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)\n\nBind the parameter dst_par_name of one component dst_comp_name of model md to a variable src_var_name in another component src_comp_name of the same model using backup to provide default values and the ignoreunits flag to indicate the need to check match units between the two.  The offset argument indicates the offset between the destination and the source ie. the value would be 1 if the destination  component parameter should only be calculated for the second timestep and beyond.\n\n\n\n\n\nconnect_param!(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)\n\nBind the parameter dst[2] of one component dst[1] of model md to a variable src[2] in another component src[1] of the same model using backup to provide default values and the ignoreunits flag to indicate the need to check match units between the two.  The offset argument indicates the offset between the destination and the source ie. the value would be 1 if the destination  component parameter should only be calculated for the second timestep and beyond.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.create_marginal_model",
    "page": "Reference",
    "title": "Mimi.create_marginal_model",
    "category": "function",
    "text": "create_marginal_model(base::Model, delta::Float64=1.0)\n\nCreate a MarginalModel where base is the baseline model and delta is the  difference used to create the marginal model.  Return the resulting MarginaModel which shares the internal ModelDef between the base and marginal.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.disconnect_param!",
    "page": "Reference",
    "title": "Mimi.disconnect_param!",
    "category": "function",
    "text": "disconnect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol)\n\nRemove any parameter connections for a given parameter param_name in a given component comp_name of model md.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.explore",
    "page": "Reference",
    "title": "Mimi.explore",
    "category": "function",
    "text": "explore(m::Model; title = \"Electron\")\n\nProduce a UI to explore the parameters and variables of Model m in a Window with title title.\n\n\n\n\n\nexplore(m::Model, comp_name::Symbol, datum_name::Symbol)\n\nPlot a specific datum_name (a variable or parameter) of Model m.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.getdataframe",
    "page": "Reference",
    "title": "Mimi.getdataframe",
    "category": "function",
    "text": "getdataframe(m::Model, comp_name::Symbol, pairs::Pair{Symbol, Symbol}...)\n\nReturn a DataFrame with values for the given variables or parameters of model m indicated by pairs, where each pair is of the form comp_name => item_name. If more than one pair is provided, all must refer to items with the same dimensions, which are used to join the respective item values.\n\n\n\n\n\ngetdataframe(m::Model, pair::Pair{Symbol, NTuple{N, Symbol}})\n\nReturn a DataFrame with values for the given variables or parameters  indicated by pairs, where each pair is of the form comp_name => item_name. If more than one pair is provided, all must refer to items with the same dimensions, which are used to join the respective item values.\n\n\n\n\n\ngetdataframe(m::Model, comp_name::Symbol, item_name::Symbol)\n\nReturn the values for variable or parameter item_name in comp_name of  model m as a DataFrame.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.gettime",
    "page": "Reference",
    "title": "Mimi.gettime",
    "category": "function",
    "text": "gettime(ts::FixedTimestep)\n\nReturn the time (year) represented by Timestep ts \n\n\n\n\n\ngettime(ts::VariableTimestep)\n\nReturn the time (year) represented by Timestep ts \n\n\n\n\n\ngettime(c::Clock)\n\nReturn the current time of the timestep held by the c clock.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.get_param_value",
    "page": "Reference",
    "title": "Mimi.get_param_value",
    "category": "function",
    "text": "get_param_value(ci::ComponentInstance, name::Symbol)\n\nReturn the value of parameter name in component ci.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.get_var_value",
    "page": "Reference",
    "title": "Mimi.get_var_value",
    "category": "function",
    "text": "get_var_value(ci::ComponentInstance, name::Symbol)\n\nReturn the value of variable name in component ci.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.hasvalue",
    "page": "Reference",
    "title": "Mimi.hasvalue",
    "category": "function",
    "text": "hasvalue(arr::TimestepArray, ts::FixedTimestep)\n\nReturn true or false, true if the TimestepArray arr contains the Timestep ts.\n\n\n\n\n\nhasvalue(arr::TimestepArray, ts::VariableTimestep)\n\nReturn true or false, true if the TimestepArray arr contains the Timestep ts.\n\n\n\n\n\nhasvalue(arr::TimestepArray, ts::FixedTimestep, idxs::Int...)\n\nReturn true or false, true if the TimestepArray arr contains the Timestep ts within indices idxs. Used when Array and Timestep have different FIRST, validating all dimensions.\n\n\n\n\n\nhasvalue(arr::TimestepArray, ts::VariableTimestep, idxs::Int...)\n\nReturn true or false, true if the TimestepArray arr contains the Timestep ts within indices idxs. Used when Array and Timestep different TIMES, validating all dimensions.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.is_first",
    "page": "Reference",
    "title": "Mimi.is_first",
    "category": "function",
    "text": "is_first(ts::AbstractTimestep)\n\nReturn true or false, true if ts is the first timestep to be run.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.is_last",
    "page": "Reference",
    "title": "Mimi.is_last",
    "category": "function",
    "text": "is_last(ts::FixedTimestep)\n\nReturn true or false, true if ts is the last timestep to be run.\n\n\n\n\n\nis_last(ts::VariableTimestep)\n\nReturn true or false, true if ts is the last timestep to be run.  Note that you may run next_timestep on ts, as ths final timestep has not been run through yet.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.is_time",
    "page": "Reference",
    "title": "Mimi.is_time",
    "category": "function",
    "text": "is_time(ts::AbstractTimestep, t::Int)\n\nReturn true or false, true if the current time (year) for ts is t\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.is_timestep",
    "page": "Reference",
    "title": "Mimi.is_timestep",
    "category": "function",
    "text": "is_timestep(ts::AbstractTimestep, t::Int)\n\nReturn true or false, true if ts timestep is step t.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.load_comps",
    "page": "Reference",
    "title": "Mimi.load_comps",
    "category": "function",
    "text": "load_comps(dirname::String=\"./components\")\n\nCall include() on all the files in the indicated directory dirname. This avoids having modelers create a long list of include() statements. Just put all the components in a directory.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.modeldef",
    "page": "Reference",
    "title": "Mimi.modeldef",
    "category": "function",
    "text": "modeldef(mi)\n\nReturn the ModelDef contained by ModelInstance mi.\n\n\n\n\n\nmodeldef(m)\n\nReturn the ModelDef contained by Model m.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.name",
    "page": "Reference",
    "title": "Mimi.name",
    "category": "function",
    "text": "name(def::NamedDef) = def.name\n\nReturn the name of def.  Possible NamedDefs include DatumDef, and ComponentDef.\n\n\n\n\n\nname(ci::ComponentInstance)\n\nReturn the name of the component ci.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.new_comp",
    "page": "Reference",
    "title": "Mimi.new_comp",
    "category": "function",
    "text": "new_comp(comp_id::ComponentId, verbose::Bool=true)\n\nAdd an empty ComponentDef to the global component registry with the given comp_id. The empty ComponentDef must be populated with calls to addvariable, addparameter, etc.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.parameters",
    "page": "Reference",
    "title": "Mimi.parameters",
    "category": "function",
    "text": "parameters(comp_def::ComponentDef)\n\nReturn a list of the parameter definitions for comp_def.\n\n\n\n\n\nparameters(comp_id::ComponentDef)\n\nReturn a list of the parameter definitions for comp_id.\n\n\n\n\n\nparameters(mi::ModelInstance, comp_name::Symbol)\n\nReturn the ComponentInstanceParameters for comp_name in ModelInstance \'mi\'.\n\n\n\n\n\nparameters(ci::ComponentInstance)\n\nReturn an iterable over the parameters in ci.\n\n\n\n\n\nparameters(m::Model, comp_name::Symbol)\n\nReturn a list of the parameter definitions for comp_name in model m.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.plot_comp_graph",
    "page": "Reference",
    "title": "Mimi.plot_comp_graph",
    "category": "function",
    "text": "plot_comp_graph(m::Model, filename::Union{Nothing, Symbol} = nothing)\n\nPlot the DAG of component connections within model m and save to filename. If no filename is given, plot will simply display.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.replace_comp!",
    "page": "Reference",
    "title": "Mimi.replace_comp!",
    "category": "function",
    "text": "replace_comp!(md::ModelDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;\n    first::NothingInt=nothing, last::NothingInt=nothing,\n    before::NothingSymbol=nothing, after::NothingSymbol=nothing,\n    reconnect::Bool=true)\n\nReplace the component with name comp_name in model definition md with the  component comp_id using the same name. The component is added in the same  position as the old component, unless one of the keywords before or after  is specified. The component is added with the same first and last values,  unless the keywords first or last are specified. Optional boolean argument  reconnect with default value true indicates whether the existing parameter  connections should be maintained in the new component.\n\n\n\n\n\nreplace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;\n    first::NothingSymbol=nothing, last::NothingSymbol=nothing,\n    before::NothingSymbol=nothing, after::NothingSymbol=nothing,\n    reconnect::Bool=true)\n\nReplace the component with name comp_name in model m with the component comp_id using the same name.  The component is added in the same position as  the old component, unless one of the keywords before or after is specified. The component is added with the same first and last values, unless the keywords  first or last are specified. Optional boolean argument reconnect with  default value true indicates whether the existing parameter connections  should be maintained in the new component.  \n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.set_dimension!",
    "page": "Reference",
    "title": "Mimi.set_dimension!",
    "category": "function",
    "text": "set_dimension!(md::ModelDef, name::Symbol, keys::Union{Int, Vector, Tuple, Range})\n\nSet the values of md dimension name to integers 1 through count, if keys is an integer; or to the values in the vector or range if keys is either of those types.\n\n\n\n\n\nset_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, AbstractRange})\n\nSet the values of m dimension name to integers 1 through count, if keysis an integer; or to the values in the vector or range ifkeys`` is either of those types.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.set_leftover_params!",
    "page": "Reference",
    "title": "Mimi.set_leftover_params!",
    "category": "function",
    "text": "set_leftover_params!(m::Model, parameters::Dict)\n\nSet all of the parameters in model m that don\'t have a value and are not connected to some other component to a value from a dictionary parameters. This method assumes the dictionary keys are strings that match the names of unset parameters in the model.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.set_param!",
    "page": "Reference",
    "title": "Mimi.set_param!",
    "category": "function",
    "text": "set_param!(m::ModelDef, comp_name::Symbol, name::Symbol, value, dims=nothing)\n\nSet the parameter name of a component comp_name in a model m to a given value. The value can by a scalar, an array, or a NamedAray. Optional argument \'dims\' is a  list of the dimension names ofthe provided data, and will be used to check that  they match the model\'s index labels.\n\n\n\n\n\nset_param!(ref::ComponentReference, name::Symbol, value)\n\nSet a component parameter as set_param!(reference, name, value).\n\n\n\n\n\nset_param!(m::Model, comp_name::Symbol, name::Symbol, value, dims=nothing)\n\nSet the parameter of a component comp_name in a model m to a given value.  The value can by a scalar, an array, or a NamedAray. Optional argument \'dims\'  is a list of the dimension names of the provided data, and will be used to check  that they match the model\'s index labels.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.variables",
    "page": "Reference",
    "title": "Mimi.variables",
    "category": "function",
    "text": "variables(mi::ModelInstance, comp_name::Symbol)\n\nReturn the ComponentInstanceVariables for comp_name in ModelInstance \'mi\'.\n\n\n\n\n\nvariables(m::Model, comp_name::Symbol)\n\nReturn a list of the variable definitions for comp_name in model m.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.update_param!",
    "page": "Reference",
    "title": "Mimi.update_param!",
    "category": "function",
    "text": "update_param!(md::ModelDef, name::Symbol, value; update_timesteps = false)\n\nUpdate the value of an external model parameter in ModelDef md, referenced  by name. Optional boolean argument update_timesteps with default value  false indicates whether to update the time keys associated with the parameter  values to match the model\'s time index.\n\n\n\n\n\nupdate_param!(m::Model, name::Symbol, value; update_timesteps = false)\n\nUpdate the value of an external model parameter in model m, referenced by  name. Optional boolean argument update_timesteps with default value false  indicates whether to update the time keys associated with the parameter values  to match the model\'s time index.\n\n\n\n\n\n"
},

{
    "location": "reference/#Mimi.update_params!",
    "page": "Reference",
    "title": "Mimi.update_params!",
    "category": "function",
    "text": "update_params!(md::ModelDef, parameters::Dict{T, Any}; update_timesteps = false) where T\n\nFor each (k, v) in the provided parameters dictionary, updateparam!  is called to update the external parameter by name k to value v, with optional  Boolean argument updatetimesteps. Each key k must be a symbol or convert to a symbol matching the name of an external parameter that already exists in the  model definition.\n\n\n\n\n\nupdate_params!(m::Model, parameters::Dict{T, Any}; update_timesteps = false) where T\n\nFor each (k, v) in the provided parameters dictionary, updateparam!  is called to update the external parameter by name k to value v, with optional  Boolean argument updatetimesteps. Each key k must be a symbol or convert to a symbol matching the name of an external parameter that already exists in the  model definition.\n\n\n\n\n\n"
},

{
    "location": "reference/#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": "@defcomp\nMarginalModel\nModel\nadd_comp!  \ncomponents \nconnect_param!\ncreate_marginal_model\ndisconnect_param!\nexplore\ngetdataframe\ngettime\nget_param_value\nget_var_value\nhasvalue\nis_first\nis_last\nis_time\nis_timestep\nload_comps\nmodeldef\nname\nnew_comp\nparameters\nplot_comp_graph\nreplace_comp! \nset_dimension! \nset_leftover_params! \nset_param! \nvariables  \nupdate_param!\nupdate_params!"
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
