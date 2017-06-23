var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Welcome-to-Mimi-1",
    "page": "Home",
    "title": "Welcome to Mimi",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Overview-1",
    "page": "Home",
    "title": "Overview",
    "category": "section",
    "text": "Mimi is a package that provides a component model for integrated assessment models."
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "Mimi is an installable package. To install Mimi, use the following:Pkg.add(\"Mimi\")For more complete setup instructions, follow the Installation Guide."
},

{
    "location": "index.html#Models-using-Mimi-1",
    "page": "Home",
    "title": "Models using Mimi",
    "category": "section",
    "text": "FUND.jl (currently in beta)\nMimi-DICE.jl and Mimi-RICE.jl (currently in closed beta)\nMimi-SNEASY.jl (currently in closed beta)"
},

{
    "location": "installation.html#",
    "page": "Installation Guide",
    "title": "Installation Guide",
    "category": "page",
    "text": ""
},

{
    "location": "installation.html#Installation-Guide-1",
    "page": "Installation Guide",
    "title": "Installation Guide",
    "category": "section",
    "text": "This guide will briefly explain how to install julia and Mimi."
},

{
    "location": "installation.html#Installing-julia-1",
    "page": "Installation Guide",
    "title": "Installing julia",
    "category": "section",
    "text": "Mimi requires the programming language julia to run. You can download the current release from the julia download page. You should download and install the command line version from that page."
},

{
    "location": "installation.html#Installing-Mimi-1",
    "page": "Installation Guide",
    "title": "Installing Mimi",
    "category": "section",
    "text": "Once julia is installed, start julia and you should see a julia command prompt. To install the Mimi package, issue the following command:julia> Pkg.add(\"Mimi\")You only have to run this command once on your machine.As Mimi gets improved we will release new versions of the package. To make sure you always have the latest version of Mimi installed, you can run the following command at the julia prompt:julia> Pkg.update()This will update all installed packages to their latest version (not just the Mimi package)."
},

{
    "location": "installation.html#Using-Mimi-1",
    "page": "Installation Guide",
    "title": "Using Mimi",
    "category": "section",
    "text": "When you start a new julia command prompt, Mimi is not yet loaded into that julia session. To load Mimi, issue the following command:julia> using MimiYou will have to run this command every time you want to use Mimi in julia. You would typically also add using Mimi to the top of any julia code file that for example defines Mimi components."
},

{
    "location": "installation.html#Editor-support-1",
    "page": "Installation Guide",
    "title": "Editor support",
    "category": "section",
    "text": "There are various editors around that have julia support:IJulia adds julia support to the jupyter (formerly IPython) notebook system.\nJuno adds julia specific features to the Atom editor. It currently is the closest to a fully featured julia IDE.\nSublime, VS Code, Emacs and many other editors all have julia extensions that add various levels of support for the julia language."
},

{
    "location": "installation.html#Getting-started-1",
    "page": "Installation Guide",
    "title": "Getting started",
    "category": "section",
    "text": "The best way to get started with Mimi is to work through the Tutorial. The examples/tutorial folder in the Mimi github repository has julia code files that completely implement the example described in the tutorial.The Mimi github repository also has links to various models that are based on Mimi, and looking through their code can be instructive.Finally, when in doubt, ask your question in the Mimi gitter chatroom or send an email to David Anthoff (<anthoff@berkeley.edu>) and ask for help. Don't be shy about either option, we would much prefer to be inundated with lots of questions and help people out than people give up on Mimi!"
},

{
    "location": "userguide.html#",
    "page": "User Guide",
    "title": "User Guide",
    "category": "page",
    "text": ""
},

{
    "location": "userguide.html#User-Guide-1",
    "page": "User Guide",
    "title": "User Guide",
    "category": "section",
    "text": ""
},

{
    "location": "userguide.html#Overview-1",
    "page": "User Guide",
    "title": "Overview",
    "category": "section",
    "text": "See the Tutorial for in depth examples of one-region and multi-region models.This guide is organized into six main sections for understanding how to use Mimi.Defining components\nConstructing a model\nRunning the model\nAccessing results\nPlotting\nAdvanced topics"
},

