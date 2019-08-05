using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles

using Test

using Mimi: modelinstance, compinstance, get_var_value, OUTER, INNER, ReshapedDistribution

include("../../examples/tutorial/02-two-region-model/two-region-model.jl")
using .MyModel
m = construct_MyModel()

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

    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end



output_dir = joinpath(tempdir(), "sim")

generate_trials!(sim, N, filename=joinpath(output_dir, "trialdata.csv"))

# Test that the proper number of trials were saved
d = readdlm(joinpath(output_dir, "trialdata.csv"), ',')
@test size(d)[1] == N+1 # extra row for column names

# Run trials 1:N, and save results to the indicated directory

Mimi.set_models!(sim, m)
run_sim(sim, output_dir=output_dir)

# From MCS discussion 5/23/2018
# generate_trials(sim, samples=load("foo.csv"))
#
# run_sim(sim, [:foo=>m1,:bar=>m2], output_vars=[:foo=>[:grosseconomy=>[:bar,:bar2,:bar3], :comp2=>:var2], :bar=>[]], N, output_dir="/tmp/Mimi")
# run_sim(sim, m1, output_vars=[:grosseconomy=>:asf, :foo=>:bar], N, output_dir="/tmp/Mimi")
# run_sim(mm, output_vars=[(:base,:compname,:varname), (:)], N, output_dir="/tmp/Mimi")
# run_sim(sim, sim, mm, output_vars=[:grosseconomy=>:asf, :foo=>:bar], N, output_dir="/tmp/Mimi")
# run_sim(sim, m, output_vars=[(:base,:compname,:varname), (:)], N, output_dir="/tmp/Mimi")

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

run_sim(sim;
        output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=outer_loop_func, 
        scenario_placement=OUTER)
 
@test loop_counter == 6


loop_counter = 0

run_sim(sim;
        output_dir=output_dir,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]],
        scenario_func=inner_loop_func, 
        scenario_placement=INNER)

@test loop_counter == N * 6


function other_loop_func(sim::Simulation, tup)
    global loop_counter
    loop_counter += 10
end

function pre_trial(sim::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
    global loop_counter
    loop_counter += 1
end

loop_counter = 0

run_sim(sim;
        output_dir=output_dir,
        pre_trial_func=pre_trial,
        scenario_func=other_loop_func,
        scenario_args=[:scen => [:low, :high],
                       :rate => [0.015, 0.03, 0.05]])

@test loop_counter == 6 * N + 60


function post_trial(sim::Simulation, trialnum::Int, ntimesteps::Int, tup::Union{Nothing,Tuple})
    global loop_counter    
    loop_counter += 1

    m = sim.models[1]
    # println("grosseconomy.share: $(m[:grosseconomy, :share])")
end

loop_counter = 0

N = 10
run_sim(sim;
        trials = N,
        output_dir=output_dir,
        post_trial_func=post_trial)

@test loop_counter == N

N = 1000

# Test new values generated for LHS sampling

generate_trials!(sim, N)
trial1 = copy(sim.rvdict[:name1].dist.values)

generate_trials!(sim, N)
trial2 = copy(sim.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
@test trial1 != trial2


# Same as sim above, but MCSData (default sampling), so we exclude correlation definitions
sim2 = @defsim begin
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

generate_trials!(sim2, N)
trial1 = copy(sim2.rvdict[:name1].dist.values)

generate_trials!(sim2, N)
trial2 = copy(sim2.rvdict[:name1].dist.values)

@test length(trial1) == length(trial2)
@test trial1 != trial2
