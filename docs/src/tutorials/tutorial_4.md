# Tutorial 4: Create a Model

This tutorial walks through the steps to create a new model, first a one-region model and then a more complex multi-region model. 

While we will walk through the code step by step below, the full code for implementation is also available in the `examples/tutorial` folder in the [Mimi](https://github.com/mimiframework/Mimi.jl) github repository.

Working through the following tutorial will require:

- [Julia v1.4.0](https://julialang.org/downloads/) or higher
- [Mimi v0.10.0](https://github.com/mimiframework/Mimi.jl) or higher

**If you have not yet prepared these, go back to the first tutorial to set up your system.**

## Constructing A One-Region Model

In this example, we construct a stylized model of the global economy and its changing greenhouse gas emission levels through time. The overall strategy involves creating components for the economy and emissions separately, and then defining a model where the two components are coupled together.

There are two main steps to creating a component, both within the  [`@defcomp`](@ref) macro which defines a component:

* List the parameters and variables.
* Use the `run_timestep` function `run_timestep(p, v, d, t)` to set the equations of that component.

Starting with the economy component, each variable and parameter is listed. If either variables or parameters have a time-dimension, that must be set with `(index=[time])`.

Next, the `run_timestep` function must be defined along with the various equations of the `grosseconomy` component. In this step, the variables and parameters are linked to this component and must be identified as either a variable or a parameter in each equation. For this example, `v` will refer to variables while `p` refers to parameters.

It is important to note that `t` below is an `AbstractTimestep`, and the specific API for using this argument are described in detail in the how to guide How-to Guide 4: Work with Timesteps.

```jldoctest tutorial4; output = false
using Mimi # start by importing the Mimi package to your space

@defcomp grosseconomy begin
	YGROSS	= Variable(index=[time])	# Gross output
	K	= Variable(index=[time])	# Capital
	l	= Parameter(index=[time])	# Labor
	tfp	= Parameter(index=[time])	# Total factor productivity
	s	= Parameter(index=[time])	# Savings rate
	depk	= Parameter()			# Depreciation rate on capital - Note that it has no time index
	k0	= Parameter()			# Initial level of capital
	share	= Parameter()			# Capital share

	function run_timestep(p, v, d, t)
		# Define an equation for K
		if is_first(t)
			# Note the use of v. and p. to distinguish between variables and 
			# parameters
			v.K[t] 	= p.k0	
		else
			v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
		end

		# Define an equation for YGROSS
		v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
	end
end

# output

```

Next, the component for greenhouse gas emissions must be created.  Although the steps are the same as for the `grosseconomy` component, there is one minor difference. While `YGROSS` was a variable in the `grosseconomy` component, it now enters the `emissions` component as a parameter. This will be true for any variable that becomes a parameter for another component in the model.

```jldoctest tutorial4; output = false
@defcomp emissions begin
	E	= Variable(index=[time])	# Total greenhouse gas emissions
	sigma	= Parameter(index=[time])	# Emissions output ratio
	YGROSS	= Parameter(index=[time])	# Gross output - Note that YGROSS is now a parameter

	function run_timestep(p, v, d, t)

	# Define an equation for E
	v.E[t] = p.YGROSS[t] * p.sigma[t]	# Note the p. in front of YGROSS
	end
end

# output

```

We can now use Mimi to construct a model that binds the `grosseconomy` and `emissions` components together in order to solve for the emissions level of the global economy over time. In this example, we will run the model for twenty periods with a timestep of five years between each period.

* Once the model is defined, [`set_dimension!`](@ref) is used to set the length and interval of the time step.
* We then use [`add_comp!`](@ref) to incorporate each component that we previously created into the model.  It is important to note that the order in which the components are listed here matters.  The model will run through each equation of the first component before moving onto the second component. One can also use the optional `first` and `last` keyword arguments to indicate a subset of the model's time dimension when the component should start and end.
* Next, [`update_param!`](@ref) is used to assign values each component parameter with an external connection to an unshared model parameter. If _population_ was a parameter for two different components, it must be assigned to each one using [`update_param!`](@ref) two different times. The syntax is `update_param!(model_name, :component_name, :parameter_name, value)`.  Alternatively if these parameters are always meant to use the same value, one could use [`add_shared_param!`](@ref) to create a shared model parameter and add it to the model, and then use [`connect_param!`](@ref) to connect both. This syntax would use `add_shared_param!(model_name, :model_param_name, value)` followed by `connect_param!(model_name, :component_name, :parameter_name, :model_param_name)` twice, once for each component.
* If any variables of one component are parameters for another, [`connect_param!`](@ref) is used to couple the two components together. In this example, _YGROSS_ is a variable in the `grosseconomy` component and a parameter in the `emissions` component. The syntax is `connect_param!(model_name, :component_name_parameter, :parameter_name, :component_name_variable, :variable_name)`, where `:component_name_variable` refers to the component where your parameter was initially calculated as a variable.
* Finally, the model can be run using the command `run(model_name)`.
* To access model results, use `model_name[:component, :variable_name]`.
* To observe model results in a graphical form , [`explore`](@ref) as either `explore(model_name)` to open the UI window, or use `Mimi.plot(model_name, :component_name, :variable_name)` or `Mimi.plot(model_name, :component_name, :parameter_name)` to plot a specific parameter or variable.

```jldoctest tutorial4; output = false

using Mimi

function construct_model()
	m = Model()

	set_dimension!(m, :time, collect(2015:5:2110))

	# Order matters here. If the emissions component were defined first, the model would not run.
	add_comp!(m, grosseconomy)  
	add_comp!(m, emissions)

	# Update parameters for the grosseconomy component
	update_param!(m, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
	update_param!(m, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
	update_param!(m, :grosseconomy, :s, ones(20).* 0.22)
	update_param!(m, :grosseconomy, :depk, 0.1)
	update_param!(m, :grosseconomy, :k0, 130.)
	update_param!(m, :grosseconomy, :share, 0.3)

	# Update parameters for the emissions component
	update_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
	
	# connect parameters for the emissions component
	connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)  

	return m

end #end function

# output

construct_model (generic function with 1 method)

```

Note that as an alternative to using many of the [`update_param!`](@ref) calls above, one may use the `default` keyword argument in [`@defcomp`](@ref) when first defining a `Variable` or `Parameter`, as shown in `examples/tutorial/01-one-region-model/one-region-model-defaults.jl`.

Now we can run the model and examine the results:

```jldoctest tutorial4; output = false, filter = r".*"s
# Run model
m = construct_model()
run(m)

# Check model results
getdataframe(m, :emissions, :E) # or m[:emissions, :E_Global] to return just the Array

# output

```
Finally we can visualize the results via plotting and explorer:
```julia
# Plot model results
Mimi.plot(m, :emissions, :E);

# Observe all model result graphs in UI
explore(m)
```

## Constructing A Multi-Region Model

We can now modify our two-component model of the globe to include multiple regional economies.  Global greenhouse gas emissions will now be the sum of regional emissions. The modeling approach is the same, with a few minor adjustments:

* When using [`@defcomp`](@ref), a regions index must be specified. In addition, for variables that have a regional index it is necessary to include `(index=[regions])`. This can be combined with the time index as well, `(index=[time, regions])`.
* In the `run_timestep` function, unlike the time dimension, regions must be specified and looped through in any equations that contain a regional variable or parameter.
* [`set_dimension!`](@ref) must be used to specify your regions in the same way that it is used to specify your timestep.
* When using [`update_param!`](@ref) for values with a time and regional dimension, an array is used.  Each row corresponds to a time step, while each column corresponds to a separate region. For regional values with no timestep, a vector can be used. It is often easier to create an array of parameter values before model construction. This way, the parameter name can be entered into [`update_param!`](@ref) rather than an entire equation.
* When constructing regionalized models with multiple components, it is often easier to save each component as a separate file and to then write a function that constructs the model.  When this is done, `using Mimi` must be speficied for each component. This approach will be used here.

To create a three-regional model, we will again start by constructing the grosseconomy and emissions components, making adjustments for the regional index as needed.  Each component should be saved as a separate file.

As this model is also more complex and spread across several files, we will also take this as a chance to introduce the custom of using [Modules](https://docs.julialang.org/en/v1/manual/modules/index.html) to package Mimi models, as shown below.

```jldoctest tutorial4; output = false
using Mimi

@defcomp grosseconomy begin
    regions = Index()                           #Note that a regional index is defined here

    YGROSS  = Variable(index=[time, regions])   #Gross output
    K       = Variable(index=[time, regions])   #Capital
    l       = Parameter(index=[time, regions])  #Labor
    tfp     = Parameter(index=[time, regions])  #Total factor productivity
    s       = Parameter(index=[time, regions])  #Savings rate
    depk    = Parameter(index=[regions])        #Depreciation rate on capital - Note that it only has a region index
    k0      = Parameter(index=[regions])        #Initial level of capital
    share   = Parameter()                       #Capital share

    function run_timestep(p, v, d, t)
    # Note that the regional dimension is defined in d and parameters and variables are indexed by 'r'

        # Define an equation for K
        for r in d.regions
            if is_first(t)
                v.K[t,r] = p.k0[r]
            else
                v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5
            end
        end

        # Define an equation for YGROSS
        for r in d.regions
            v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)
        end
    end
end

# output

```

Save this component as **`gross_economy.jl`**

```jldoctest tutorial4; output = false, filter = r".*"s
using Mimi	#Make sure to call Mimi again

@defcomp emissions begin
    regions     = Index()                           # The regions index must be specified for each component

    E           = Variable(index=[time, regions])   # Total greenhouse gas emissions
    E_Global    = Variable(index=[time])            # Global emissions (sum of regional emissions)
    sigma       = Parameter(index=[time, regions])  # Emissions output ratio
    YGROSS      = Parameter(index=[time, regions])  # Gross output - Note that YGROSS is now a parameter

    # function init(p, v, d)
    # end
    
    function run_timestep(p, v, d, t)
        # Define an equation for E
        for r in d.regions
            v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]
        end

        # Define an equation for E_Global
        for r in d.regions
            v.E_Global[t] = sum(v.E[t,:])
        end
    end

end

# output

```

Save this component as **`emissions.jl`**

Let's create a file with all of our parameters that we can call into our model.  This will help keep things organized as the number of components and regions increases. Each column refers to parameter values for a region, reflecting differences in initial parameter values and growth rates between the three regions.

```jldoctest tutorial4; output = false
l = Array{Float64}(undef, 20, 3)
for t in 1:20
    l[t,1] = (1. + 0.015)^t *2000
    l[t,2] = (1. + 0.02)^t * 1250
    l[t,3] = (1. + 0.03)^t * 1700
end

tfp = Array{Float64}(undef, 20, 3)
for t in 1:20
    tfp[t,1] = (1 + 0.06)^t * 3.2
    tfp[t,2] = (1 + 0.03)^t * 1.8
    tfp[t,3] = (1 + 0.05)^t * 2.5
end

s = Array{Float64}(undef, 20, 3)
for t in 1:20
    s[t,1] = 0.21
    s[t,2] = 0.15
    s[t,3] = 0.28
end

depk = [0.11, 0.135 ,0.15]
k0   = [50.5, 22., 33.5]

sigma = Array{Float64}(undef, 20, 3)
for t in 1:20
    sigma[t,1] = (1. - 0.05)^t * 0.58
    sigma[t,2] = (1. - 0.04)^t * 0.5
    sigma[t,3] = (1. - 0.045)^t * 0.6
end

# output

```
Save this file as **`region_parameters.jl`**

The final step is to create a module:

```julia
module MyModel

using Mimi

include("region_parameters.jl")
include("gross_economy.jl")
include("emissions.jl")

export construct_MyModel
```
```jldoctest tutorial4; output = false
function construct_MyModel()

	m = Model()

	set_dimension!(m, :time, collect(2015:5:2110))
	set_dimension!(m, :regions, [:Region1, :Region2, :Region3])	 # Note that the regions of your model must be specified here

	add_comp!(m, grosseconomy)
	add_comp!(m, emissions)

	update_param!(m, :grosseconomy, :l, l)
	update_param!(m, :grosseconomy, :tfp, tfp)
	update_param!(m, :grosseconomy, :s, s)
	update_param!(m, :grosseconomy, :depk,depk)
	update_param!(m, :grosseconomy, :k0, k0)
	update_param!(m, :grosseconomy, :share, 0.3)

	update_param!(m, :emissions, :sigma, sigma)
	connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    return m
end

# output

construct_MyModel (generic function with 1 method)

```
```julia
end #module
``` 

Save this file as **`MyModel.jl`**

We can now run the model and evaluate the results.

```julia
using Mimi

include("MyModel.jl")
using .MyModel
```
```jldoctest tutorial4; output = false, filter = r".*"s
m = construct_MyModel()
run(m)

# Check results
getdataframe(m, :emissions, :E_Global) # or m[:emissions, :E_Global] to return just the Array

# output

```
```julia
# Observe model result graphs
explore(m)
```

----
Next, feel free to move on to the next tutorial, which will go into depth on how to **run a sensitivity analysis** on a own model.
