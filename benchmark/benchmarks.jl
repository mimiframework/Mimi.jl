using BenchmarkTools

include("RegionTutorialBenchmarks.jl")

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() 
SUITE["two_regions"] = @benchmarkable run_tworegion()
