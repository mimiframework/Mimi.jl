using Mimi
using Base.Test

@testset "Mimi" begin

    tests = (
        "main", "metainfo", "references", "units", "model_structure", "tools", 
        "parameter_labels", "parametertypes", "marginal_models", "adder", "getindex", 
        "num_components", "components_ordering", "variables_model_instance", "getdataframe", 
        "mult_getdataframe", "timesteparrays", "timesteps", "connectorcomp"
    )

    # override to test just specific modules
    good = ("metainfo", "references", "units")
    
    tests = ("model_structure",)

    for name in tests
        filename = "test_$(name).jl"
        println("\n*** Running $filename")
        include(filename)
    end

end
