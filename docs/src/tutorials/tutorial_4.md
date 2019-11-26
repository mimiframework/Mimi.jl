# Tutorial 4: Sensitivity Analysis (SA) Support

This tutorial walks through the sensitivity analysis (SA) functionality of Mimi, including core routines and examples.  We will start with looking at using the SA routines with the Mimi two-region model provided in the Mimi repository at `examples/tutorial/02-two-region-model`, and then build out to examine its use on [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund), 

Working through the following tutorial will require:

- [Julia v1.2.0](https://julialang.org/downloads/) or higher
- [Mimi v0.9.0](https://github.com/mimiframework/Mimi.jl) 

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

Futhermore, if you are not yet comfortable with downloading (only needs to be done once) and running FUND, refer to Tutorial 1 for instructions.  Carry out **Steps 1 and 2** from Tutorial 1, and then return to continue with this tutorial. Note that FUND is only requred for the second example in this tutorial. 

## The API

The best current documentation on the SA API is the internals documentation [here](https://github.com/anthofflab/Mimi.jl/blob/master/docs/src/internals/montecarlo.md), which provides a working and informal description of the Sensitivity Analysis support of Mimi. This file should be used in conjunction with the examples below for details, since the documentation covers more advanced options such as non-stochastic scenarios and running multiple models, which are not yet included in this tutorial.

These are described further below. We will refer separately to two types, `SimulationDef` and `SimulationInstance`.  They are referred to as `sim_def` and `sim_inst` respectively as function arguments, and `sd` and `si` respectively as local variables.

## Two-Region Model Example

This section will walk through the simple example provided in `"Mimi.jl/test/sim/test_defsim.jl"`.

### Step 1. Setup
First, set up for the tutorial as follows with the necessary packages and `main.jl` script for the two-region example.  You should have `Mimi` installed by now, and if you do not have `Distributions`, take a moment to add that package using by entering `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode and then typing `add Distributions`.

```julia
cd(<Mimi-directory-path>) # Mimi-directory-path is a placeholder for the string describing the path of the Mimi directory
using Distributions

include("examples/tutorial/02-two-region-model/main.jl")
m = model # defined by 2-region model
```

### Step 2. Define Random Variables
The `@defsim` macro, which defines random variables (RVs) which are assigned distributions and associated with model parameters, is the first step in the process. It also selects the sampling method, with
simple random sampling being the default. Other options include Latin Hypercube Sampling, and Sobol
Sampling.

```julia
sd = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # If using LHS, you can define correlations like this:
    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])

    # Exclude the sampling() call, or use the following for simple random sampling:
    # sampling(MCSData)

    # For Sobol sampling, specify N, and calc_second_order, which defaults to false.
    # sampling(SobolData, N=100000, calc_second_order=true)

    # assign RVs to model Parameters
    share = Uniform(0.2, 0.8)
    sigma[:, Region1] *= name2
    sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    # Assign an array of distributions, keyed by region, to parameter depk
    depk = [Region1 => Uniform(0.7, 1.3),
            Region2 => Uniform(0.8, 1.2),
            Region3 => Normal()]

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, 
         emissions.E, emissions.E_Global)
end
```

### Step 3. Optional User-Defined Functions
Next, create the user-defined `print_result` function, which can be called as a post-trial function by `run`.

 ```julia
