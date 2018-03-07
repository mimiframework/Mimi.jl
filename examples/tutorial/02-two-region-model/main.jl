using Mimi

include(joinpath(@__DIR__, "two-region-model.jl"))

using tworegion

m = tworegion.tutorial

run(m)

# show results
getdataframe(m, :emissions, :E_Global)