{
    "location": "userguide.html#Defining-Components-1",
    "page": "User Guide",
    "title": "Defining Components",
    "category": "section",
    "text": "Any Mimi model is made up of at least one component, so before you construct a model, you need to create your components. We define a component in the following way:using Mimi\n\n@defcomp MyComponentName begin\n  regions = Index()\n\n  A = Variable(index = [time])\n  B = Variable(index = [time, regions])\n\n  c = Parameter()\n  d = Parameter(index = [time])\n  e = Parameter(index = [time, regions])\n  f = Parameter(index = [regions])\nendA component can have any number of parameters and variables. Parameters are data values that will be provided to the component as input, and variables are values that the component will calculate in the run_timestep function when the model is run. The index of a parameter or variable determines the number of dimensions that parameter or variable has. They can be scalar values and have no index, such as parameter 'c' in the example above. They can be one-dimensional, such as the variable 'A' and the parameters 'd' and 'f' above. They can be two dimensional such as variable 'B' and parameter 'e' above. Note that any index other than 'time' must be declared at the top of the component, as shown by regions = Index() above.The user must define a run_timestep function for each component. That looks like the following:function run_timestep(c::MyComponentName, t::Timestep)\n  params = c.Parameters\n  vars = c.Variables\n  dims = c.Dimensions\n\n  vars.A[t] = params.c + params.d[t]\n  for r in dims.regions\n    vars.B[t, r] = params.f[r] * params.e[t, r]\n  end\nend\nThe run_timestep function is responsible for calculating values for each variable in that component. The first argument to the function is a 'ComponentState', a type whose name matches the component you defined. The second argument is a Timestep, which represents which timestep the model is at each time the function gets called. Note that the component state (the first argument) has fields for the Parameters, Variables, and Dimensions of that component you defined. You can access each parameter, variable, or dimension using dot notation as shown above.To access the data in a parameter or to assign a value to a variable, you must use the appropriate index or indices (in this example, either the Timestep or region or both)."
},

{
    "location": "userguide.html#Constructing-a-Model-1",
    "page": "User Guide",
    "title": "Constructing a Model",
    "category": "section",
    "text": "The first step in constructing a model is to set the values for each index of the model. Below is an example for setting the 'time' and 'regions' indexes. The time index expects either a numerical range or an array of numbers. If a single value is provided, say '100', then that index will be set from 1 to 100. Other indexes can have values of any type.mymodel = Model()\nsetindex(mymodel, :time, 1850:2200)\nsetindex(mymodel, :regions, [\"USA\", \"EU\", \"LATAM\"])\nThe next step is to add components to the model. This is done by the following syntax:addcomponent(mymodel, :ComponentA, :GDP)\naddcomponent(mymodel, :ComponentB; start=2010)\naddcomponent(mymodel, :ComponentC; start=2010, final=2100)\nThe first argument to addcomponent is the model, the second is the name of the component type. If an optional second symbol is provided (as in the first line above), this will be used as the name of the component in this model. This allows you to add multiple versions of the same component to a model, with different names. You can also have components that do not run for the full length of the model. You can specify custom start and final times with the optional keyword arguments as shown above. If no start or final time is provided, the component will assume the start or final time of the model's time index values that were specified in setindex.The next step is to set the values for all the parameters in the components. Parameters can either have their values assigned from external data, or they can internally connect to the values from variables in other components of the model.To make an external connection, the syntax is as follows:setparameter(mymodel, :ComponentName, :parametername, 0.8) # a scalar parameter\nsetparameter(mymodel, :ComponentName, :parametername2, rand(351, 3)) # a two-dimensional parameter\nTo make an internal connection:connectparameter(mymodel, :TargetComponent=>:parametername, :SourceComponent=>:variablename)\nIf you wish to delete a component that has already been added, do the following:delete!(mymodel, :ComponentName)This will delete the component from the model and remove any existing connections it had. Thus if a different component was previously connected to this component, you will need to connect its parameter(s) to something else."
},

{
    "location": "userguide.html#Running-a-Model-1",
    "page": "User Guide",
    "title": "Running a Model",
    "category": "section",
    "text": "After all components have been added to your model and all parameters have been connected to either external values or internally to another component, then the model is ready to be run. Note: at each timestep, the model will run the components in the order you added them. So if one component is going to rely on the value of another component, then the user must add them to the model in the appropriate order.run(mymodel)\n"
},

