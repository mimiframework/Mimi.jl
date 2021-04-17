using Pkg

# We need these for the doctests. We install them before we load any
# package so that we don't run into precompile problems
Pkg.add(PackageSpec(url="https://github.com/fund-model/MimiFUND.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/anthofflab/MimiDICE2010.jl", rev="master"))

using Mimi
import Electron
using Test
using Documenter

Electron.prep_test_env()

@testset "Mimi" begin

    @info("test_main.jl")
    @time include("test_main.jl")

    @info("test_composite.jl")
    @time include("test_composite.jl")

    @info("test_composite_parameters.jl")
    @time include("test_composite_parameters.jl")

    @info("test_main_variabletimestep.jl")
    @time include("test_main_variabletimestep.jl")

    @info("test_broadcast.jl")
    @time include("test_broadcast.jl")

    @info("test_metainfo.jl")
    @time include("test_metainfo.jl")

    @info("test_metainfo_variabletimestep.jl")
    @time include("test_metainfo_variabletimestep.jl")

    @info("test_references.jl")
    @time include("test_references.jl")

    @info("test_units.jl")
    @time include("test_units.jl")

    @info("test_model_structure.jl")
    @time include("test_model_structure.jl")

    @info("test_model_structure_variabletimestep.jl")
    @time include("test_model_structure_variabletimestep.jl")

    @info("test_delete.jl")
    @time include("test_delete.jl")

    @info("test_replace_comp.jl")
    @time include("test_replace_comp.jl")

    @info("test_tools.jl")
    @time include("test_tools.jl")

    @info("test_parameter_labels.jl")
    @time include("test_parameter_labels.jl")

    @info("test_parametertypes.jl")
    @time include("test_parametertypes.jl")

    @info("test_defaults.jl")
    @time include("test_defaults.jl")

    @info("test_marginal_models.jl")
    @time include("test_marginal_models.jl")

    @info("test_adder.jl")
    @time include("test_adder.jl")

    @info("test_getindex.jl")
    @time include("test_getindex.jl")

    @info("test_getindex_variabletimestep.jl")
    @time include("test_getindex_variabletimestep.jl")

    @info("test_components.jl")
    @time include("test_components.jl")

    @info("test_variables_model_instance.jl")
    @time include("test_variables_model_instance.jl")

    @info("test_getdataframe.jl")
    @time include("test_getdataframe.jl")

    @info("test_mult_getdataframe.jl")
    @time include("test_mult_getdataframe.jl")

    @info("test_clock.jl")
    @time include("test_clock.jl")

    @info("test_timesteps.jl")
    @time include("test_timesteps.jl")

    @info("test_timesteparrays.jl")
    @time include("test_timesteparrays.jl")

    @info("test_dimensions.jl")
    @time include("test_dimensions.jl")

    @info("test_datum_storage.jl")
    @time include("test_datum_storage.jl")

    @info("test_connectorcomp.jl")
    @time include("test_connectorcomp.jl")
    
    @info("test_firstlast.jl")
    @time include("test_firstlast.jl")

    @info("test_explorer_model.jl") # BROKEN
    @time include("test_explorer_model.jl")

    @info("test_explorer_sim.jl")
    @time include("test_explorer_sim.jl")

    @info("test_explorer_compositecomp.jl")
    @time include("test_explorer_compositecomp.jl")

    @info("mcs/runtests.jl")
    @time include("mcs/runtests.jl")
    
    @info("doctests")
    @time doctest(Mimi)

    for app in Electron.applications()
        close(app)
    end
    
end
