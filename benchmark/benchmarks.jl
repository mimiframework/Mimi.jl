using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() seconds = 20.0 samples = 10_000
SUITE["two_regions"] = @benchmarkable run_tworegion() seconds = 20.0 samples = 10_000

# Run the following lines to tune the SUITE, view parameters, and save them to be 
# viewed:   
# tune!(SUITE)
# SUITE
# BenchmarkTools.save("params.json", params(suite));
