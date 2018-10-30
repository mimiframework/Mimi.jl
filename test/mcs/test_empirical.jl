using ExcelFiles
using Mimi
using Random
using Statistics
using Test

include("../../wip/load_empirical_dist.jl")

# function load_vector(path, range, header=false)
#     tups = collect(load(path, range, header=header))
#     name = fieldnames(tups[1])[1]   # field name of first item in NamedTuple
#     map(obj -> getfield(obj, name), tups)
# end

# function load_empirical_dist(path::AbstractString, 
#                              values_range::AbstractString, 
#                              probs_range::AbstractString="")
#     println("Reading from '$path'")                     
#     values = load_vector(path, values_range)
#     probs = probs_range == "" ? nothing : load_vector(path, probs_range)
#     d = Mimi.EmpiricalDistribution(values, probs)
#     println("returning distribution $(typeof(d))")
#     return d
# end

filename = joinpath(@__DIR__, "RB-ECS-distribution.xls")
d = load_empirical_dist(filename, "Sheet1!A2:A1001", "Sheet1!B2:B1001")

# Set the seed to get repeatable results (with some caveats...)
Random.seed!(1234567)

# Get the statistical outline of the distribution
q = quantile.(Ref(d), [0.01, 0.10, 0.25, 0.50, 0.75, 0.90, 0.99])

expected = [1.47, 1.92, 2.33, 3.01, 4.16, 5.85, 9.16]
# @info "quantiles: $q\n expected: $expected"

@test isapprox(q, expected, atol=0.01)


# Test that the EmpiricalDistribution gets saved as a SampleStore and values 
# get re-used across multiple scenarios

num_scenarios = 4
num_trials = 5
output_dir = "./out/"

results = zeros(num_scenarios, num_trials)

_values = collect(1:10)
_probs = 0.1 * ones(10)

mcs_test = @defmcs begin
    p = EmpiricalDistribution(_values, _probs)
end 

@defcomp test begin
    p = Parameter(default = 5)
    function run_timestep(p, v, d, t) end
end

scenario_args = [
    :num => collect(1:num_scenarios)
]

function scenario_func(mcs::MonteCarloSimulation, tup::Tuple)
    nothing
end

function post_trial_func(mcs::MonteCarloSimulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
    m, = mcs.models
    scenario_num, = tup
    results[scenario_num, trialnum] = m[:test, :p]
end

m = Model()
set_dimension!(m, :time, 2000:2001)
add_comp!(m, test)
set_model!(mcs_test, m)

generate_trials!(mcs_test, num_trials; sampling = RANDOM)

run_mcs(mcs_test, num_trials;
    output_dir = output_dir,
    scenario_args = scenario_args,
    scenario_func = scenario_func, 
    post_trial_func = post_trial_func
    )

for rv in values(mcs_test.rvdict)
    @test rv.dist isa Mimi.SampleStore
end

for i = 1:num_scenarios
    @test results[i, :] == results[1, :]
end

rm(output_dir, recursive = true)

# Test in the case of sampling = LHS

generate_trials!(mcs_test, num_trials; sampling = LHS)
trial1 = copy(collect(values(mcs_test.rvdict))[1].dist.values)

for rv in values(mcs_test.rvdict)
    @test rv.dist isa Mimi.SampleStore
end

generate_trials!(mcs_test, num_trials; sampling = LHS)
trial2 = copy(collect(values(mcs_test.rvdict))[1].dist.values)

@test trial1!=trial2
