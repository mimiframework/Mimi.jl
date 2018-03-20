using Mimi

include("two-region-model.jl")

run(model)

# show results
getdataframe(model, :emissions, :E_Global)
