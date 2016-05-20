###Constructing A One-Region Model
---

In this example, we will construct a stylized model of the global economy and its changing greenhouse gas emission levels through time. The overall strategy will involve creating components for the economy and emissions separately, and then defining a model where the two components are coupled together.

There are two main steps to creating a component:

* Define the component using ``@defcomp`` where the parameters and variables are listed.
* Use the timestep function ``timestep(state::component_name, t:Int)`` to set the equations of that component.

Starting with the economy component, each variable and parameter is listed. If either varialbes or parameters have a time-dimension, that must be set with ``(index=[time])``.

```julia
using Mimi

@defcomp grosseconomy begin
	YGROSS	= Variable(index=[time])	#Gross output
	K 		= Variable(index=[time])	#Capital
	l 		= Parameter(index=[time])	#Labor
	tfp 	= Parameter(index=[time]) 	#Total factor productivity
	s 		= Parameter(index=[time])	#Savings rate
	depk	= Parameter() 				#Depreciation rate on capital - Note that it has no time index
	k0		= Parameter()				#Initial level of capital
	share	= Parameter() 				#Capital share
end
```

Next, the timestep function must be defined along with the various equations of the ``grosseconomy`` component. In this step, the variables and parameters are linked to this component by ``state`` and must be identified as either a variable or a parameter in each equation. For this example, ``v`` will refer to variables while ``p`` refers to paremeters.

```julia
function timestep(state::grosseconomy, t::Int)
	v = state.Variables
	p = state.Parameters

	#Define an equation for K
	if t == 1
		v.K[t] 	= p.k0	#Note the use of v. and p. to distinguish between variables and parameters
	else
		v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
	end

	#Define an equation for YGROSS
	v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
end
```

Next, the the component for greenhouse gas emissions must be created.  Although the steps are the same as for the ``grosseconomy`` component, there is one minor difference. While ``YGROSS`` was a variable in the ``grosseconomy`` component, it now enters the ``emissions`` component as a parameter. This will be true for any variable that becomes a parameter for another component in the model.

```julia
@defcomp emissions begin
	E 		= Variable(index=[time])	#Total greenhouse gas emissions
	sigma	= Parameter(index=[time])	#Emissions output ratio
	YGROSS	= Parameter(index=[time])	#Gross output - Note that YGROSS is now a parameter
end
```

```julia
function timestep(state::emissions, t::Int)
	v = state.Variables
	p = state.Parameters

	#Define an eqation for E
	v.E[t] = p.YGROSS[t] * p.sigma[t]	#Note the p. in front of YGROSS
end
```

We can now use Mimi to construct a model that binds the ``grosseconomy`` and ``emissions`` components together in order to solve for the emissions level of the global economy over time. In this example, we will run the model for twenty periods with a timestep of five years between each period.

* Once the model is defined, ``setindex`` is used to set the length and interval of the time step.
* We then use ``addcomponent`` to incorporate each component that we previously created into the model.  It is important to note that the order in which the components are listed here matters.  The model will run through each equation of the first component before moving onto the second component.
* Next, ``setparameter`` is used to assign values to each parameter in the model, with parameters being uniquely tied to each component. If _population_ was a parameter for two different components, it must be assigned to each one using ``setparameter`` two different times. The syntax is ``setparameter(model_name, :component_name, :parameter_name, value)``
* If any variables of one component are parameters for another, ``connectparameter`` is used to couple the two components together. In this example, _YGROSS_ is a variable in the ``grosseconomy`` component and a parameter in the ``emissions`` component. The syntax is ``connectparameter(model_name, :component_name_current, :parameter_name, :component_name_variable)``, where ``:component_name_variable`` refers to the component where your parameter was initially calculated as a variable.
* Finally, the model can be run using the command ``run(model_name)``.
* To access model results, use ``model_name[:component, :variable_name]``.

```julia
my_model = Model()

setindex(my_model, :time, [2015:5:2110])

addcomponent(my_model, grosseconomy)  #Order matters here. If the emissions component were defined first, the model would not run.
addcomponent(my_model, emissions)

#Set parameters for the grosseconomy component
setparameter(my_model, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
setparameter(my_model, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
setparameter(my_model, :grosseconomy, :s, ones(20).* 0.22)
setparameter(my_model, :grosseconomy, :depk, 0.1)
setparameter(my_model, :grosseconomy, :k0, 130.)
setparameter(my_model, :grosseconomy, :share, 0.3)

#Set parameters for the emissions component
setparameter(my_model, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)  #Note that connectparameter was used here.

run(my_model)

#Check model results
my_model[:emissions, :E]
```

###Constructing A Multi-Region Model

We can now modify our two-component model of the globe to include multiple regional economies.  Global greenhouse gas emissions will now be the sum of regional emissions. The modeling approach is the same, with a few minor adjustments:

