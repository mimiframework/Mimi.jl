using ExcelFiles
using Mimi
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
srand(1234567)

# Get the statistical outline of the distribution
q = quantile.(d, [0.01, 0.10, 0.25, 0.50, 0.75, 0.90, 0.99])

expected = [1.47, 1.92, 2.33, 3.01, 4.16, 5.85, 9.16]
println("quantiles: $q\n expected: $expected")

@test isapprox(q, expected, atol=0.01)
