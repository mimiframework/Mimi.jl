using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
include("getindex.jl")

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() 
SUITE["multi_regions"] = @benchmarkable run_multiregion()
SUITE["getindex"] = @benchmarkable run_getindex()