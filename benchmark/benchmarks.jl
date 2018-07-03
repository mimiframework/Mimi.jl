using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() 
SUITE["two_regions"] = @benchmarkable run_tworegion() 

# Run the following lines to tune the SUITE, view parameters, and save them to be 
# viewed:   
# tune!(SUITE)
# SUITE
# BenchmarkTools.save("params.json", params(suite));
