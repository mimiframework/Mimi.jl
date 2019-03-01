# Tutorial 4: Monte Carlo Simulation (MCS) Support

This tutorial walks through the MCS functionality of Mimi, including core routines and examples.  We will start with looking at using the MCS routines with the Mimi two-region model provided in the Mimi repository at `examples/tutorial/02-two-region-model`, and then build out to examine its use on [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund), 

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/mimiframework/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

Futhermore, if you are not yet comfortable with downloading (only needs to be done once) and running FUND, refer to Tutorial 1 for instructions.  Carry out **Steps 1 and 2** from Tutorial 1, and then return to continue with this tutorial. Note that FUND is only requred for the second example in this tutorial. 

## The API

The best current documentation on the MCS API is the internals documentation [here](https://github.com/mimiframework/Mimi.jl/blob/master/docs/src/internals/montecarlo.md), which provides a working and informal description of the Monte Carlo Simulation support of Mimi. This file should be used in conjunction with the examples below for details, since the documentation covers more advanced options such as non-stochastic scenarios and running multiple models, which are not yet included in this tutorial.

## Two-Region Model Example

This section will walk through the simple example provided in `"Mimi.jl/test/mcs/test_defmcs.jl"`.

### Step 1. Setup
First, set up for the tutorial as follows with the necessary packages and `main.jl` script for the two-region example.  You should have `Mimi` installed by now, and if you do not have `Distributions`, take a moment to add that package using by entering `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode and then typing `add Distributions`.

```juila
cd(<Mimi-directory-path>) # Mimi-directory-path is a placeholder for the string describing the path of the Mimi directory
using Distributions

include("examples/tutorial/02-two-region-model/main.jl")
m = model # defined by 2-region model
```

### Step 2. Define Random Variables
The `@defmcs` macro, which defines random variables (RVs) which are assigned distributions and associated with model parameters, is the first step in the process.

```julia
mcs = @defmcs begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # define correlations
    name1:name2 = 0.7
    name1:name3 = 0.5

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
Next, a user may create a user-defined function, which can be called as a pre or post-trial function by [`run_mcs`](@ref).

If `pre_trial_func` or `post_trial_func` are defined, the designated functions are called 
just before or after (respectively) running a trial. The functions must have the signature:

    fn(mcs::MonteCarloSimulation, trialnum::Int, ntimesteps::Int, tup::Tuple)

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the MCS loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

### Step 2. Generate Trials

The optional [`generate_trials!`](@ref) function can be used to pre-generate all trial data, save all random variable values in a file, and/or override the default (Latin Hypercube) sampling method.  If this function is not called prior to calling [`run_mcs`](@ref), random sampling is used for all distributions and trial data are not saved. Employ this function as follows:

```julia
# Generate trial data for all RVs and (optionally) save to a file
output_dir = joinpath(tempdir(), "mcs")
generate_trials!(mcs, 1000, filename=joinpath(output_dir, "trialdata.csv"))
```

### Step 4. Run MCS

Finally, use the [`set_models!`](@ref) and [`run_mcs`](@ref) functions.  First, calling [`set_models!`] with a model, marginal model, or list of models will set those models as those to be run by your `mcs` simulation.  Next, use [`run_mcs`](@ref) which runs a simulation, with parameters describing the number of trials and optional callback functions to customize simulation behavior. In its simplest use, the [`run_mcs`](@ref) function iterates over a given number of trials, perturbing a chosen set of Mimi's "external parameters", based on the defined distributions, and then runs the given Mimi model. Optionally, trial values and/or model results are saved to CSV files.  View the internals documentation for **critical and useful details on the full signature of this function**:

```
function run_mcs(mcs::MonteCarloSimulation, 
                 trials::Union{Int, Vector{Int}, AbstractRange{Int}},
                 models_to_run::Int=length(mcs.models);
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing)
```

Here, we first employ [`run_mcs`](@ref) in its simplest form to obtain results:

```julia
set_models!(mcs, m)
# Run trials 1:4, and save results to the indicated directory, one CSV file per RV
run_mcs(mcs,1:4, output_dir=output_dir)
```

## FUND Example

This example is in progress and will be built out soon.
