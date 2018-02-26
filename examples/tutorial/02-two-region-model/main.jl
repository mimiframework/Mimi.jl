using Mimi
include("two-region-model.jl")

using tworegion

run(my_model)

#Check results
my_model[:emissions, :E_Global]
