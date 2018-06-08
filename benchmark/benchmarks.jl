using BenchmarkTools

include("RegionTutorialBenchmarks.jl")
using RegionTutorialBenchmarks

const SUITE = BenchmarkGroup()
SUITE["region_models"] = BenchmarkGroup
SUITE["region_models"] = @benchmarkable RegionTutorialBenchmarks