{
    "location": "userguide.html#Accessing-Results-1",
    "page": "User Guide",
    "title": "Accessing Results",
    "category": "section",
    "text": "After a model has been run, you can access the results (the calculated variable values in each component) in a few different ways.You can use the getindex syntax as follows:mymodel[:ComponentName, :VariableName] # returns the whole array of values\nmymodel[:ComponentName, :VariableName][100] # returns just the 100th value\nIndexing into a model with the name of the component and variable will return an array with values from each timestep. You can index into this array to get one value (as in the second line, which returns just the 100th value). Note that if the requested variable is tow-dimensional, then a 2-D array will be returned.You can also get data in the form of a dataframe, which will display the corresponding index labels rather than just a raw array. The syntax for this is:getdataframe(mymodel, :ComponentName=>:Variable) # request one variable from one component\ngetdataframe(mymodel, :ComponentName=>(:Variable1, :Variable2)) # request multiple variables from the same component\ngetdataframe(mymodel, :Component1=>:Var1, :Component2=>:Var2) # request variables from different components\n"
},

{
    "location": "userguide.html#Plotting-1",
    "page": "User Guide",
    "title": "Plotting",
    "category": "section",
    "text": "(Image: Plotting Example)Mimi provides support for plotting using the Plots module. Mimi extends Plots by adding an additional method to the Plots.plot function. Specifically, it adds a new method with the signaturefunction Plots.plot(m::Model, component::Symbol, parameter::Symbol ; index::Symbol, legend::Symbol, x_label::String, y_label::String)A few important things to note:The model m must be built and run before it is passed into plot\nindex, legend, x_label, and y_label are optional keyword arguments. If no values are provided, the plot will index by time and use the data it has to best fill in the axis labels.\nlegend should be a Symbol that refers to an index on the model set by a call to setindexThis method returns a PlotsPlot object, so calling it in an instance of an IJulia Notebook will display the plot. Because this method is defined on the Plots package, it is easy to use the other features of the Plots package. For example, calling savefig(\"x\") will save the plot as x.png, etc. See the Plots Documentaton for a full list of capabilities."
},

{
    "location": "userguide.html#Advanced-Topics-1",
    "page": "User Guide",
    "title": "Advanced Topics",
    "category": "section",
    "text": ""
},

{
    "location": "userguide.html#Timesteps-and-available-functions-1",
    "page": "User Guide",
    "title": "Timesteps and available functions",
    "category": "section",
    "text": "A Timestep is an immutable type defined within Mimi in \"src/clock.jl\". It is used to represent and keep track of time indices when running a model.In the run_timestep functions which the user defines, it may be useful to use any of the following functions, where t is a Timestep object:isfinaltimestep(t) # returns true or false\nisfirsttimestep(t) # returns true or false\ngettime(t) # returns the year represented by timestep t"
},

{
    "location": "userguide.html#Parameter-connections-between-different-length-components-1",
    "page": "User Guide",
    "title": "Parameter connections between different length components",
    "category": "section",
    "text": "As mentioned earlier, it is possible for some components to start later or end sooner than the full length of the model. This presents potential complications for connecting their parameters. If you are setting the parameters to external values, then the provided values just need to be the right size for that component's parameter. If you are making an internal connection, this can happen in one of two ways:A shorter component is connected to a longer component. In this case, nothing additional needs to happen. The shorter component will pick up the correct values it needs from the longer component.\nA longer component is connected to a shorter component. In this case, the shorter component will not have enough values to supply to the longer component. In order to make this connection, the user must also provide an array of backup data for the parameter to default to when the shorter component does not have values to give. Do this in the following way:backup = rand(100) # data array of the proper size\nconnectparameter(mymodel, :LongComponent=>:parametername, :ShortComponent=>:variablename, backup)Note: for now, to avoid discrepancy with timing and alignment, the backup data must be the length of the whole component's start to final time, even though it will only be used for values not found in the shorter component."
},

{
    "location": "userguide.html#More-on-parameter-indices-1",
    "page": "User Guide",
    "title": "More on parameter indices",
    "category": "section",
    "text": "As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model's indexes. A parameter can also have an index specified in the following ways:@defcomp MyComponent begin\n  p1 = Parameter(index=[4]) # an array of length 4\n  p2::Array{Float64, 2} = Parameter() # a two dimensional array of unspecified length\nendIn both of these cases, the parameter's values are stored of as an array (p1 is one dimensional, and p2 is two dimensional). But with respect to the model, they are considered \"scalar\" parameters, simply because they do not use any of the model's indices (namely 'time', or 'regions')."
},

