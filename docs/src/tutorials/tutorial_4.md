# Tutorial 4: Sensitivity Analysis (SA) Support

This tutorial walks through the sensitivity analysis (SA) functionality of Mimi, including core routines and examples.  We will start with looking at using the SA routines with the Mimi two-region model provided in the Mimi repository at `examples/tutorial/02-two-region-model`, and then build out to examine its use on [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund), 

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/mimiframework/Mimi.jl) 

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

Futhermore, if you are not yet comfortable with downloading (only needs to be done once) and running FUND, refer to Tutorial 1 for instructions.  Carry out **Steps 1 and 2** from Tutorial 1, and then return to continue with this tutorial. Note that FUND is only requred for the second example in this tutorial. 

## The API

The best current documentation on the SA API is the internals documentation [here](https://github.com/anthofflab/Mimi.jl/blob/master/docs/src/internals/montecarlo.md), which provides a working and informal description of the Sensitivity Analysis support of Mimi. This file should be used in conjunction with the examples below for details, since the documentation covers more advanced options such as non-stochastic scenarios and running multiple models, which are not yet included in this tutorial.

## Two-Region Model Example

This section will walk through the simple example provided in `"Mimi.jl/test/sim/test_defsim.jl"`.

### Step 1. Setup
First, set up for the tutorial as follows with the necessary packages and `main.jl` script for the two-region example.  You should have `Mimi` installed by now, and if you do not have `Distributions`, take a moment to add that package using by entering `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode and then typing `add Distributions`.

```juila
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
sim = @defsim begin
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

### Step 2. Optional User-Defined Functions
Next, create the user-defined `print_result` function, which can be called as a post-trial function by [`run_sim`](@ref).

 ```julia
# Optional user functions can be called just before or after a trial is run
function print_result(m::Model, sim::Simulation, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end
```

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the SA loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

### Step 2. Generate Trials

The  [`generate_trials!`](@ref) function generates all trial data, and save all random variable values in a file. Employ this function as follows:

```julia
# Generate trial data for all RVs and (optionally) save to a file
generate_trials!(sim, 1000, filename="/tmp/trialdata.csv")
```

### Step 4. Run Simulation

Finally, use the [`set_models!`](@ref) and [`run_sim`](@ref) functions.  First, calling [`set_models!`] with a model, marginal model, or list of models will set those models as those to be run by your `sim` simulation.  Next, use [`run_sim`](@ref) which runs a simulation, with parameters describing the number of trials and optional callback functions to customize simulation behavior. In its simplest use, the [`run_sim`](@ref) function iterates over all pre-generated trial data, perturbing a chosen set of Mimi's "external parameters", based on the defined distributions, and then runs the given Mimi model. Optionally, trial values and/or model results are saved to CSV files.  View the internals documentation for **critical and useful details on the full signature of this function**:

```
function run_sim(sim::Simulation; 
                 trials::Union{Nothing, Int, Vector{Int}, AbstractRange{Int}} = nothing,
                 models_to_run::Int=length(sim.models),
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing)
```

Here, we first employ [`run_sim`](@ref) to obtain results:

```julia
# Set models
set_models!(sim, m)

# Run trials 1:4, and save results to the indicated directory, one CSV file per RV
run_sim(sim, 4, output_dir="/tmp/Mimi")
```

and then again using our user-defined post-trial function as the `post_trial_func` parameter:

```julia
# Same thing but with a post-trial function
run_sim(m, sim, 4, post_trial_func=print_result, output_dir="/tmp/Mimi")
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

First, we define the typical variables for a simulation, including the number of trials `N` and the simulation `sim`.  In this case we only define one random variable, `t2xco2`, but note there could be any number of random variables defined here.

```julia
using Mimi
using MimiDICE2010

# define your trial number
N = 1000000 

# define your simulation (defaults to Monte Carlo sampling)
mcs = @defsim begin
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

We are now ready to define a post-trial function, which has a required type signature `MyFunction((mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)` although not all arguments have to be used within the function. Our function will access our model from the list of models in `mcs.models` (length of one in this case) and then perform calculations on the `DAMAGES` variable from the `neteconomy` component in that model as follows.

```julia
# define your post trial function; this is the required type signature, even though we won't use all of the arguments
function my_npv_calculation(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
    m = mcs.models[1]    # access the model after it is run for this trial
    damages = m[:neteconomy, :DAMAGES]    # access the damage values for this run
    for (i, df) in enumerate(dfs)    # loop through our precomputed discount factors
        npv_results[trialnum, i] = sum(df .* damages)    # do the npv calculation and save it to our array of results
    end
    nothing    # return nothing
end
```
Now that we have defined  our post-trial function, we can set our models and run the simulation! Afterwards, we can use the `npv_results` array as we need.

```julia
# set the model, generate trials, and run the simulation
set_models!(mcs, m)
generate_trials!(mcs, N; filename = "ECS_sample.csv")   # providing a file name is optional; only use if you want to see the climate sensitivity values later
run_sim(mcs; post_trial_func = my_npv_calculation)

# do something with the npv_results array
println(mean(npv_results, dims=2))    # or write to a file
```

### Social Cost of Carbon (SCC)

Case: We want to do an SCC calculation across a base and marginal model of `MimiDICE2010`, which consists of running both a `base` and `marginal` model (the latter being a model including an emissions pulse, see the [`create_marginal_model`](@ref) or create your own two models). We then take the difference between the `DAMAGES` in these two models and obtain the NPV to get the SCC.

The beginning steps for this case are identical to those above. We first define the typical variables for a simulation, including the number of trials `N` and the simulation `sim`.  In this case we only define one random variable, `t2xco2`, but note there could be any number of random variables defined here.

```julia
using Mimi
using MimiDICE2010

# define your trial number
N = 1000000 

# define your simulation (defaults to Monte Carlo sampling)
mcs = @defsim begin
    t2xco2 = MyDistribution()
end
```

Next, we prepare our post-trial calculations by setting up a `scc_results` array to hold the results.  We then define a `post_trial_function` called `my_scc_calculation` which will calculate the SCC for that run.

```julia
scc_results = zeros(N, length(discount_rates))

function my_scc_calculation(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
    base, marginal = mcs.models
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

# Set models and run
set_models!(mcs, [base, marginal])
generate_trials!(mcs, N; filename = "ecs_sample.csv")
run_sim!(mcs; post_trial_func = my_scc_calculation)
```
