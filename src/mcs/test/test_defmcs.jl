using Mimi
using Distributions
using Query
using Plots
using DataFrames
using IterTools

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

    depk[:] *= Uniform(0.7, 1.3)

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

Mimi.reset_compdefs()

include("../../../examples/tutorial/02-two-region-model/main.jl")

m = model

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, mcs::MonteCarloSimulation, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

N = 10000

generate_trials!(mcs, N, filename="/tmp/Mimi/trialdata.csv")

# Run trials 1:N, and save results to the indicated directory
run_mcs(m, mcs, N, output_dir="/tmp/Mimi")

# From MCS discussion 5/23/2018
# generate_trials(mcs, samples=load("foo.csv"))
#
# run_mcs([:foo=>m1,:bar=>m2], output_vars=[:foo=>[:grosseconomy=>[:bar,:bar2,:bar3], :comp2=>:var2], :bar=>[]], mcs, N, output_dir="/tmp/Mimi")
# run_mcs(m1, output_vars=[:grosseconomy=>:asf, :foo=>:bar], mcs, N, output_dir="/tmp/Mimi")
# run_mcs(mm, output_vars=[:grosseconomy=>:asf, :foo=>:bar], mcs, N, output_dir="/tmp/Mimi")
# run_mcs(mm, output_vars=[(:base,:compname,:varname), (:)], mcs, N, output_dir="/tmp/Mimi")
# run_mcs(m, output_vars=[(:base,:compname,:varname), (:)], mcs, N, output_dir="/tmp/Mimi")


# run_mcs(m, mcs, N, post_trial_func=print_result, output_dir="/tmp/Mimi")

function show_E_Global(year::Int; bins=40)
    df = @from i in E_Global begin
             @where i.time == year
             @select i
             @collect DataFrame
        end
    histogram(df[:E_Global], bins=bins, 
              title="Distribution of global emissions in $year",
              xlabel="Emissions")
end

#
# Test new loop capability
#

#
# Save a pointer to the generated function in the mcs struct
# Also save an optional context::Any that caller can use as needed
#
function my_loop_func(m::Model, mcs::MonteCarloSimulation,    # required args
                      scen::Symbol, rate::Float64)            # user-defined args
    # Do stuff with mcs and tuple values to set up model
    println("scen:$scen, rate:$rate")
end

# Pass as a tuple of pairs
run_mcs(m, mcs, 10;
        output_dir="/tmp/Mimi",
        loop_func=my_loop_func, 
        loop_args=[:scen => [:low, :med, :high],
                   :rate => [0.015, 0.03, 0.05]])
 