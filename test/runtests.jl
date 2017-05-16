using Mimi
using Base.Test


tests = ["main",
    "references",
    "units",
    "model_structure",
    "tools",
    "parameter_labels",
    "marginal_models",
    "adder",
    "getindex",
    "num_components",
    "components_ordering",
    "variables_model_instance",
    "getdataframe",
    "mult_getdataframe",
    "ourarrays"
]

for t in tests
    fp = joinpath("test_$t.jl")
    println("$fp ...")
    include(fp)
end
