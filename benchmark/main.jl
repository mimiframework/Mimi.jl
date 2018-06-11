using PkgBenchmark

#function to compare the package benchmark suite performance at the target git id
#at the target and the baeline git id (eg. branch, commit, etc.)
function benchmarkMimi(target::String, baseline::String; filepath::String = nothing)

    results = judge("Mimi", target, baseline)

    #gather the results in order to print a short summmary of the comparison
    trial_judgement = collect(PkgBenchmark.benchmarkgroup(results))
    target_results_nums = collect(PkgBenchmark.benchmarkgroup(PkgBenchmark.target_result(results)))
    baseline_results_nums = collect(PkgBenchmark.benchmarkgroup(PkgBenchmark.baseline_result(results)))
    
    println("Results Summary: ")
    for i = 1:length(trial_judgement)
        println(trial_judgement[i]...)
        println("Min for Target: ", target_results_nums[i]...)
        println("Min for Baseline: ", baseline_results_nums[i]...)
        println("")
    end

    #print optional results file
    if filepath != nothing
        export_markdown(string(filepath), results)
    end

    return results
end