{
    "location": "userguide.html#Updating-an-external-parameter-1",
    "page": "User Guide",
    "title": "Updating an external parameter",
    "category": "section",
    "text": "When setparameter is called, it creates an external parameter by the name provided, and stores the provided value(s). It is possible to later change the value(s) associated with that parameter name. Use the following available function:update_external_parameter(mymodel, :parametername, newvalues)Note: newvalues must be the same size and type (or be able to convert to the type) of the old values stored in that parameter."
},

{
    "location": "userguide.html#Setting-parameters-with-a-dictionary-1",
    "page": "User Guide",
    "title": "Setting parameters with a dictionary",
    "category": "section",
    "text": "In larger models it can be beneficial to set some of the external parameters using a dictionary of values. To do this, use the following function:setleftoverparameters(mymodel, parameters)Where parameters is a dictionary of type Dict{String, Any} where the keys are strings that match the names of the unset parameters in the model, and the values are the values to use for those parameters."
},

{
    "location": "userguide.html#Using-NamedArrays-for-setting-parameters-1",
    "page": "User Guide",
    "title": "Using NamedArrays for setting parameters",
    "category": "section",
    "text": "When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model's index values for those dimensions. Examples of this can be found in \"test/test_parameter_labels.jl\"."
},

{
    "location": "userguide.html#The-internal-'build'-function-and-model-instances-1",
    "page": "User Guide",
    "title": "The internal 'build' function and model instances",
    "category": "section",
    "text": "When you call the run function on your model, first the internal build function is called, which produces a ModelInstance, and then the ModelInstance is run. A model instance is an instantiated version of the model you have designed where all of the component constructors have been called and all of the data arrays have been allocated. If you wish to create and run multiple versions of your model, you can use the intermediate build function and store the separate ModelInstances. This may be useful if you want to change some parameter values, while keeping the model's structure mostly the same. For example:instance1 = Mimi.build(mymodel)\nrun(instance1)\n\nupdate_external_parameter(mymodel, paramname, newvalue)\ninstance2 = Mimi.build(mymodel)\nrun(instance2)\n\nresult1 = instance1[:Comp, :Var]\nresult2 = instance2[:Comp, :Var]\nNote that you can retrieve values from a ModelInstance in the same way previously shown for indexing into a model."
},

{
    "location": "tutorial.html#",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "page",
    "text": ""
},

{
    "location": "tutorial.html#Tutorial-1",
    "page": "Tutorial",
    "title": "Tutorial",
    "category": "section",
    "text": ""
},

