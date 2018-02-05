module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays
using MacroTools

export
    @defcomp,
    @deftimestep,
    ComponentState,
    ConnectorCompMatrix,
    ConnectorCompVector,
    MarginalModel,
    Model,
    Timestep,
    TimestepMatrix,
    TimestepVector,
    addcomponent,
    adder,
    components,
    connectparameter,
    delete!,
    get_unconnected_parameters,
    get_componentdef_variables,
    getdataframe,
    getindex,
    getindexcount,
    getindexlabels,
    getindexvalues,
    getvariable,
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
    unitcheck,
    update_external_parameter,
    variables 

import
    Base.getindex, Base.run, Base.show

# _subdirs = ("modelinstance", "core", "helpercomponents", "utils")

# for d in _subdirs
#     if ! (d in LOAD_PATH)
#         push!(LOAD_PATH, d)
#     end
# end

# using modelinstance
# using core
# using helpercomponents
# using utils

include("modelinstance/mi_types.jl")
include("modelinstance/clock.jl")

include("core/mimi_types.jl")
include("core/timestep_arrays.jl")
include("core/metainfo.jl")

include("modelinstance/dotoverloading.jl")
include("modelinstance/run.jl")
include("modelinstance/build.jl")
include("modelinstance/deftimestep_macro.jl")

include("core/references.jl")
include("core/mimi-core.jl")
include("core/defcomp.jl")

include("helpercomponents/marginalmodel.jl")
include("helpercomponents/adder.jl")
include("helpercomponents/connectorcomp.jl")

include("utils/graph.jl")
include("utils/plotting.jl")
include("utils/getdataframe.jl")
include("utils/lint_helper.jl")

end # module
