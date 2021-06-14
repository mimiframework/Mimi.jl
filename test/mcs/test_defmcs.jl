using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles

using Test

using Mimi: modelinstance, compinstance, get_var_value, OUTER, INNER, ReshapedDistribution

using CSVFiles: load

# Toy @defsim 

@defcomp test begin
    regions = Index()                           

    p_shared1   = Parameter()
    p_shared2   = Parameter(index = [time])
    p_shared3   = Parameter(index=[time, regions])
    p_shared4   = Parameter(index = [regions])

    p_unshared1   = Parameter(default = 5.0)
    p_unshared2   = Parameter(index = [time], default = collect(1:20))
    p_unshared3   = Parameter(index=[time, regions], default = fill(10,20,3))
    p_unshared4   = Parameter(index = [regions], default = collect(1:3))

    function run_timestep(p, v, d, t)
    end
end

sd_toy = @defsim begin
    
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # shared parameters
    p_shared1 = name1
    p_shared2[2015] *= name2
    p_shared3[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)
    p_shared4 = [Region1 => Uniform(0.08, 0.14),
                Region2 => Uniform(0.10, 1.50),
                Region3 => Uniform(0.10, 0.20)]

    # unshared parameters
    test.p_unshared1 = name1
    test.p_unshared2[2015] *= name2
    test.p_unshared3[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)
    test.p_unshared4 = [Region1 => Uniform(0.08, 0.14),
                Region2 => Uniform(0.10, 1.50),
                Region3 => Uniform(0.10, 0.20)]

end

m = Model()
set_dimension!(m, :time, 2015:5:2110)
set_dimension!(m, :regions, [:Region1, :Region2, :Region3])
add_comp!(m, test)

add_shared_param!(m, :p_shared1, 5)
connect_param!(m, :test, :p_shared1, :p_shared1)

@test_throws ErrorException add_shared_param!(m, :p_shared2, collect(1:20)) # need dimensions
add_shared_param!(m, :p_shared2, collect(1:20), dims = [:time])
connect_param!(m, :test, :p_shared2, :p_shared2)

@test_throws ErrorException add_shared_param!(m, :p_shared3, fill(10,20,3), dims = [:time]) # need 2 dimensions
add_shared_param!(m, :p_shared3, fill(10,20,3), dims = [:time, :regions])
connect_param!(m, :test, :p_shared3, :p_shared3)

add_shared_param!(m, :p_shared4, collect(1:3), dims = [:regions])
connect_param!(m, :test, :p_shared4, :p_shared4)

run(sd_toy, m, 10)

# More Complex/Realistic @defsim

include("test-model-2/multi-region-model.jl")
using .MyModel
m = construct_MyModel()
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
    
    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global, grosseconomy.share_var, grosseconomy.depk_var)
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

# test getdataframe
results_mem = si.results[1][(:grosseconomy, :K)] # manual access to dictionary
results_getdataframe = getdataframe(si, :grosseconomy, :K) # getdataframe
results_getdataframe2 = getdataframe(si, :grosseconomy, :K, model = 1) # getdataframe

@test results_getdataframe == results_mem
@test results_getdataframe2 == results_mem

# test that disk results equal in memory results
results_disk = load(joinpath(output_dir, "grosseconomy_K.csv")) |> DataFrame
results_disk[!,2] = Symbol.(results_disk[!,2])
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

# test getdataframe with scenarios
results_mem = si.results[1][(:grosseconomy, :K)] # manual access to dictionary
results_getdataframe = getdataframe(si, :grosseconomy, :K) # getdataframe
@test results_getdataframe == results_mem

# test in memory results compared to disk saved results
results_disk = load(joinpath(output_dir, "high_0.03", "grosseconomy_K.csv")) |> DataFrame
results_mem = results_mem |> @filter(_.scen == "high_0.03") |> DataFrame

results_disk[!,2] = Symbol.(results_disk[!,2])
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

results_disk[!,2] = Symbol.(results_disk[!,2])
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

results_disk[!,2] = Symbol.(results_disk[!,2])
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

results_disk[!,2] = Symbol.(results_disk[!,2])
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

# test broadcasting examples
sd3 = @defsim begin

    # 1 dimension
    grosseconomy.depk[:] = Uniform(0.1, 0.2)
    grosseconomy.k0[(Region2, Region3)] = Uniform(20, 30)
    
    # 2 dimensions
    grosseconomy.tfp[:, Region1] = Uniform(0.75, 1.25)
    emissions.sigma[2020:5:2050, (Region2, Region3)] = Uniform(0.8, 1.2)
    grosseconomy.s[2020, Region1] = Uniform(0.2, 0.3)
     
end

N = 5
si3 = run(sd3, m, N)