{
    "location": "tutorial.html#Constructing-A-One-Region-Model-1",
    "page": "Tutorial",
    "title": "Constructing A One-Region Model",
    "category": "section",
    "text": "In this example, we will construct a stylized model of the global economy and its changing greenhouse gas emission levels through time. The overall strategy will involve creating components for the economy and emissions separately, and then defining a model where the two components are coupled together.There are two main steps to creating a component:Define the component using @defcomp where the parameters and variables are listed.\nUse the run_timestep function run_timestep(state::component_name, t::Int) to set the equations of that component.Starting with the economy component, each variable and parameter is listed. If either varialbes or parameters have a time-dimension, that must be set with (index=[time]).using Mimi\n\n@defcomp grosseconomy begin\n	YGROSS	= Variable(index=[time])	#Gross output\n	K 		= Variable(index=[time])	#Capital\n	l 		= Parameter(index=[time])	#Labor\n	tfp 	= Parameter(index=[time]) 	#Total factor productivity\n	s 		= Parameter(index=[time])	#Savings rate\n	depk	= Parameter() 				#Depreciation rate on capital - Note that it has no time index\n	k0		= Parameter()				#Initial level of capital\n	share	= Parameter() 				#Capital share\nendNext, the run_timestep function must be defined along with the various equations of the grosseconomy component. In this step, the variables and parameters are linked to this component by state and must be identified as either a variable or a parameter in each equation. For this example, v will refer to variables while p refers to parameters.function run_timestep(state::grosseconomy, t::Int)\n	v = state.Variables\n	p = state.Parameters\n\n	#Define an equation for K\n	if t == 1\n		v.K[t] 	= p.k0	#Note the use of v. and p. to distinguish between variables and parameters\n	else\n		v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5\n	end\n\n	#Define an equation for YGROSS\n	v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)\nendNext, the the component for greenhouse gas emissions must be created.  Although the steps are the same as for the grosseconomy component, there is one minor difference. While YGROSS was a variable in the grosseconomy component, it now enters the emissions component as a parameter. This will be true for any variable that becomes a parameter for another component in the model.@defcomp emissions begin\n	E 		= Variable(index=[time])	#Total greenhouse gas emissions\n	sigma	= Parameter(index=[time])	#Emissions output ratio\n	YGROSS	= Parameter(index=[time])	#Gross output - Note that YGROSS is now a parameter\nendfunction run_timestep(state::emissions, t::Int)\n	v = state.Variables\n	p = state.Parameters\n\n	#Define an equation for E\n	v.E[t] = p.YGROSS[t] * p.sigma[t]	#Note the p. in front of YGROSS\nendWe can now use Mimi to construct a model that binds the grosseconomy and emissions components together in order to solve for the emissions level of the global economy over time. In this example, we will run the model for twenty periods with a timestep of five years between each period.Once the model is defined, setindex is used to set the length and interval of the time step.\nWe then use addcomponent to incorporate each component that we previously created into the model.  It is important to note that the order in which the components are listed here matters.  The model will run through each equation of the first component before moving onto the second component.\nNext, setparameter is used to assign values to each parameter in the model, with parameters being uniquely tied to each component. If _population_ was a parameter for two different components, it must be assigned to each one using setparameter two different times. The syntax is setparameter(model_name, :component_name, :parameter_name, value)\nIf any variables of one component are parameters for another, connectparameter is used to couple the two components together. In this example, _YGROSS_ is a variable in the grosseconomy component and a parameter in the emissions component. The syntax is connectparameter(model_name, :component_name_parameter, :parameter_name, :component_name_variable, :variable_name), where :component_name_variable refers to the component where your parameter was initially calculated as a variable.\nFinally, the model can be run using the command run(model_name).\nTo access model results, use model_name[:component, :variable_name].my_model = Model()\n\nsetindex(my_model, :time, collect(2015:5:2110))\n\naddcomponent(my_model, grosseconomy)  #Order matters here. If the emissions component were defined first, the model would not run.\naddcomponent(my_model, emissions)\n\n#Set parameters for the grosseconomy component\nsetparameter(my_model, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])\nsetparameter(my_model, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])\nsetparameter(my_model, :grosseconomy, :s, ones(20).* 0.22)\nsetparameter(my_model, :grosseconomy, :depk, 0.1)\nsetparameter(my_model, :grosseconomy, :k0, 130.)\nsetparameter(my_model, :grosseconomy, :share, 0.3)\n\n#Set parameters for the emissions component\nsetparameter(my_model, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])\nconnectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)  #Note that connectparameter was used here.\n\nrun(my_model)\n\n#Check model results\nmy_model[:emissions, :E]"
},

