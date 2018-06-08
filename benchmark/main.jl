using PkgBenchmark
using BenchmarkTools

function benchmarkMimi(target::String, baseline::String)
    return judge("Mimi", target, baseline) 
end

results = benchmarkMimi("benchmark-suite", "master")
