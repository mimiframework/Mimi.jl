__precompile__(false)

module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    @defcomp,
    @defmodel,
    ComponentDef,
    ComponentKey,
    ComponentReference,
    MarginalModel,
    Model,
    Timestep,
    TimestepMatrix,
    TimestepVector,
    addcomponent,
    adddimension,
    addparameter,
    components,
    connectparameter,
    delete!,
    get_unconnected_parameters,
    getcompdef,
    getcompdefs,
    get_componentdef_variables,
    getdataframe,
    getdimensions,
    getindex,
    getindexcount,
    getindexlabels,
    getindexvalues,
    getparameters,
    get_run_expr,
    getvariables,
    getvpd,
    hasvalue,
    isfinaltimestep,
    isfirsttimestep,
    load_comps,
    # plot,
    run,
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

include("types/timestep.jl")
include("types/definitions.jl")
include("types/instances.jl")
include("types/model.jl")

# After loading types, the rest can just be alphabetical
include("core/build.jl")
include("core/clock.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/defmodel.jl")
include("core/mimi-core.jl")
include("core/references.jl")
include("core/run.jl")
include("core/timestep_arrays.jl")

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
