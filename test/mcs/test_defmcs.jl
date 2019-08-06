using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles

using Test

using Mimi: reset_compdefs, modelinstance, compinstance, 
            get_var_value, OUTER, INNER, ReshapedDistribution

using CSVFiles: load

include("test-model-2/two-region-model.jl")
using .MyModel
m = construct_MyModel()

N = 100

sd = @defsim begin
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

    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global, grosseconomy.share_var, grosseconomy.k0_var)
end

# Optionally, user functions can be called just before or after a trial is run
function print_result(m::Model, sim_inst::SimulationInstance, trialnum::Int)
    ci = Mimi.compinstance(m.mi, :emissions)
    value = Mimi.get_variable_value(ci, :E_Global)
    println("$(ci.comp_id).E_Global: $value")
end

output_dir = joinpath(tempdir(), "sim")

# Run trials 
si = run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

# Test that the proper number of trials were saved
d = readdlm(joinpath(output_dir, "trialdata.csv"), ',')
@test size(d)[1] == N+1 # extra row for column names

function show_E_Global(year::Int; bins=40)
    df = @from i in E_Global begin
             @where i.time == year
             @select i
             @collect DataFrame
        end
    histogram(df.E_Global, bins=bins, 
              title="Distribution of global emissions in $year",
              xlabel="Emissions")
end

# test getindex
results_mem = si.results[1][(:grosseconomy, :K)] # manual access to dictionary
results_getindex = si[:grosseconomy, :K] # Base.getindex
results_getindex2 = si[:grosseconomy, :K, model = 1] # Base.getindex

@test results_getindex == results_mem
@test results_getindex2 == results_mem

# test that disk results equal in memory results
results_disk = load(joinpath(output_dir, "grosseconomy_K.csv")) |> DataFrame
results_disk[:,2] = Symbol.(results_disk[:,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

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
        scenario_placement=OUTER)
 
@test loop_counter == 6

# test getindex with scenarios
results_mem = si.results[1][(:grosseconomy, :K)] # manual access to dictionary
results_getindex = si[:grosseconomy, :K] # Base.getindex
@test results_getindex == results_mem

# test in memory results compared to disk saved results
results_disk = load(joinpath(output_dir, "high_0.03", "grosseconomy_K.csv")) |> DataFrame
results_mem = results_mem |> @filter(_.scen == "high_0.03") |> DataFrame

results_disk[:,2] = Symbol.(results_disk[:,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

# delete all created directories and files
rm(output_dir, recursive = true)

loop_counter = 0

si = run(sd, m, N;
        results_output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=inner_loop_func, 
        scenario_placement=INNER)

@test loop_counter == N * 6

function other_loop_func(sim_inst::SimulationInstance, tup)
    global loop_counter
    loop_counter += 10
end

function pre_trial(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)
    global loop_counter
    loop_counter += 1
end

# test in memory results compared to disk saved results
results_disk = load(joinpath(output_dir, "high_0.03", "grosseconomy_K.csv")) |> DataFrame
results_mem = si.results[1][(:grosseconomy, :K)] |> @filter(_.scen == "high_0.03") |> DataFrame

results_disk[:,2] = Symbol.(results_disk[:,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

# delete all created directories and files
rm(output_dir, recursive = true)

loop_counter = 0

si = run(sd, m, N;
        results_output_dir=output_dir,
        pre_trial_func=pre_trial,
        scenario_func=other_loop_func,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]])

@test loop_counter == 6 * N + 60

# test in memory results compared to disk saved results
results_disk = load(joinpath(output_dir, "high_0.03", "grosseconomy_K.csv")) |> DataFrame
results_mem = si.results[1][(:grosseconomy, :K)] |> @filter(_.scen == "high_0.03") |> DataFrame

results_disk[:,2] = Symbol.(results_disk[:,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

# delete all created directories and files
rm(output_dir, recursive = true)

function post_trial(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Union{Nothing,Tuple})
    global loop_counter    
    loop_counter += 1

    m = sim_inst.models[1]
    # println("grosseconomy.share: $(m[:grosseconomy, :share])")
end

loop_counter = 0

N = 10
si = run(sd, m, N;
        results_output_dir=output_dir,
        post_trial_func=post_trial)

@test loop_counter == N

# test in memory results compared to disk saved results
results_disk = load(joinpath(output_dir, "grosseconomy_K.csv")) |> DataFrame
results_mem = si.results[1][(:grosseconomy, :K)]

results_disk[:,2] = Symbol.(results_disk[:,2])
@test results_disk[:, [1,2,4]] == results_mem[:, [1,2,4]]
@test results_disk[:, 3] ≈ results_disk[:, 3] atol = 1e-9

# delete all created directories and files
rm(output_dir, recursive = true)

N = 1000

# Test new values generated for LHS sampling
si1 = run(sd, m, N)
trial1 = copy(si1.sim_def.rvdict[:name1].dist.values)

si2 = run(sd, m, N)
trial2 = copy(si2.sim_def.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
@test trial1 != trial2


# Same as sim above, but MCSData (default sampling), so we exclude correlation definitions
sd2 = @defsim begin
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

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

# Test new values generated for RANDOM sampling
si1 = run(sd2, m, N)
trial1 = copy(si1.sim_def.rvdict[:name1].dist.values)

si2 = run(sd2, m, N)
trial2 = copy(si2.sim_def.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
@test trial1 != trial2
