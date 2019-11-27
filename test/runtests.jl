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
    include("test_main.jl")

    @info("test_composite.jl")
    include("test_composite.jl")

    @info("test_main_variabletimestep.jl")
    include("test_main_variabletimestep.jl")

    @info("test_broadcast.jl")
    include("test_broadcast.jl")

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

    @info("test_replace_comp.jl")
    include("test_replace_comp.jl")

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

    @info("test_components.jl")
    include("test_components.jl")

    @info("test_variables_model_instance.jl")
    include("test_variables_model_instance.jl")

    @info("test_getdataframe.jl")
    include("test_getdataframe.jl")

    @info("test_mult_getdataframe.jl")
    include("test_mult_getdataframe.jl")

    @info("test_clock.jl")
    include("test_clock.jl")

    @info("test_timesteps.jl")
    include("test_timesteps.jl")

    @info("test_timesteparrays.jl")
    include("test_timesteparrays.jl")

    @info("test_dimensions")
    include("test_dimensions.jl")

    @info("test_datum_storage.jl")
    include("test_datum_storage.jl")

    @info("test_connectorcomp.jl")
    include("test_connectorcomp.jl")

    @info("test_explorer_model.jl")
    include("test_explorer_model.jl")

    @info("test_explorer_sim.jl")
    include("test_explorer_sim.jl")

    @info("test_plotting.jl")
    include("test_plotting.jl")

    @info("mcs/runtests.jl")
    include("mcs/runtests.jl")
    
    @info("doctests")
    doctest(Mimi)

    if haskey(ENV, "GITHUB_ACTIONS") && ENV["GITHUB_ACTIONS"] == "true"
        run(`$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(@__DIR__, "dependencies", ".")) $(joinpath(@__DIR__, "dependencies", "run_dependency_tests.jl"))`)
    end
end
