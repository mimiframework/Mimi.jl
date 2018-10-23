using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
include("getindex.jl")

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() 
SUITE["two_regions"] = @benchmarkable run_tworegion()
SUITE["getindex"] = @benchmarkable run_getindex()