module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    ComponentState, run_timestep, run, @defcomp, Model, setindex, addcomponent, setparameter,
    connectparameter, setleftoverparameters, getvariable, adder, MarginalModel, ConnectorComp, getindex,
    getdataframe, components, variables, getvpd, unitcheck, set_external_parameter, plot, getindexcount,
    getindexvalues, getindexlabels, delete!, get_unconnected_parameters, Timestep, isfirsttimestep,
    isfinaltimestep, OurTVector, OurTMatrix, hasvalue

import
    Base.getindex, Base.run, Base.show

include("clock.jl")
include("ourarrays.jl")
include("mimi-core.jl")
include("metainfo.jl")
include("marginalmodel.jl")
include("adder.jl")
include("connectorcomp.jl")
include("references.jl")
include("plotting.jl")
include("lint_helper.jl")

end # module