* When using ``@defcomp``, a regions index must be specified. In addition, for variables that have a regional index it is necessary to include ``(index=[regions])``. This can be combined with the time index as well, ``(index=[time, regions])``.
* In the timestep function, a region dimension must be defined using ``state.Dimensions``.  Unlike the time dimension, regions must be specified and looped through in any equations that contain a regional variable or parameter.
* ``setindex`` must be used to specify your regions in the same way that it is used to specify your timestep.
* When using ``setparameter`` for values with a time and regional dimension, an array is used.  Each row corresponds to a time step, while each column corresponds to a separate region. For regional values with no timestep, a vector can be used. It is often easier to create an array of parameter values before model construction. This way, the parameter name can be entered into ``setparameter`` rather than an entire equation.
* When constructing regionalized models with multiple components, it is often easier to save each component as a separate file and to then write a function that constructs the model.  When this is done, ``using Mimi`` must be speficied for each component. This approach will be used here.

To create a three-regional model, we will again start by constructing the grosseconomy and emissions components, making adjustments for the regional index as needed.  Each component should be saved as a separate file.

```julia
using Mimi

@defcomp grosseconomy begin
	regions = Index()							#Note that a regional index is defined here

	YGROSS	= Variable(index=[time, regions])	#Gross output
	K 		= Variable(index=[time, regions])	#Capital
	l 		= Parameter(index=[time, regions])	#Labor
	tfp 	= Parameter(index=[time, regions]) 	#Total factor productivity
	s 		= Parameter(index=[time, regions])	#Savings rate
	depk	= Parameter(index=[regions]) 		#Depreciation rate on capital - Note that it only has a region index
	k0		= Parameter(index=[regions])		#Initial level of capital
	share	= Parameter() 						#Capital share
end


function timestep(state::grosseconomy, t::Int)
	v = state.Variables
	p = state.Parameters
	d = state.Dimensions 						#Note that the regional dimension is defined here and parameters and variables are indexed by 'r'

	#Define an equation for K
	for r in d.regions
		if t == 1
			v.K[t,r] = p.k0[r]
		else
			v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5
		end
	end

	#Define an equation for YGROSS
	for r in d.regions
		v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)
	end
end
```

Save this component as _**gross_economy.jl**_

```julia
using Mimi											#Make sure to call Mimi again

@defcomp emissions begin
	regions 	= Index()							#The regions index must be specified for each component

	E 			= Variable(index=[time, regions])	#Total greenhouse gas emissions
	E_Global	= Variable(index=[time])			#Global emissions (sum of regional emissions)
	sigma		= Parameter(index=[time, regions])	#Emissions output ratio
	YGROSS		= Parameter(index=[time, regions])	#Gross output - Note that YGROSS is now a parameter
end


function timestep(state::emissions, t::Int)
	v = state.Variables
	p = state.Parameters
	d = state.Dimensions

	#Define an eqation for E
	for r in d.regions
		v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]
	end

	#Define an equation for E_Global
	for r in d.regions
		v.E_Global[t] = sum(v.E[t,:])
	end
end
```

Save this component as _**emissions.jl**_

Let's create a file with all of our parameters that we can call into our model.  This will help keep things organized as the number of components and regions increases. Each column refers to parameter values for a region, reflecting differences in initial parameter values and growth rates between the three regions.

```julia
l = Array(Float64,20,3)
for t in 1:20
	l[t,1] = (1. + 0.015)^t *2000
	l[t,2] = (1. + 0.02)^t * 1250
	l[t,3] = (1. + 0.03)^t * 1700
end

tfp = Array(Float64,20,3)
for t in 1:20
	tfp[t,1] = (1 + 0.06)^t * 3.2
	tfp[t,2] = (1 + 0.03)^t * 1.8
	tfp[t,3] = (1 + 0.05)^t * 2.5
end

s = Array(Float64,20,3)
for t in 1:20
	s[t,1] = 0.21
	s[t,2] = 0.15
	s[t,3] = 0.28
end

depk = [0.11, 0.135 ,0.15]
k0 	 = [50.5, 22., 33.5]

sigma = Array(Float64,20,3)
for t in 1:20
	sigma[t,1] = (1. - 0.05)^t * 0.58
	sigma[t,2] = (1. - 0.04)^t * 0.5
	sigma[t,3] = (1. - 0.045)^t * 0.6
end
```
Save this file as _**region_parameters.jl**_

The final step is to create a function that will run our model.

```julia
include("gross_economy.jl")
include("emissions.jl")

function run_my_model()

	my_model = Model()

	setindex(my_model, :time, [2015:5:2110])
	setindex(my_model, :regions, ["Region1", "Region2", "Region3"])	 #Note that the regions of your model must be specified here

	addcomponent(my_model, grosseconomy)
	addcomponent(my_model, emissions)

	setparameter(my_model, :grosseconomy, :l, l)
	setparameter(my_model, :grosseconomy, :tfp, tfp)
	setparameter(my_model, :grosseconomy, :s, s)
	setparameter(my_model, :grosseconomy, :depk,depk)
	setparameter(my_model, :grosseconomy, :k0, k0)
	setparameter(my_model, :grosseconomy, :share, 0.3)

	#set parameters for emissions component
	setparameter(my_model, :emissions, :sigma, sigma)
	connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)

	run(my_model)
	return(my_model)

end
```
We can now call in our parameter file, use ``run_my_model`` to construct our model, and evaluate the results.

```julia
using Mimi
include("region_parameters.jl")

run1 = run_my_model()

#Check results
run1[:emissions, :E_Global]
```
