__precompile__(false)

module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    # @defcomp,
    # @defmodel,
    # ComponentDef,
    # ComponentKey,
    ComponentReference,
    MarginalModel,
    Model,
    ModelParameter,
    Timestep,
    TimestepMatrix,
    TimestepVector,
    addcomponent,
    adddimension,
    addparameter,
    compdef,
    compdefs,
    components,
    connectparameter,
    delete!,
    get_unconnected_parameters,
    getdataframe,
    dimensions,
    getindex,
    indexcount,
    indexvalues,
    parameters,
    variables,
    hasvalue,
    indexlabels,
    isfinaltimestep,
    isfirsttimestep,
    load_comps,
    newcomponent,
    # plot,
    run,
    run_expr,
    run_timestep,
    setindex,
    set_leftover_parameters,
    setparameter,
    set_run_expr,
    unitcheck,
    update_external_parameter,
    variables 

import
    Base.getindex, Base.run, Base.show

include("core/types.jl")
include("core/macros.jl")

# After loading types and macros, the rest can just be alphabetical
include("core/build.jl")
include("core/clock.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/instances.jl")
include("core/mimi-core.jl")
include("core/references.jl")
include("core/timestep_arrays.jl")
include("core/model.jl")

include("utils/graph.jl")
# include("utils/plotting.jl")
include("utils/getdataframe.jl")
include("utils/lint_helper.jl")


"""
    load_comps(dirname::String="./components")

Call include() on all the files in the indicated directory.
This avoids having modelers create a long list of include()
statements. Just put all the components in a directory.
"""
function load_comps(dirname::String="./components")
    files = readdir(dirname)
    for file in files
        if endswith(file, ".jl")
            pathname = joinpath(dirname, file)
            include(pathname)
        end
    end
end

# Components are defined here to allow pre-compilation to work
function __init__()
    compdir = joinpath(dirname(@__FILE__), "components")
    load_comps(compdir)
end

end # module
