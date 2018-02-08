module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays
using MacroTools

export
    @defcomp,
    @deftimestep,
    ComponentDef,
    ComponentKey,
    ConnectorCompMatrix,        # deprecated
    ConnectorCompVector,        # deprecated
    MarginalModel,
    Model,
    Timestep,
    TimestepMatrix,
    TimestepVector,
    addcomponent,
    adder,
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
    plot,
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

include("core/metainfo.jl")
include("modelinstance/mi_types.jl")
include("modelinstance/clock.jl")
include("modelinstance/deftimestep_macro.jl")
include("modelinstance/run.jl")

include("core/mimi_types.jl")
include("core/timestep_arrays.jl")
include("core/references.jl")
include("core/defcomp2.jl")
include("core/build.jl")
include("core/mimi-core.jl")

include("helpercomponents/marginalmodel.jl")

include("utils/graph.jl")
include("utils/plotting.jl")
include("utils/getdataframe.jl")
include("utils/lint_helper.jl")

# Components are defined here to allow pre-compilation to work
function __init__()
    include("helpercomponents/adder.jl")
    include("helpercomponents/connectorcomp.jl")   
end

end # module
