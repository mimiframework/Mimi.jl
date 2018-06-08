using PkgBenchmark

function benchmarkMimi(target::String, baseline::String; filepath::String = nothing)

    results = judge("Mimi", target, baseline; ) 
    trial_judgement = collect(PkgBenchmark.benchmarkgroup(results))

    target_results_nums = collect(PkgBenchmark.benchmarkgroup(PkgBenchmark.target_result(results)))
    baseline_results_nums = collect(PkgBenchmark.benchmarkgroup(PkgBenchmark.baseline_result(results)))
    
    println("Results Summary: ")
    for i = 1:length(results_nums)
        println(results_nums[i]...)
        println("Min for Target: ", target_results_nums[i]...)
        println("Min for Baseline: ", baseline_results_nums[i]...)
        println("")
    end

    export_markdown(string(filepath), results)
    return results
end
