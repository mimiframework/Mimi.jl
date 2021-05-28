using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles
using VegaLite

using Test

using CSVFiles: load

N = 100

sd = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an model parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # assign RVs to model Parameters
    grosseconomy.share = Uniform(0.2, 0.8)
    emissions.sigma[:, Region1] *= name2
    emissions.sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    grosseconomy.depk = [Region1 => Uniform(0.08, 0.14),
            Region2 => Uniform(0.10, 1.50),
            Region3 => Uniform(0.10, 0.20)]

    sampling(SobolData, calc_second_order = false)
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

include("../../examples/tutorial/02-multi-region-model/main.jl")

m = model

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, sim_inst::SimulationInstance, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

output_dir = joinpath(tempdir(), "sim")
si = run(sd, m, N; trials_output_filename=joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

# Test that the proper number of trials were saved
d = readdlm(joinpath(output_dir, "trialdata.csv"), ',')
@test size(d)[1] == si.trials+1 # extra row for column names

# Check files saved to disk compared to data saved in memory
results_disk = load(joinpath(output_dir, "grosseconomy_K.csv")) |> DataFrame
results_mem = si.results[1][(:grosseconomy, :K)]

results_disk[!,2] = Symbol.(results_disk[!,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

# do some analysis
E = CSVFiles.load(joinpath(output_dir, "emissions_E.csv")) |> DataFrame
results = analyze(si, E[1:60:end, 3]; progress_meter = false, N_override = 100)
results = analyze(si, E[1:60:end, 3]; progress_meter = false, num_resamples = 10_000, conf_level = 0.95)

# delete all created directories and files
rm(output_dir, recursive = true)

#
# Test scenario loop capability
#
global loop_counter = 0

function outer_loop_func(sim_inst::SimulationInstance, tup)
    global loop_counter
    loop_counter += 1

    # unpack tuple (better to use NT here?)
    (scen, rate) = tup
    @debug "outer loop: scen:$scen, rate:$rate"
end

function inner_loop_func(sim_inst::SimulationInstance, tup)
    global loop_counter
    loop_counter += 1

    # unpack tuple (better to use NT here?)
    (scen, rate) = tup
    @debug "inner loop: scen:$scen, rate:$rate"
end

loop_counter = 0

si = run(sd, m, N;
        results_output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=outer_loop_func, 
        scenario_placement=Mimi.OUTER)
 
@test loop_counter == 6

# delete all created directories and files
rm(output_dir, recursive = true)

loop_counter = 0

si = run(sd, m, N;
        results_output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=inner_loop_func, 
        scenario_placement=Mimi.INNER)

@test loop_counter == si.trials * 6

function other_loop_func(sim_inst::SimulationInstance, tup)
    global loop_counter
    loop_counter += 10
end

function pre_trial(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)
    global loop_counter
    loop_counter += 1
end

# delete all created directories and files
rm(output_dir, recursive = true)

loop_counter = 0

si = run(sd, m, N;
        results_output_dir=output_dir,
        pre_trial_func=pre_trial,
        scenario_func=other_loop_func,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]])

@test loop_counter == 6 * si.trials + 60


function post_trial(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Union{Nothing,Tuple})
    global loop_counter    
    loop_counter += 1

    m = sim_inst.models[1]
    # println("grosseconomy.share: $(m[:grosseconomy, :share])")
end

# delete all created directories and files
rm(output_dir, recursive = true)

loop_counter = 0

N = 10
si = run(sd, m, N;
        results_output_dir=output_dir,
        post_trial_func=post_trial)

@test loop_counter == si.trials

# delete all created directories and files
rm(output_dir, recursive = true)

N = 1000

# Test new values generated for Sobol sampling
si1 = run(sd, m, N)
trial1 = copy(si1.sim_def.rvdict[:name1].dist.values)

si2 = run(sd, m, N)
trial2 = copy(si2.sim_def.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
