using PkgBenchmark

function benchmarkMimi(target::String, baseline::String; filename::String = nothing)

    results = judge("Mimi", target, baseline) 
    results_nums = collect(PkgBenchmark.benchmarkgroup(results))

    println("Results Summary: ")
    for i = 1:length(results_nums)
        println(results_nums[i]...)
    end

    export_markdown(string("benchmark/results/", filename), results)
    return results
end

results = benchmarkMimi("benchmark-branch1", "benchmark-branch2", filename = "test1")
