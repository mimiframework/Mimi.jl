using Mimi
using Base.Test

tests = ["main", "units", "dependencies", "model_structure"]

for t in tests
    fp = joinpath("test_$t.jl")
    println("$fp ...")
    include(fp)
end
