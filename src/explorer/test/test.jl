##  Mimi UI
using Mimi

## Test 1:  One Region Model
include(joinpath(@__DIR__, "01-one-region-model/one-region-model.jl"))
include("../explore.jl")
explore(my_model)
