#
# User facing struct that unifies a ModelDef and a ModelInstance and delegates
# function calls to one or the other as appropriate.
#
using MacroTools

"""
    modeldef(m)

Return the `ModelDef` contained by Model `m`.
"""
modeldef(m::Model) = m.md

modelinstance(m::Model) = m.mi
modelinstance_def(m::Model) = modeldef(modelinstance(m))

is_built(m::Model) = !(dirty(m.md) || modelinstance(m) === nothing)

@delegate compinstance(m::Model, name::Symbol) => mi
@delegate has_comp(m::Model, name::Symbol) => md

@delegate number_type(m::Model) => md

@delegate internal_param_conns(m::Model) => md
@delegate external_param_conns(m::Model) => md

@delegate external_params(m::Model) => md
@delegate external_param(m::Model, name::Symbol; missing_ok=false) => md

@delegate connected_params(m::Model) => md
@delegate unconnected_params(m::Model) => md

@delegate add_connector_comps(m::Model) => md

"""
    connect_param!(m::Model, dst_comp_path::ComponentPath, dst_par_name::Symbol, src_comp_path::ComponentPath, 
        src_var_name::Symbol, backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst_par_name` of one component `dst_comp_path` of model `md`
to a variable `src_var_name` in another component `src_comp_path` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination 
component parameter should only be calculated for the second timestep and beyond.
"""
@delegate connect_param!(m::Model, 
                         dst_comp_path::ComponentPath, dst_par_name::Symbol, 
                         src_comp_path::ComponentPath, src_var_name::Symbol, 
                         backup::Union{Nothing, Array}=nothing; 
                         ignoreunits::Bool=false, offset::Int=0) => md

@delegate connect_param!(m::Model, 
                         dst_comp_name::Symbol, dst_par_name::Symbol, 
                         src_comp_name::Symbol, src_var_name::Symbol,
                         backup::Union{Nothing, Array}=nothing; 
                         ignoreunits::Bool=false, offset::Int=0) => md

"""
    connect_param!(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)

Bind the parameter `dst[2]` of one component `dst[1]` of model `md`
to a variable `src[2]` in another component `src[1]` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination 
component parameter should only be calculated for the second timestep and beyond.

"""
function connect_param!(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Union{Nothing, Array}=nothing; 
                           ignoreunits::Bool=false, offset::Int=0)
    connect_param!(m.md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

@delegate disconnect_param!(m::Model, comp_path::ComponentPath, param_name::Symbol) => md
@delegate disconnect_param!(m::Model, comp_name::Symbol, param_name::Symbol) => md

@delegate set_external_param!(m::Model, name::Symbol, value::ModelParameter) => md

@delegate set_external_param!(m::Model, name::Symbol, value::Number; 
                              param_dims::Union{Nothing,Array{Symbol}} = nothing) => md

@delegate set_external_param!(m::Model, name::Symbol, value::Union{AbstractArray, AbstractRange, Tuple}; 
                              param_dims::Union{Nothing,Array{Symbol}} = nothing) => md

@delegate add_internal_param_conn!(m::Model, conn::InternalParameterConnection) => md

# @delegate doesn't handle the 'where T' currently. This is the only instance of it for now...
function set_leftover_params!(m::Model, parameters::Dict{T, Any}) where T
    set_leftover_params!(m.md, parameters)
end

"""
    update_param!(m::Model, name::Symbol, value; update_timesteps = false)

Update the `value` of an external model parameter in model `m`, referenced by 
`name`. Optional boolean argument `update_timesteps` with default value `false` 
indicates whether to update the time keys associated with the parameter values 
to match the model's time index.
"""
@delegate update_param!(m::Model, name::Symbol, value; update_timesteps = false) => md

"""
    update_params!(m::Model, parameters::Dict{T, Any}; update_timesteps = false) where T

For each (k, v) in the provided `parameters` dictionary, `update_param!`` 
is called to update the external parameter by name k to value v, with optional 
Boolean argument update_timesteps. Each key k must be a symbol or convert to a
symbol matching the name of an external parameter that already exists in the 
model definition.
"""
@delegate update_params!(m::Model, parameters::Dict; update_timesteps = false) => md

"""
    add_comp!(m::Model, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name;
              exports=nothing, first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the model indicated by `m`. The component is added at the end of 
the list unless one of the keywords, `first`, `last`, `before`, `after`. If the `comp_name`
differs from that in the `comp_id`, a copy of `comp_id` is made and assigned the new name.
"""
function add_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name; kwargs...)
    comp_def = add_comp!(m.md, comp_id, comp_name; kwargs...)
    return ComponentReference(m.md, comp_name)
