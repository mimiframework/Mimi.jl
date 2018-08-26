using Mimi
using Base.Test

# For now, use the warn function; for 0.7/1.0, remove this and use real logging...
macro info(msg)
    msg = "\n$msg"
    :(Base.println_with_color(:light_blue, $msg, bold=true))
end


@testset "Mimi" begin

    @info("test_main.jl")
    include("test_main.jl")

    @info("test_main_variabletimestep.jl")
    include("test_main_variabletimestep.jl")

    @info("test_metainfo.jl")
    include("test_metainfo.jl")

    @info("test_metainfo_variabletimestep.jl")
    include("test_metainfo_variabletimestep.jl")

    @info("test_references.jl")
    include("test_references.jl")

    @info("test_units.jl")
    include("test_units.jl")

    @info("test_model_structure.jl")
    include("test_model_structure.jl")

    @info("test_model_structure_variabletimestep.jl") 
    include("test_model_structure_variabletimestep.jl")

    @info("test_tools.jl")
    include("test_tools.jl")

    @info("test_parameter_labels.jl")
    include("test_parameter_labels.jl")

    @info("test_parametertypes.jl")
    include("test_parametertypes.jl")

    @info("test_marginal_models.jl")
    include("test_marginal_models.jl")

    @info("test_adder.jl")
    include("test_adder.jl")

    @info("test_getindex.jl")
    include("test_getindex.jl")

    @info("test_getindex_variabletimestep.jl") 
    include("test_getindex_variabletimestep.jl")

    @info("test_num_components.jl")
    include("test_num_components.jl")

    @info("test_components_ordering.jl")
    include("test_components_ordering.jl")

    @info("test_variables_model_instance.jl")
    include("test_variables_model_instance.jl")

    @info("test_getdataframe.jl")
    include("test_getdataframe.jl")

    @info("test_mult_getdataframe.jl")        
    include("test_mult_getdataframe.jl")    

    @info("test_timesteparrays.jl")
    include("test_timesteparrays.jl")
 
    @info("test_clock.jl")
    include("test_clock.jl")
 
    @info("test_dimensions")
    include("test_dimensions.jl")

    @info("test_timesteps.jl")           
    include("test_timesteps.jl") 

    # fails currently: requires either not having Refs typed (which prevents reassignment)
    # or by having lighter typing, e.g., TimestepArray but not a parameterized version.
    # @info("test_connectorcomp.jl")
    # include("test_connectorcomp.jl")

    @info("test_explorer.jl")
    include("test_explorer.jl")

    @info("test_plotting.jl")
    include("test_plotting.jl")

    include("mcs/run_tests.jl")
end
