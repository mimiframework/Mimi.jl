using PkgBenchmark
using BenchmarkTools
using JSON

function benchmarkMimi(target::String, baseline::String; filename::String = nothing)

    results = judge("Mimi", target, baseline) 

    base_results = PkgBenchmark.baseline_result(results)
    base_trials = PkgBenchmark.benchmarkgroup(base_results)["region_models"]
    target_results = PkgBenchmark.target_result(results)
    target_trials = PkgBenchmark.benchmarkgroup(target_results)["region_models"]

    println("Baseline Minimum:  ", base_trials)
    println("Target Minimum:  ", target_trials)

    export_markdown(string("benchmark/results/", filename), results)
    return results
end

results = benchmarkMimi("benchmark-branch1", "benchmark-branch2", filename = "test1")
