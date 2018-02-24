__precompile__(false)

module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    @defcomp,
    @defmodel,
    @modelegate,
    ArrayModelParameter, 
    ComponentDef,
    ComponentId, 
    ComponentInstance, 
    ComponentInstanceData, 
    ComponentInstanceParameters,
    ComponentInstanceVariables, 
    ComponentReference,
    DimensionDef, 
    ExternalParameterConnection, 
    InternalParameterConnection, 
    MarginalModel,
    Model,
    ModelDef, 
    ModelInstance,
    ModelParameter,
    ParameterDef, 
    ScalarModelParameter,
    Timestep, 
    TimestepMatrix, 
    TimestepVector,
    VariableDef,
    addcomponent,
    add_connector_comps!,
    add_dimension,
    addparameter,
    compdef,
    compdefs,
    components,
    connect_parameter,
    connected_params,
    datatype,
    delete!,
    description,
    dimensions,
    duration,
    getdataframe,
    getindex,
    hasvalue,
    indexcount,
    indexlabels,
    indexvalues,
    is_final_timestep,
    is_first_timestep,
    load_comps,
    modeldef,
    name,
    newcomponent,
    number_type,
    parameters,
    # plot,
    run,
    run_expr,
    run_timestep,
    set_leftover_params,
    set_run_expr,
    setindex,
    set_parameter,
    unconnected_params,
    unit,
    # update_external_param,
    variables

import
    Base.getindex, Base.run, Base.show

include("core/types.jl")

# After loading types and macros, the rest can just be alphabetical
include("core/build.jl")
include("core/connections.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/instances.jl")
# include("core/mimi-core.jl")
include("core/references.jl")
include("core/time.jl")
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
