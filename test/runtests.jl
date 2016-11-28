using Mimi
using Base.Test

tests = ["main", "references", "units", "model_structure", "tools", "parameter_labels"]

for t in tests
    fp = joinpath("test_$t.jl")
    println("$fp ...")
    include(fp)
end
