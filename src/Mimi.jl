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
include("core/types/_includes.jl")
#
# After loading types and delegation macro, the rest can be loaded in any order.
#
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
include("core/time_arrays.jl")
include("core/model.jl")
include("core/order.jl")
include("core/paths.jl")
include("core/show.jl")

include("explorer/explore.jl")
include("mcs/mcs.jl")
include("utils/getdataframe.jl")
include("utils/graph.jl")
include("utils/lint_helper.jl")
include("utils/misc.jl")
include("utils/plotting.jl")

# Load built-in components
include("components/adder.jl")
include("components/connector.jl")

end # module
