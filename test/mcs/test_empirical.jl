using FileIO
using Mimi
using Base.Test

# include("../../../wip/load_empirical_dist.jl")

using ExcelReaders

function load_vector(path, range, header=false)
    tups = collect(load(path, range, header=header))
    name = fieldnames(tups[1])[1]   # field name of first item in NamedTuple
    map(obj -> getfield(obj, name), tups)
end

function load_empirical_dist(path::AbstractString, 
                             values_range::AbstractString, 
                             probs_range::AbstractString="")
    println("Reading from '$path'")                     
    values = load_vector(path, values_range)
    probs = probs_range == "" ? nothing : load_vector(path, probs_range)
    d = Mimi.EmpiricalDistribution(values, probs)
    println("returning distribution $(typeof(d))")
    return d
end

filename = joinpath(@__DIR__, "RB-ECS-distribution.xls")
d = load_empirical_dist(filename, "Sheet1!A2:A1001", "Sheet1!B2:B1001")

vals = rand(d, 1000000)
#vals = repmat([3.5], 1000)
#append!(vals, [1, 10])

av = mean(vals)
mx = maximum(vals)
mn = minimum(vals)

@test isapprox(av, 3.50, atol=0.1)
@test isapprox(mn, 1.01, atol=0.1)
@test isapprox(mx, 10.0, atol=0.1)
