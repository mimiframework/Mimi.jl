using Mimi
using Base.Test

#tests = ["main", "references", "units", "dependencies", "model_structure"]
tests = ["main", "units", "dependencies", "model_structure"]

for t in tests
    fp = joinpath("test_$t.jl")
    println("$fp ...")
    include(fp)
end
