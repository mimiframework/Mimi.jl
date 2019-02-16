using Mimi

include("/Users/lisarennels/.julia/dev/Mimi/examples/tutorial/02-two-region-model/two-region-model.jl")
using .MyModel
model = construct_MyModel()

run(model)

# show results
getdataframe(model, :emissions, :E_Global)