{
    "location": "tutorial.html#Constructing-A-Multi-Region-Model-1",
    "page": "Tutorial",
    "title": "Constructing A Multi-Region Model",
    "category": "section",
    "text": "We can now modify our two-component model of the globe to include multiple regional economies.  Global greenhouse gas emissions will now be the sum of regional emissions. The modeling approach is the same, with a few minor adjustments:When using @defcomp, a regions index must be specified. In addition, for variables that have a regional index it is necessary to include (index=[regions]). This can be combined with the time index as well, (index=[time, regions]).\nIn the run_timestep function, a region dimension must be defined using state.Dimensions.  Unlike the time dimension, regions must be specified and looped through in any equations that contain a regional variable or parameter.\nsetindex must be used to specify your regions in the same way that it is used to specify your timestep.\nWhen using setparameter for values with a time and regional dimension, an array is used.  Each row corresponds to a time step, while each column corresponds to a separate region. For regional values with no timestep, a vector can be used. It is often easier to create an array of parameter values before model construction. This way, the parameter name can be entered into setparameter rather than an entire equation.\nWhen constructing regionalized models with multiple components, it is often easier to save each component as a separate file and to then write a function that constructs the model.  When this is done, using Mimi must be speficied for each component. This approach will be used here.To create a three-regional model, we will again start by constructing the grosseconomy and emissions components, making adjustments for the regional index as needed.  Each component should be saved as a separate file.using Mimi\n\n@defcomp grosseconomy begin\n	regions = Index()							#Note that a regional index is defined here\n\n	YGROSS	= Variable(index=[time, regions])	#Gross output\n	K 		= Variable(index=[time, regions])	#Capital\n	l 		= Parameter(index=[time, regions])	#Labor\n	tfp 	= Parameter(index=[time, regions]) 	#Total factor productivity\n	s 		= Parameter(index=[time, regions])	#Savings rate\n	depk	= Parameter(index=[regions]) 		#Depreciation rate on capital - Note that it only has a region index\n	k0		= Parameter(index=[regions])		#Initial level of capital\n	share	= Parameter() 						#Capital share\nend\n\n\nfunction run_timestep(state::grosseconomy, t::Int)\n	v = state.Variables\n	p = state.Parameters\n	d = state.Dimensions 						#Note that the regional dimension is defined here and parameters and variables are indexed by 'r'\n\n	#Define an equation for K\n	for r in d.regions\n		if t == 1\n			v.K[t,r] = p.k0[r]\n		else\n			v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5\n		end\n	end\n\n	#Define an equation for YGROSS\n	for r in d.regions\n		v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)\n	end\nendSave this component as _gross_economy.jl_using Mimi											#Make sure to call Mimi again\n\n@defcomp emissions begin\n	regions 	= Index()							#The regions index must be specified for each component\n\n	E 			= Variable(index=[time, regions])	#Total greenhouse gas emissions\n	E_Global	= Variable(index=[time])			#Global emissions (sum of regional emissions)\n	sigma		= Parameter(index=[time, regions])	#Emissions output ratio\n	YGROSS		= Parameter(index=[time, regions])	#Gross output - Note that YGROSS is now a parameter\nend\n\n\nfunction run_timestep(state::emissions, t::Int)\n	v = state.Variables\n	p = state.Parameters\n	d = state.Dimensions\n\n	#Define an eqation for E\n	for r in d.regions\n		v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]\n	end\n\n	#Define an equation for E_Global\n	for r in d.regions\n		v.E_Global[t] = sum(v.E[t,:])\n	end\nendSave this component as _emissions.jl_Let's create a file with all of our parameters that we can call into our model.  This will help keep things organized as the number of components and regions increases. Each column refers to parameter values for a region, reflecting differences in initial parameter values and growth rates between the three regions.l = Array(Float64,20,3)\nfor t in 1:20\n	l[t,1] = (1. + 0.015)^t *2000\n	l[t,2] = (1. + 0.02)^t * 1250\n	l[t,3] = (1. + 0.03)^t * 1700\nend\n\ntfp = Array(Float64,20,3)\nfor t in 1:20\n	tfp[t,1] = (1 + 0.06)^t * 3.2\n	tfp[t,2] = (1 + 0.03)^t * 1.8\n	tfp[t,3] = (1 + 0.05)^t * 2.5\nend\n\ns = Array(Float64,20,3)\nfor t in 1:20\n	s[t,1] = 0.21\n	s[t,2] = 0.15\n	s[t,3] = 0.28\nend\n\ndepk = [0.11, 0.135 ,0.15]\nk0 	 = [50.5, 22., 33.5]\n\nsigma = Array(Float64,20,3)\nfor t in 1:20\n	sigma[t,1] = (1. - 0.05)^t * 0.58\n	sigma[t,2] = (1. - 0.04)^t * 0.5\n	sigma[t,3] = (1. - 0.045)^t * 0.6\nendSave this file as _region_parameters.jl_The final step is to create a function that will run our model.include(\"gross_economy.jl\")\ninclude(\"emissions.jl\")\n\nfunction run_my_model()\n\n	my_model = Model()\n\n	setindex(my_model, :time, collect(2015:5:2110))\n	setindex(my_model, :regions, [\"Region1\", \"Region2\", \"Region3\"])	 #Note that the regions of your model must be specified here\n\n	addcomponent(my_model, grosseconomy)\n	addcomponent(my_model, emissions)\n\n	setparameter(my_model, :grosseconomy, :l, l)\n	setparameter(my_model, :grosseconomy, :tfp, tfp)\n	setparameter(my_model, :grosseconomy, :s, s)\n	setparameter(my_model, :grosseconomy, :depk,depk)\n	setparameter(my_model, :grosseconomy, :k0, k0)\n	setparameter(my_model, :grosseconomy, :share, 0.3)\n\n	#set parameters for emissions component\n	setparameter(my_model, :emissions, :sigma, sigma)\n	connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)\n\n	run(my_model)\n	return(my_model)\n\nendWe can now call in our parameter file, use run_my_model to construct our model, and evaluate the results.using Mimi\ninclude(\"region_parameters.jl\")\n\nrun1 = run_my_model()\n\n#Check results\nrun1[:emissions, :E_Global]"
},

{
    "location": "faq.html#",
    "page": "FAQ",
    "title": "FAQ",
    "category": "page",
    "text": ""
},