# Optional user functions can be called just before or after a trial is run
function print_result(m::Model, sim_inst::SimulationInstance, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end
```

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the SA loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

### Step 4. Run Simulation

 Finally, use `run` which runs a simulation, indicating the `sim_def`, the `models` is a model, marginal model, or list of models to be run by your `sim_def` simulation, and `samplesize` the number of samples to use.
 
  In it's simplest use, the `run` function generates and iterates over generated trial data, perturbing a chosen subset of Mimi's "external parameters", based on the defined distributions, and then runs the given Mimi model(s). The function retuns an instance of `SimulationInstance`, holding a copy of the original `SimulationDef` in addition to trials information (`trials`, `current_trial`, and `current_data`), the model list`models`, and results information in `results`. Optionally, trial values and/or model results are saved to CSV files. Optionally, trial values and/or model results are saved to CSV files.  Note that if there is concern about in-memory storage space for the results, use the `results_in_memory` flag set to `false` to incrementally clear the results from memory. View the internals documentation for **critical and useful details on the full signature of this function**:

```
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

Here, we first employ `run` to obtain results:

```julia

# Run 100 trials and save results to the indicated directories, one CSV file per RV for the results
si = run(sd, m, 100; trials_output_filename = "/tmp/trialdata.csv", results_output_dir="/tmp/Mimi")

# Explore the results saved in-memory
results = getdataframe(si, :grosseconomy, :K) # model index chosen defaults to 1
```

and then again using our user-defined post-trial function as the `post_trial_func` parameter:

```julia
# Same thing but with a post-trial function
si = run(sd, m, 100; trials_output_filename = "/tmp/trialdata.csv", results_output_dir="/tmp/Mimi", post_trial_func=print_result)

# Explore the results saved in-memory
results = getdataframe(si, :grosseconomy, :K) # model index chosen defaults to 1
```

### Step 5. Explore and Plot Results

As described in the internals documentation [here](https://github.com/mimiframework/Mimi.jl/blob/master/docs/src/internals/montecarlo.md), Mimi provides both `explore` and `Mimi.plot` to explore the results of both a run `Model` and a run `SimulationInstance`. 

To view your results in an interactive application viewer, simply call:

```julia
explore(si)
```

If desired, you may also include a `title` for your application window. If more than one model was run in your Simulation, indicate which model you would like to explore with the `model` keyword argument, which defaults to 1. Finally, if your model leverages different scenarios, you **must** indicate the `scenario_name`.

```julia
explore(si; title = "MyWindow", model = 1) # we do not indicate scen_name here since we have no scenarios
```

To view the results for one of the saved variables from the `save` command in `@defsim`, use the (unexported to avoid namespace collisions)`Mimi.plot` function.  This function has the same keyword arguments and requirements as `explore`, save for `title`, and three required arguments: the `SimulationInstance`, the component name (as a `Symbol`), and the variable name (as a `Symbol`).

```julia
using VegaLite
Mimi.plot(si, :grosseconomy, :K)
```
To save your figure, use the `save` function to save typical file formats such as [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics), [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), [PDF](https://en.wikipedia.org/wiki/PDF) and [EPS](https://en.wikipedia.org/wiki/Encapsulated_PostScript) files. Note that while `explore(sim_inst)` returns interactive plots for several graphs, `Mimi.plot(si, :foo, :bar)` will return only static plots. 

```julia
p = Mimi.plot(si, :grosseconomy, :K)
save("MyFigure.png", p)
```

## Advanced Post-trial Functions

While the model above employed a fairly simple `post_trial_func` that printed out results, the post-trial functions can be used for more complex calculations that need to be made for each simulation run.  This can be especially usefu, for example,for calculating net present value of damages or the social cost of carbon (SCC) for each run.

### NPV of Damages

Case: We want to run MimiDICE2010, varying the climate sensitivity `t2xco2` over a distribution `MyDistribution`, and for each run return the sum of discounted climate damages `DAMAGES` using three different discount rates.

Without using the Mimi functionality, this may look something like:

```julia
# N = number of trials
# m = DICE2010 model
# df = array of discount factors
# npv_damages= an empty array to store my results
# ECS_sample = a vector of climate sensitivity values drawn from the desired distribution

for i = 1:N
    update_param!(m, :t2xco2, ECS_sample[i])
    run(m)
    npv_damages[i] = sum(df .* m[:neteconomy, :DAMAGES])
end
```

We encourage users to employ the Mimi framework for this type of analysis, in large part because the underlying functions have optimizations that will improve speed and memory use, especially as the number of runs climbs.

Employing the sensitivity analysis functionality could look like the following template:

First, we define the typical variables for a simulation, including the number of trials `N` and the simulation definition `sim_def`.  In this case we only define one random variable, `t2xco2`, but note there could be any number of random variables defined here.

```julia
using Mimi
using MimiDICE2010

# define your trial number
N = 1000000 

# define your simulation(defaults to Monte Carlo sampling)
sd = @defsim begin
    t2xco2 = MyDistribution()
end
```

Next, we consider the requirements for our post-trial function.  We will need to define the array of discount rates `discount_rates`, and a function that converts `discount_rates` into the necessary array of discount factors `df`, as follows.

```julia   
# define your desired discount rates and pre compute the discount factors
discount_rates = [0.025, 0.03, 0.05]
dfs = [calculate_df(rate) for rate in discount_rates]    # need to define or replace calculate_df
```

Next, we must create an array to store the npv damages results to during the post-trial funciton
```julia
# make an array to store the npv damages results to during the post trial function
npv_results = zeros(N, length(discount_rates))    
```

We are now ready to define a post-trial function, which has a required type signature `MyFunction(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)` although not all arguments have to be used within the function. Our function will access our model from the list of models in `mcs_inst.models` (length of one in this case) and then perform calculations on the `DAMAGES` variable from the `neteconomy` component in that model as follows.

```julia
# define your post trial function; this is the required type signature, even though we won't use all of the arguments
function my_npv_calculation(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)
    m = sim_inst.models[1]    # access the model after it is run for this trial
    damages = m[:neteconomy, :DAMAGES]    # access the damage values for this run
    for (i, df) in enumerate(dfs)    # loop through our precomputed discount factors
        npv_results[trialnum, i] = sum(df .* damages)    # do the npv calculation and save it to our array of results
    end
    nothing    # return nothing
end
```
Now that we have defined  our post-trial function, we can set our models and run the simulation! Afterwards, we can use the `npv_results` array as we need.

```julia  
si = run(sd, m, N; post_trial_func = my_npv_calculation, trials_output_filename = "ECS_sample.csv")# providing a file name is optional; only use if you want to see the climate sensitivity values later

# do something with the npv_results array
println(mean(npv_results, dims=2))    # or write to a file
```

### Social Cost of Carbon (SCC)

Case: We want to do an SCC calculation across a base and marginal model of `MimiDICE2010`, which consists of running both a `base` and `marginal` model (the latter being a model including an emissions pulse, see the [`create_marginal_model`](@ref) or create your own two models). We then take the difference between the `DAMAGES` in these two models and obtain the NPV to get the SCC.

The beginning steps for this case are identical to those above. We first define the typical variables for a simulation, including the number of trials `N` and the simulation definition `sim_def`.  In this case we only define one random variable, `t2xco2`, but note there could be any number of random variables defined here.

```julia
using Mimi
using MimiDICE2010

# define your trial number
N = 1000000 

# define your simulation (defaults to Monte Carlo sampling)
sd = @defsim begin
    t2xco2 = MyDistribution()
end
```

Next, we prepare our post-trial calculations by setting up a `scc_results` array to hold the results.  We then define a `post_trial_function` called `my_scc_calculation` which will calculate the SCC for that run.

```julia
scc_results = zeros(N, length(discount_rates))

function my_scc_calculation(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)
    base, marginal = sim_inst.models
    base_damages = base[:neteconomy, :DAMAGES]
    marg_damages = marginal[:neteconomy, :DAMAGES]
    for (i, df) in enumerate(dfs)
        scc_results[trialnum, i] = sum(df .* (marg_damages .- base_damages))
    end
end
```

Now that we have our post-trial function, we can proceed to obtain our two models and run the simulation.

```julia
# Build the base model
base = construct_dice()

#Build the marginal model, which here involves a dummy function `construct_marginal_dice()` that you will need to write
marginal = construct_marginal_dice(year) 

# Run
si = run(sd, [base, marginal], N; trials_output_filename = "ecs_sample.csv", post_trial_func = my_scc_calculation)
```
## Simulation Modification Functions
A small set of unexported functions are available to modify an existing `SimulationDefinition`.  The functions include:
* `delete_RV!`
* `add_RV!`
* `replace_RV!`
* `delete_transform!`
* `add_transform!`
* `delete_save!`
* `add_save!`
* `set_payload!`
* `payload`
