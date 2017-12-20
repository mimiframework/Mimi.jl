using Mimi
using Base.Test

@testset "Mimi" begin

include("test_main.jl")
include("test_references.jl")
include("test_units.jl")
include("test_model_structure.jl")
include("test_tools.jl")
include("test_parameter_labels.jl")
include("test_marginal_models.jl")
include("test_adder.jl")
include("test_getindex.jl")
include("test_num_components.jl")
include("test_components_ordering.jl")
include("test_variables_model_instance.jl")
include("test_getdataframe.jl")

end