{
    "location": "faq.html#Frequently-asked-questions-1",
    "page": "FAQ",
    "title": "Frequently asked questions",
    "category": "section",
    "text": ""
},

{
    "location": "faq.html#What's-up-with-the-name?-1",
    "page": "FAQ",
    "title": "What's up with the name?",
    "category": "section",
    "text": "The name is probably an acronym for \"Modular Integrated Modeling Interface\", but we are not sure. What is certain is that it came up during a dinner that Bob, David and Sol had in 2015. David thinks that Bob invented the name, Bob doesn't remember and Sol thinks the waiter might have come up with it (although we can almost certainly rule that option out). It certainly is better than the previous name \"IAMF\". We now use \"Mimi\" purely as a name of the package, not as an acronym."
},

{
    "location": "faq.html#How-do-I-use-a-multivariate-distribution-for-a-parameter-within-a-component?-1",
    "page": "FAQ",
    "title": "How do I use a multivariate distribution for a parameter within a component?",
    "category": "section",
    "text": "You might want to use a multivariate distribution to capture the covariance between estimated coefficient parameters.  For example, an estimated polynomial can be represented as a multivariate Normal distribution, with a variance-covariance matrix.  Do use this, define the parameter in the component with a vector type, like here:@defcomp example begin\n    cubiccoeffs::Vector{Float64} = Parameter()\nendThen in the model construction, set the parameter with a multivariate distribution (here the parameters are loaded from a CSV file):cubicparams = readdlm(\"../data/cubicparams.csv\", ',')\nsetparameter(m, :example, :cubiccoeff, MvNormal(squeeze(cubicparams[1,:], 1), cubicparams[2:4,:]))Here, ../data/cubicparams.csv is a parameter definition file that looks something like this:# Example estimated polynomial parameter\n# First line: linear, quadratic, cubic\n# Lines 2-4: covariance matrix\n-3.233303,1.911123,-.1018884\n1.9678593,-.57211657,.04413228\n-.57211657,.17500949,-.01388863\n.04413228,-.01388863,.00111965"
},

{
    "location": "faq.html#How-do-I-use-component-references?-1",
    "page": "FAQ",
    "title": "How do I use component references?",
    "category": "section",
    "text": "Component references allow you to write cleaner model code when connecting components.  The addcomponent function returns a reference to the component that you just added:mycomponent = addcomponent(model, MyComponent)If you want to get a reference to a component after the addcomponent call has been made, you can construct the reference as:mycomponent = ComponentReference(model, :MyComponent)You can use this component reference in place of the setparameter and connectparameter calls."
},

{
    "location": "faq.html#References-in-place-of-setparameter-1",
    "page": "FAQ",
    "title": "References in place of setparameter",
    "category": "section",
    "text": "The line setparameter(model, :MyComponent, :myparameter, myvalue) can be written as mycomponent[:myparameter] = myvalue, where mycomponent is a component reference."
},

{
    "location": "faq.html#References-in-place-of-connectparameter-1",
    "page": "FAQ",
    "title": "References in place of connectparameter",
    "category": "section",
    "text": "The line connectparameter(model, :MyComponent, :myparameter, :YourComponent, :yourparameter) can be written as mycomponent[:myparameter] = yourcomponent[:yourparameter], where mycomponent and yourcomponent are component references."
},

{
    "location": "reference.html#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference.html#Mimi.@defcomp",
    "page": "Reference",
    "title": "Mimi.@defcomp",
    "category": "Macro",
    "text": "@defcomp name begin\n\nDefine a new component.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.setindex",
    "page": "Reference",
    "title": "Mimi.setindex",
    "category": "Function",
    "text": "setindex(m::Model, name::Symbol, count::Int)\n\nSet the values of Model's' index name to integers 1 through count.\n\n\n\nsetindex{T}(m::Model, name::Symbol, values::Vector{T})\n\nSet the values of Model's index name to values.\n\n\n\nsetindex{T}(m::Model, name::Symbol, valuerange::Range{T})\n\nSet the values of Model's index name to the values in the given range valuerange.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.addcomponent",
    "page": "Reference",
    "title": "Mimi.addcomponent",
    "category": "Function",
    "text": "addcomponent(m::Model, t, name::Symbol=t.name.name; before=nothing,after=nothing)\n\nAdd a component of type t to a model.\n\n\n\n"
},

