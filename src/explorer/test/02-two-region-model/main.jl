using Mimi
include("region_parameters.jl")
include("two-region-model.jl")

run1 = run_my_model()

#Check results
run1[:emissions, :E_Global]
