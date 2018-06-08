using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["one_region"] = @benchmarkable run_oneregion() 
SUITE["two_regions"] = @benchmarkable run_tworegion() 

# SUITE["region_models"]["one-region"] = @benchmarkable run_oneregion()
# SUITE["region_models"]["two-region"] = @benchmarkable run_tworegion()