{
    "location": "reference.html#Base.delete!",
    "page": "Reference",
    "title": "Base.delete!",
    "category": "Function",
    "text": "delete!(m::Model, component::Symbol\n\nDelete a component from a model, by name.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.setparameter",
    "page": "Reference",
    "title": "Mimi.setparameter",
    "category": "Function",
    "text": "setparameter(m::Model, component::Symbol, name::Symbol, value, dims)\n\nSet the parameter of a component in a model to a given value. Value can by a scalar, an array, or a NamedAray. Optional argument 'dims' is a list of the dimension names of the provided data, and will be used to check that they match the model's index labels.\n\n\n\nSet a component parameter as setparameter(reference, name, value).\n\n\n\n"
},

{
    "location": "reference.html#Mimi.connectparameter",
    "page": "Reference",
    "title": "Mimi.connectparameter",
    "category": "Function",
    "text": "connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)\n\nConnect a parameter in a component to an external parameter.\n\n\n\nconnectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)\n\nBind the parameter of one component to a variable in another component.\n\n\n\nconnectparameter(m::Model, target::Pair{Symbol, Symbol}, source::Pair{Symbol, Symbol}; ignoreunits::Bool=false)\n\nBind the parameter of one component to a variable in another component.\n\n\n\nConnect two components as connectparameter(reference1, name1, reference2, name2).\n\n\n\nConnect two components as connectparameter(reference1, reference2, name).\n\n\n\n"
},

{
    "location": "reference.html#Mimi.get_unconnected_parameters",
    "page": "Reference",
    "title": "Mimi.get_unconnected_parameters",
    "category": "Function",
    "text": "get_unconnected_parameters(m::Model)\n\nReturn a list of tuples (componentname, parametername) of parameters that have not been connected to a value in the model.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.setleftoverparameters",
    "page": "Reference",
    "title": "Mimi.setleftoverparameters",
    "category": "Function",
    "text": "setleftoverparameters(m::Model, parameters::Dict{Any,Any})\n\nSet all the parameters in a model that don't have a value and are not connected to some other component to a value from a dictionary. This method assumes the dictionary keys are strings that match the names of unset parameters in the model.\n\n\n\n"
},

{
    "location": "reference.html#Base.run",
    "page": "Reference",
    "title": "Base.run",
    "category": "Function",
    "text": "run(m::Model)\n\nRun model m once.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.components",
    "page": "Reference",
    "title": "Mimi.components",
    "category": "Function",
    "text": "components(m::Model)\n\nList all the components in model m.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.variables",
    "page": "Reference",
    "title": "Mimi.variables",
    "category": "Function",
    "text": "variables(m::Model, componentname::Symbol)\n\nList all the variables of componentname in model m.\n\n\n\nvariables(mi::ModelInstance, componentname::Symbol)\n\nList all the variables of componentname in the ModelInstance 'mi'. NOTE: this variables function does NOT take in Nullable instances\n\n\n\n"
},

{
    "location": "reference.html#Mimi.getdataframe",
    "page": "Reference",
    "title": "Mimi.getdataframe",
    "category": "Function",
    "text": "getdataframe(m::Model, componentname::Symbol, name::Symbol)\n\nReturn the values for variable name in componentname of model m as a DataFrame.\n\n\n\ngetdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => name::Symbol)...)\ngetdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => (name::Symbol, name::Symbol...)...)\n\nReturn the values for each variable name in each corresponding componentname of model m as a DataFrame.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.getindexcount",
    "page": "Reference",
    "title": "Mimi.getindexcount",
    "category": "Function",
    "text": "getindexcount(m::Model, i::Symbol)\n\nReturns the size of index i in model m.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.getindexvalues",
    "page": "Reference",
    "title": "Mimi.getindexvalues",
    "category": "Function",
    "text": "getindexvalues(m::Model, i::Symbol)\n\nReturn the values of index i in model m.\n\n\n\n"
},

{
    "location": "reference.html#Mimi.getindexlabels",
    "page": "Reference",
    "title": "Mimi.getindexlabels",
    "category": "Function",
    "text": "getindexlabels(m::Model, component::Symbol, x::Symbol)\n\nReturn the index labels of the variable or parameter in the given component.\n\n\n\n"
},

{
    "location": "reference.html#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": "@defcomp\nsetindex\naddcomponent\ndelete!\nsetparameter\nconnectparameter\nget_unconnected_parameters\nsetleftoverparameters\nrun\ncomponents\nvariables\ngetdataframe\ngetindexcount\ngetindexvalues\ngetindexlabels"
},

]}
