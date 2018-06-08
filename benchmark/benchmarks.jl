using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["region_models"] = BenchmarkGroup(["one-region", "two-region"])
SUITE["region_models"]["one-region"] = @benchmarkable 1+1 #run_oneregion()
SUITE["region_models"]["two-region"] = @benchmarkable 1+1 #run_tworegion()