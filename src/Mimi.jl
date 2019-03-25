module Mimi

using Classes
using DataFrames
using DataStructures
using Distributions
using Electron
using JSON 
using NamedArrays
using StringBuilders

export
    @defcomp,
    @defsim,
    @defcomposite,
    MarginalModel,
    Model,
    add_comp!,
    components,
    connect_param!,
    create_marginal_model,
    dim_count,
    dim_keys,
    dim_key_dict,
    disconnect_param!,
    explore,
    getdataframe, 
    generate_trials!,
    gettime,
    get_param_value,
    get_var_value,
    hasvalue,
    is_first,
    is_last,
    is_time,
    is_timestep,
    load_comps,
    modeldef,
    name,
    parameters, 
    parameter_dimensions,
    parameter_names,
    plot_comp_graph,
    replace_comp!, 
    run_sim,
    set_dimension!, 
    set_leftover_params!, 
    set_models!,
    set_param!, 
    update_param!,
    update_params!,
    variables,
    variable_dimensions,
    variable_names

include("core/delegate.jl")
include("core/types.jl")

# After loading types and delegation macro, the rest is alphabetical
include("core/build.jl")
include("core/connections.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/defmodel.jl")
include("core/defcomposite.jl")
include("core/dimensions.jl")
include("core/instances.jl")
include("core/references.jl")
include("core/time.jl")
include("core/model.jl")
include("core/show.jl")

# For debugging composites we don't need these
include("explorer/explore.jl")
include("mcs/mcs.jl")
include("utils/getdataframe.jl")
include("utils/graph.jl")
include("utils/lint_helper.jl")
include("utils/misc.jl")
include("utils/plotting.jl")

"""
    load_comps(dirname::String="./components")

Call include() on all the files in the indicated directory `dirname`.
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
    compdir = joinpath(@__DIR__, "components")
    load_comps(compdir)
end

end # module
