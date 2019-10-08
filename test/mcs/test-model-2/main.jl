using Mimi

include("multi-region-model.jl")
using .MyModel
model = construct_MyModel()

run(model)

# show results
getdataframe(model, :emissions, :E_Global)
