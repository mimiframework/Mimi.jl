__precompile__()

module Mimi

using DataFrames
using DataStructures
using Distributions
using Electron
using JSON 
using LightGraphs
using MetaGraphs
using NamedArrays

export
    @defcomp,
    @modelegate, # Don't export
    MarginalModel,
    Model,
    addcomponent, # push!, add_component!, add_component, addcomp!, add!; could also have multiple functions like insert!, push! etc. instead of before after keywords
    add_connector_comps, # Don't export
    add_dimension, # Don't export
    addparameter, # Don't export
    compdef, # Don't export
    compdefs, # Don't export
    compinstance, # Don't export
    compkeys, # Don't export
    components,
    connect_parameter, # connect!, bind, assign, link; ! yes or no; frontrunner: connect!
    create_marginal_model,
    datatype, # Don't export
    description, # Don't export
    dimension, # Don't export
    dimensions, # Don't export
    disconnect!, # disconnect_parameter!; frontrunner: disconnect!
    explore,
    getdataframe, # Table for now
    getproperty, # Don't export
    get_parameter_value, # Don't export
    get_variable_value, # Don't export
    interpolate, # Don't export, move to contrib or something
    load_comps, # Don't export
    modeldef, # Don't export
    name, # Don't export
    new_component, # Don't export
    parameters,
    # plot,
    # plot_comp_graph,
    replace_component, # Add !, comp vs, component, replace!
    run_timestep, # Don't export
    set_dimension!, # Think hard about axis-dimension-index-blabla
    set_leftover_params!, # Rethink in general
    set_parameter!, # Just make parameter match other parts
    setproperty!, # Don't export
    unit, # Don't export
    variables # Just make sure it matches vars vs variables

    # delete! for comps

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
# include("utils/plotting.jl")
include("utils/getdataframe.jl")
include("utils/lint_helper.jl")
include("utils/misc.jl")

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
