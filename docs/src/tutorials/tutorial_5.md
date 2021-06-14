# Tutorial 5: Monte Carlo Simulations and Sensitivity Analysis Support

This tutorial walks through the Monte Carlo simulation and sensitivity analysis (SA) functionality of Mimi, including core routines and examples.  We will start with looking at using the Monte Carlo and SA routines with the multi-region Mimi model built in the second half of Tutorial 3, which is also available in the Mimi repository at `examples/tutorial/02-multi-region-model`. Then we will show some more advanced features using a real Integrated Assessment model, [MimiDICE2010](https://github.com/anthofflab/MimiDICE2010.jl).

**For a more complete understanding of the Monte Carlo and SA Support, we recommend following up by reading How-to Guide 3: Conduct Monte Carlo Simulations and Sensitivity Analysis.**

Working through the following tutorial will require:

- [Julia v1.4.0](https://julialang.org/downloads/) or higher
- [Mimi v0.10.0](https://github.com/mimiframework/Mimi.jl) or higher

**If you have not yet prepared these, go back to the first tutorial to set up your system.**

MimiDICE2010 is required for the second example in this tutorial. If you are not yet comfortable with downloading and running a registered Mimi model, refer to Tutorial 2 for instructions.

## The API

The best current documentation on the SA API is the how to guide How-to Guide 3: Conduct Sensitivity Analysis. This file can be used in conjunction with the examples below for details since the documentation covers more advanced options such as non-stochastic scenarios and running multiple models, which are not yet included in this tutorial.

Below we will refer separately to two types, `SimulationDef` and `SimulationInstance`.  They are referred to as `sim_def` and `sim_inst` respectively as function arguments, and `sd` and `si` respectively as local variables.

## Multi-Region Model Example

This section will walk through a simple example of how to define a simulation, run the simulation for a given model, and access the outputs.

#### Step 1. Setup
You should have `Mimi` installed by now, and if you do not have the `Distributions` package, take a moment to add that package by entering `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode and then typing `add Distributions`.

As a reminder, the following code is the multi-region model that was constructed in the second half of tutorial 3. You can either load the `MyModel` module from tutorial 3, or run the following code which defines the same `construct_Mymodel` function that we will use.

```jldoctest tutorial5; output = false
using Mimi 

# Define the grosseconomy component
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

# define the emissions component
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

# Define values for input parameters to be used when constructing the model

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

# Define a function for building the model

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

Then, we obtain a copy of the model:

```jldoctest tutorial5; output = false
m = construct_MyModel()

# output

Mimi.Model    
  Module: Mimi
  Components:
    ComponentId(grosseconomy)
    ComponentId(emissions)
  Built: false
```

#### Step 2. Define the Simulation

The [`@defsim`](@ref) macro is the first step in the process, and returns a `SimulationDef`. The following syntax allows users to define random variables (RVs) as distributions,  and associate model parameters with the defined random variables.

There are two ways of assigning random variables to model parameters in the [`@defsim`](@ref) macro. Notice that both of the following syntaxes are used in the following example. 
 
The first is the following:
```julia
rv(rv1) = Normal(0, 0.8)    # create a random variable called "rv1" with the specified distribution
param1 = rv1                # then assign this random variable "rv1" to the shared model parameter "param1" in the model
comp1.param2 = rv1          # then assign this random variable "rv1" to the unshared model parameter "param2" in component `comp1`
```

The second is a shortcut, in which you can directly assign the distribution on the right-hand side to the name of the model parameter on the left hand side. With this syntax, a single random variable is created under the hood and then assigned to our shared model parameter `param1` and unshared model parameter `param2`.
```julia
param1 = Normal(0, 0.8)
comp1.param2 = Normal(1,0)
```

Note here that if we have a shared model parameter we can assign based on its name, but if we have an unshared model parameter specific to one component/parameter pair we need to specify both.  If the component is not specified Mimi will throw a warning and try to resolve under the hood with assumptions, proceeding if possible and erroring if not.

**It is important to note** that for each trial, a random variable on the right hand side of an assignment, be it using an explicitly defined random variable with `rv(rv1)` syntax or using shortcut syntax as above, will take on the value of a **single** draw from the given distribution.  This means that even if the random variable is applied to more than one parameter on the left hand side (such as assigning to a slice), each of these parameters will be assigned the same value, not different draws from the distribution

The [`@defsim`](@ref) macro also selects the sampling method. Simple random sampling (also called Monte Carlo sampling) is the default. Other options include Latin Hypercube sampling and Sobol sampling. Below we show just one example of a [`@defsim`](@ref) call, but the How-to guide referenced at the beginning of this tutorial gives a more comprehensive overview of the options.

```jldoctest tutorial5; output = false, filter = r".*"s
using Mimi
using Distributions 

sd = @defsim begin

    # Define random variables. The rv() is only required when defining correlations 
    # or sharing an RV across parameters. Otherwise, you can use the shortcut syntax
    # to assign a distribution to a parameter name.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # Define the sampling strategy, and if you are using LHS, you can define 
    # correlations like this:
    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])

    # assign RVs to model Parameters
    grosseconomy.share = Uniform(0.2, 0.8)

    # you can use the *= operator to replace the values in the parameter with the 
    # product of the original value and the value of the RV for the current 
    # trial (note that in both lines below, all indexed values will be mulitplied by the
    # same draw from the given random parameter (name2 or Uniform(0.8, 1.2))
    emissions.sigma[:, Region1] *= name2
    emissions.sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    # For parameters that have a region dimension, you can assign an array of distributions, 
    # keyed by region label, which must match the region labels in the model
    grosseconomy.depk = [Region1 => Uniform(0.7, .9),
            Region2 => Uniform(0.8, 1.),
            Region3 => Truncated(Normal(), 0, 1)]

    # Indicate which variables to save for each model run.
    # The syntax is: component_name.variable_name
    save(grosseconomy.K, grosseconomy.YGROSS, 
         emissions.E, emissions.E_Global)
end

# output

```

#### Step 3. Run Simulation

Next, use the [`run`](@ref) function to run the simulation for the specified simulation definition, model (or list of models), and number of trials. View the internals documentation [here](https://github.com/mimiframework/Mimi.jl/blob/master/docs/src/internals/montecarlo.md) for **critical and useful details on the full signature of the [`run`](@ref) function**.

In its simplest use, the [`run`](@ref) function generates and iterates over a sample of trial data from the distributions of the random variables defined in the `SimulationDef`, perturbing the subset of Mimi's model parameters that have been assigned random variables, and then runs the given Mimi model(s) for each set of trial data. The function returns a `SimulationInstance`, which holds a copy of the original `SimulationDef` in addition to trials information (`trials`, `current_trial`, and `current_data`), the model list `models`, and results information in `results`. Optionally, trial values and/or model results are saved to CSV files. Note that if there is concern about in-memory storage space for the results, use the `results_in_memory` flag set to `false` to incrementally clear the results from memory. 

```jldoctest tutorial5; output = false, filter = r".*"s
# Run 100 trials, and optionally save results to the indicated directories
si = run(sd, m, 100; trials_output_filename = "/tmp/trialdata.csv", results_output_dir="/tmp/tutorial4")

# Explore the results saved in-memory by using getdataframe with the returned SimulationInstance.
# Values are saved from each trial for each variable or parameter specified by the call to "save()" at the end of the @defsim block.
K_results = getdataframe(si, :grosseconomy, :K)
E_results = getdataframe(si, :emissions, :E)

# output

```
#### Step 4. Explore and Plot Results

As described in the internals documentation [here](https://github.com/mimiframework/Mimi.jl/blob/master/docs/src/internals/montecarlo.md), Mimi provides both [`explore`](@ref) and `Mimi.plot` to explore the results of both a run `Model` and a run `SimulationInstance`. 

To view your results in an interactive application viewer, simply call:

```julia
explore(si)
```

If desired, you may also include a `title` for your application window. If more than one model was run in your Simulation, indicate which model you would like to explore with the `model` keyword argument, which defaults to 1. Finally, if your model leverages different scenarios, you **must** indicate the `scenario_name`.

```julia
explore(si; title = "MyWindow", model_index = 1) # we do not indicate scen_name here since we have no scenarios
```

To view the results for one of the saved variables from the `save` command in `@defsim`, use the (unexported to avoid namespace collisions) `Mimi.plot` function.  This function has the same keyword arguments and requirements as [`explore`](@ref) (except for `title`), and three required arguments: the `SimulationInstance`, the component name (as a `Symbol`), and the variable name (as a `Symbol`).

```julia
Mimi.plot(si, :grosseconomy, :K)
```
To save your figure, use the `save` function to save typical file formats such as [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics), [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), [PDF](https://en.wikipedia.org/wiki/PDF) and [EPS](https://en.wikipedia.org/wiki/Encapsulated_PostScript) files. Note that while `explore(sim_inst)` returns interactive plots for several graphs, `Mimi.plot(si, :foo, :bar)` will return only static plots. 

```julia
p = Mimi.plot(si, :grosseconomy, :K)
save("MyFigure.png", p)
```

## Advanced Features - Social Cost of Carbon (SCC) Example

This example will discuss the more advanced SA capabilities of post-trial functions and payload objects.

Case: We want to do an SCC calculation with `MimiDICE2010`, which consists of running both a `base` and `modified` model (the latter being a model including an additional emissions pulse, see the [`create_marginal_model`](@ref) function or create your own two models). We then take the difference between the consumption level in these two models and obtain the discounted net present value to get the SCC.

The beginning steps for this case are identical to those above. We first define the typical variables for a simulation, including the number of trials `N` and the simulation definition `sd`.  In this case we only define one random variable, `t2xco2`, but note there could be any number of random variables defined here.

```jldoctest tutorial5; output = false, filter = r".*"s
using Mimi
using MimiDICE2010
using Distributions

# define the number of trials
N = 100

# define your simulation (defaults to Monte Carlo sampling)
sd = @defsim begin
    t2xco2 = Truncated(Gamma(6.47815626,0.547629469), 1.0, Inf) # a dummy distribution
end

# output

```

#### Payload object
Simulation definitions can hold a user-defined payload object which is not used or modified by Mimi. In this example, we will use the payload to hold an array of pre-computed discount factors that we will use in the SCC calculation, as well as a storage array for saving the SCC values.

```jldoctest tutorial5; output = false, filter = r".*"s
# Choose what year to calculate the SCC for
scc_year = 2015
year_idx = findfirst(isequal(scc_year), MimiDICE2010.model_years)

# Pre-compute the discount factors for each discount rate
discount_rates = [0.03, 0.05, 0.07]
nyears = length(MimiDICE2010.model_years)
discount_factors = [[zeros(year_idx - 1)... [(1/(1 + r))^((t-year_idx)*10) for t in year_idx:nyears]...] for r in discount_rates] 

# Create an array to store the computed SCC in each trial for each discount rate
scc_results = zeros(N, length(discount_rates))  

# Set the payload object in the simulation definition
my_payload_object = (discount_factors, scc_results) # In this case, the payload object is a tuple which holds both both arrays
Mimi.set_payload!(sd, my_payload_object)  

# output

```

#### Post-trial function

In the simple multi-region simulation example, the only values that were saved during each trial of the simulation were values of variables calculated internally by the model. Sometimes, a user may need to perform other calculations before or after each trial is run. For example, the SCC is calculated using two models, so this calculation needs to happen in a post-trial function, as shown below.

Here we define a `post_trial_function` called `my_scc_calculation` which will calculate the SCC for each trial of the simulation. Notice that this function retrieves and uses the payload object that was previously stored in the `SimulationDef`.

```jldoctest tutorial5; output = false
function my_scc_calculation(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Nothing)
    mm = sim_inst.models[1] 
    discount_factors, scc_results = Mimi.payload(sim_inst)  # Unpack the payload object

    marginal_damages = mm[:neteconomy, :C] * -1 * 10^12 * 12/44 # convert from trillion $/ton C to $/ton CO2; multiply by -1 to get positive value for damages
    for (i, df) in enumerate(discount_factors)
        scc_results[trialnum, i] = sum(df .* marginal_damages .* 10)
    end
end

# output

my_scc_calculation (generic function with 1 method)
```

#### Run the simulation

Now that we have our post-trial function, we can proceed to obtain our two models and run the simulation. Note that we are using a Mimi MarginalModel `mm` from MimiDICE2010, which is a Mimi object that holds both the base model and the model with the additional pulse of emissions.

```julia
# Build the marginal model
mm = MimiDICE2010.get_marginal_model(year = scc_year)   # The additional emissions pulse will be added in the specified year

# Run
si = run(sd, mm, N; trials_output_filename = "ecs_sample.csv", post_trial_func = my_scc_calculation)

# View the scc_results by retrieving them from the payload object
scc_results = Mimi.payload(si)[2]   # Recall that the SCC array was the second of two arrays we stored in the payload tuple

```

#### Other Helpful Functions

A small set of unexported functions are available to modify an existing `SimulationDef`.  Please refer to How-to Guide 3: Conduct Monte Carlo Simulations and Sensitivity Analysis for an in depth description of their use cases.  The functions include the following:

* `delete_RV!`
* `add_RV!`
* `replace_RV!`
* `delete_transform!`
* `add_transform!`
* `delete_save!`
* `add_save!`
* `get_simdef_rvnames`
* `set_payload!`
* `payload`

#### Full list of keyword options for running a simulation

View How-to Guide 3: Conduct Monte Carlo Simulations and Sensitivity Analysis for **critical and useful details on the full signature of this function**, as well as more details and optionality for more advanced use cases.

```julia
function Base.run(sim_def::SimulationDef{T}, models::Union{Vector{Model}, Model}, samplesize::Int;
                 ntimesteps::Int=typemax(Int), 
                 trials_output_filename::Union{Nothing, AbstractString}=nothing, 
                 results_output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing,
                 results_in_memory::Bool=true) where T <: AbstractSimulationData
```
