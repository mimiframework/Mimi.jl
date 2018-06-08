using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["blah"] = @benchmarkable 1+1 

# SUITE["region_models"] = BenchmarkGroup(["one-region", "two-region"])
# SUITE["region_models"]["one-region"] = @benchmarkable run_oneregion()
# SUITE["region_models"]["two-region"] = @benchmarkable run_tworegion()
tune!(SUITE)