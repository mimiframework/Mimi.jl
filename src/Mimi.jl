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
    add_shared_param!,
    # components,
    connect_param!,
    create_marginal_model,
    delete_param!,
    dim_count,
    dim_keys,
    dim_key_dict,
    disconnect_param!,
    explore,
    getdataframe,
    gettime,
    get_param_value,
    get_var_value,
    hasvalue,
    is_first,
    is_last,
    is_time, 
    is_timestep,
    modeldef,
    name,
    # parameters,
    parameter_dimensions,
    parameter_names,
    replace_comp!,
    set_dimension!,
    set_leftover_params!,
    set_param!,
    TimestepIndex,
    TimestepValue,
    update_param!,
    update_params!,
    update_leftover_params!,
    # variables,
    variable_dimensions,
    variable_names

include("core/delegate.jl")
include("core/types/includes.jl")
#
# After loading types and delegation macro, the rest can be loaded in any order.
#
include("core/build.jl")
include("core/connections.jl")
include("core/defs.jl")
include("core/defcomp.jl")
include("core/defcomposite.jl")
include("core/dimensions.jl")
include("core/instances.jl")
include("core/references.jl")
include("core/time.jl")
include("core/time_arrays.jl")
include("core/model.jl")
include("core/paths.jl")
include("core/show.jl")

include("mcs/mcs.jl") # need mcs types for explorer and utils
include("explorer/explore.jl")
include("utils/getdataframe.jl")
include("utils/graph.jl")
include("utils/misc.jl")

# Load built-in components
include("components/adder.jl")
include("components/multiplier.jl")
include("components/connector.jl")

end # module
