using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles
using VegaLite

using Test

N = 100

sim = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # assign RVs to model Parameters
    share = Uniform(0.2, 0.8)
    sigma[:, Region1] *= name2
    sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    depk = [Region1 => Uniform(0.08, 0.14),
            Region2 => Uniform(0.10, 1.50),
            Region3 => Uniform(0.10, 0.20)]

    sampling(SobolData, calc_second_order = false)
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

Mimi.reset_compdefs()
include("../../examples/tutorial/02-two-region-model/main.jl")

m = model

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, sim::Simulation, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

output_dir = joinpath(tempdir(), "sim")
generate_trials!(sim, N, filename=joinpath(output_dir, "trialdata.csv")) 

# Test that the proper number of trials were saved
d = readdlm(joinpath(output_dir, "trialdata.csv"), ',')
@test size(d)[1] == sim.trials+1 # extra row for column names

# Run trials 1:sim.trials, and save results to the indicated directory
Mimi.set_model!(sim, m)
run_sim(sim, sim.trials, output_dir=output_dir)

# do some analysis
E = load(joinpath(output_dir, "E.csv")) |> DataFrame
results = analyze(sim, E[1:60:end, 3])

function show_E_Region(year::Int; region = "Region1", bins=40)
    df = @from i in E begin
             @where i.time == year
             @where i.regions == region
             @select i
             @collect DataFrame
        end

    df |> @vlplot(:bar, x={:E, bin=true}, y="count()")
end

#
# Test scenario loop capability
#
global loop_counter = 0

function outer_loop_func(sim::Simulation, tup)
    global loop_counter
    loop_counter += 1

    # unpack tuple (better to use NT here?)
    (scen, rate) = tup
    @debug "outer loop: scen:$scen, rate:$rate"
end

function inner_loop_func(sim::Simulation, tup)
    global loop_counter
    loop_counter += 1

    # unpack tuple (better to use NT here?)
    (scen, rate) = tup
    @debug "inner loop: scen:$scen, rate:$rate"
end

loop_counter = 0

run_sim(sim, N;
        output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=outer_loop_func, 
        scenario_placement=Mimi.OUTER)
 
@test loop_counter == 6

loop_counter = 0

run_sim(sim, N;
        output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=inner_loop_func, 
        scenario_placement=Mimi.INNER)

@test loop_counter == sim.trials * 6

function other_loop_func(sim::Simulation, tup)
    global loop_counter
    loop_counter += 10
end

function pre_trial(sim::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
    global loop_counter
    loop_counter += 1
end

loop_counter = 0

run_sim(sim, N;
        output_dir=output_dir,
        pre_trial_func=pre_trial,
        scenario_func=other_loop_func,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]])

@test loop_counter == 6 * sim.trials + 60


function post_trial(sim::Simulation, trialnum::Int, ntimesteps::Int, tup::Union{Nothing,Tuple})
    global loop_counter    
    loop_counter += 1

    m = sim.models[1]
    # println("grosseconomy.share: $(m[:grosseconomy, :share])")
end

loop_counter = 0

N = 10
run_sim(sim, N;
        output_dir=output_dir,
        post_trial_func=post_trial)

@test loop_counter == sim.trials

N = 1000

# Test new values generated for Sobol sampling

generate_trials!(sim, N)
trial1 = copy(sim.rvdict[:name1].dist.values)

generate_trials!(sim, N)
trial2 = copy(sim.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
@test trial1 == trial2 # deterministic
