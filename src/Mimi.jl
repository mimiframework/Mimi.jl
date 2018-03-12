__precompile__(false)

module Mimi

using DataStructures
using DataFrames
using Distributions
using NamedArrays
using JSON 
using Electron

export
    @defcomp,
    @defmodel,
    @modelegate,
    MarginalModel,
    Model,
    addcomponent,
    add_dimension,
    addparameter,
    compdef,
    compdefs,
    compinstance,
    compkeys,
    components,
    datatype,
    delete!,
    description,
    dimensions,
    explore,
    getdataframe,
    get_parameter_value,
    get_variable_value,
    load_comps,
    modeldef,
    name,
    new_component,
    parameters,
    plot,
    run,
    set_dimension,
    set_leftover_params,
    set_parameter,
    unit,
    variables

import
    Base.getindex, Base.run, Base.show

include("core/types.jl")

# After loading types and macros, the rest can just be alphabetical
include("core/build.jl")
include("core/connections.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/dimensions.jl")
include("core/instances.jl")
include("core/references.jl")
include("core/time.jl")
include("core/model.jl")
include("explorer/explore.jl")
include("mcs/mcs.jl")
include("utils/graph.jl")
include("utils/plotting.jl")
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
