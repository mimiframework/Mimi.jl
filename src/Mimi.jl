module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    ComponentState, run_timestep, run, @defcomp, Model, setindex, addcomponent, setparameter,
    connectparameter, setleftoverparameters, getvariable, adder, MarginalModel, getindex,
    getdataframe, components, variables, getvpd, unitcheck, addparameter, plot, getindexcount,
    getindexvalues, getindexlabels, get_unconnected_parameters

import
    Base.getindex, Base.run, Base.show

include("mimi-core.jl")
include("metainfo.jl")
include("clock.jl")
include("marginalmodel.jl")
include("adder.jl")
include("references.jl")
include("plotting.jl")
include("lint_helper.jl")

end # module
