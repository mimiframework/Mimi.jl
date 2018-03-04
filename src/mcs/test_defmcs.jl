using Mimi
using Distributions

include("examples/tutorial/02-two-region-model/main.jl")

m = tworegion.my_model

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

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, 
         emissions.E, emissions.E_Global)
end

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, mcs::MonteCarloSimulation, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

generate_trials!(mcs, 20, filename="/tmp/trialdata.csv")

# Run trials 1:4, and save results to the indicated directory
run_mcs(m, mcs, 4, output_dir="/tmp/Mimi")

# run_mcs(m, mcs, 4, post_trial_func=print_result, output_dir="/tmp/Mimi")