end

function add_comp!(m::Model, comp_def::ComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name; kwargs...)
    return add_comp!(m, comp_def.comp_id, comp_name; kwargs...)
end

"""
    replace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        first::NothingSymbol=nothing, last::NothingSymbol=nothing,
        before::NothingSymbol=nothing, after::NothingSymbol=nothing,
        reconnect::Bool=true)
        
Replace the component with name `comp_name` in model `m` with the component
`comp_id` using the same name.  The component is added in the same position as 
the old component, unless one of the keywords `before` or `after` is specified.
The component is added with the same first and last values, unless the keywords 
`first` or `last` are specified. Optional boolean argument `reconnect` with 
default value `true` indicates whether the existing parameter connections 
should be maintained in the new component.  
"""
function replace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name; kwargs...)
    comp_def = replace_comp!(m.md, comp_id, comp_name; kwargs...)
    return ComponentReference(m.md, comp_name)
end

function replace_comp!(m::Model, comp_def::ComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name; kwargs...)
    return replace_comp!(m, comp_def.comp_id, comp_name; kwargs...)
end

@delegate ComponentReference(m::Model, name::Symbol) => md

"""
    components(m::Model)

Return an iterator on the components in a model's model instance.
"""
@delegate components(m::Model) => mi

@delegate compdefs(m::Model) => md

@delegate compdef(m::Model, comp_name::Symbol) => md

@delegate numcomponents(m::Model) => md

@delegate first_and_step(m::Model) => md

@delegate time_labels(m::Model) => md

# Return the number of timesteps a given component in a model will run for.
@delegate getspan(m::Model, comp_name::Symbol) => md

"""
    datumdef(comp_def::ComponentDef, item::Symbol)

Return a DatumDef for `item` in the given component `comp_def`.
"""
function datumdef(comp_def::ComponentDef, item::Symbol)
    if has_variable(comp_def, item)
        return variable(comp_def, item)

    elseif has_parameter(comp_def, item)
        return parameter(comp_def, item)
    else
        error("Cannot access data item; :$item is not a variable or a parameter in component $(comp_def.comp_id).")
    end
end

datumdef(m::Model, comp_name::Symbol, item::Symbol) = datumdef(compdef(m.md, comp_name), item)

"""
    dim_names(m::Model, comp_name::Symbol, datum_name::Symbol)

Return the dimension names for the variable or parameter `datum_name`
in the given component `comp_name` in model `m`.
"""
dim_names(m::Model, comp_name::Symbol, datum_name::Symbol) = dim_names(compdef(m, comp_name), datum_name)

@delegate dimension(m::Model, dim_name::Symbol) => md

# Allow access of the form my_model[:grosseconomy, :tfp]
@delegate Base.getindex(m::Model, comp_name::Symbol, datum_name::Symbol) => mi

"""
    dim_count(m::Model, dim_name::Symbol)
    
Return the size of index `dim_name` in model `m`.
"""
@delegate dim_count(m::Model, dim_name::Symbol) => md
@delegate dim_counts(m::Model, dims::Vector{Symbol}) => md
@delegate dim_count_dict(m::Model) => md

"""
    dim_keys(m::Model, dim_name::Symbol)
    
Return keys for dimension `dim-name` in model `m`.
"""
@delegate dim_keys(m::Model, dim_name::Symbol) => md
"""
    dim_key_dict(m::Model)
    
Return a dict of dimension keys for all dimensions in model `m`.
"""
@delegate dim_key_dict(m::Model) => md
"""
    dim_values(m::Model, name::Symbol)
    
Return values for dimension `name` in Model `m`.
"""
@delegate dim_values(m::Model, name::Symbol) => md
"""
    dim_value_dict(m::Model)
    
Return a dictionary of the values of all dimensions in Model `m`.
"""
@delegate dim_value_dict(m::Model) => md
"""
    set_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, AbstractRange})

Set the values of `m` dimension `name` to integers 1 through `count`, if `keys`` is
an integer; or to the values in the vector or range if `keys`` is either of those types.
"""
@delegate set_dimension!(m::Model, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange}) => md

@delegate set_run_period!(m::Model, first, last) => md

@delegate check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol) => md

@delegate parameter_names(m::Model, comp_name::Symbol) => md

@delegate parameter_dimensions(m::Model, comp_name::Symbol, param_name::Symbol) => md

@delegate parameter_unit(m::Model, comp_name::Symbol, param_name::Symbol) => md

parameter(m::Model, comp_def::ComponentDef, param_name::Symbol) = parameter(comp_def, param_name)

parameter(m::Model, comp_name::Symbol, param_name::Symbol) = parameter(m, compdef(m, comp_name), param_name)

"""
    parameters(m::Model, comp_name::Symbol)

Return a list of the parameter definitions for `comp_name` in model `m`.
"""
parameters(m::Model, comp_name::Symbol) = parameters(compdef(m, comp_name))

variable(m::Model, comp_name::Symbol, var_name::Symbol) = variable(compdef(m, comp_name), var_name)

@delegate variable_unit(m::Model, comp_path::ComponentPath, var_name::Symbol) => md

@delegate variable_dimensions(m::Model, comp_path::ComponentPath, var_name::Symbol) => md

"""
    variables(m::Model, comp_name::Symbol)

Return an iterator on the variable definitions for `comp_name` in model `m`.
"""
variables(m::Model, comp_name::Symbol) = variables(compdef(m, comp_name))

@delegate variable_names(m::Model, comp_name::Symbol) => md

"""
    set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims)

Add a one or two dimensional (optionally, time-indexed) array parameter `name` 
with value `value` to the model `m`.
"""
@delegate set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims) => md

"""
    set_external_scalar_param!(m::Model, name::Symbol, value::Any)

Add a scalar type parameter `name` with value `value` to the model `m`.
"""
@delegate set_external_scalar_param!(m::Model, name::Symbol, value::Any) => md

"""
    delete!(m::Model, component::Symbol

Delete a `component`` by name from a model `m`'s ModelDef, and nullify the ModelInstance.
"""
@delegate Base.delete!(m::Model, comp_name::Symbol) => md

"""
    set_param!(m::Model, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter of a component `comp_name` in a model `m` to a given `value`. 
The `value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' 
is a list of the dimension names of the provided data, and will be used to check 
that they match the model's index labels.
"""
@delegate set_param!(m::Model, comp_name::Symbol, param_name::Symbol, value, dims=nothing) => md

"""
    set_param!(m::Model, path::AbstractString, param_name::Symbol, value, dims=nothing)

Set a parameter for a component with the given relative path (as a string), in which "/x" means the
component with name `:x` beneath `m.md`. If the path does not begin with "/", it is treated as 
relative to `m.md`, which at the top of the hierarchy, produces the same result as starting with "/".
"""
@delegate set_param!(m::Model, path::AbstractString, param_name::Symbol, value, dims=nothing) => md

"""
    run(m::Model)

Run model `m` once.
"""
function Base.run(m::Model; ntimesteps::Int=typemax(Int), rebuild::Bool=false,
                  dim_keys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
    if numcomponents(m) == 0
        error("Cannot run a model with no components.")
    end

    if (rebuild || ! is_built(m))
        build(m)
    end

    # println("Running model...")
    mi = modelinstance(m)
    run(mi, ntimesteps, dim_keys)
    nothing
end
