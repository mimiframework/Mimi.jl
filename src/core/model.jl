#
# User facing struct that unifies a ModelDef and a ModelInstance and delegates
# function calls to one or the other as appropriate.
#
using MacroTools

# Simplify delegation of calls to ::Model to internal ModelInstance or ModelDelegate objects.
macro modelegate(ex)
    if @capture(ex, fname_(varname_::Model, args__) => rhs_)
        result = esc(:($fname($varname::Model, $(args...)) = $fname($varname.$rhs, $(args...))))
        #println(result)
        return result
    end
    error("Calls to @modelegate must be of the form 'func(m::Model, args...) => X', where X is either mi or md'. Expression was: $ex")
end

"""
    modeldef(m)

Return the `ModelDef` contained by Model `m`.
"""
modeldef(m::Model) = m.md

modelinstance(m::Model) = m.mi

@modelegate compinstance(m::Model, name::Symbol) => mi

@modelegate number_type(m::Model) => md

@modelegate external_param_conns(m::Model) => md

@modelegate internal_param_conns(m::Model) => md

@modelegate external_params(m::Model) => md

@modelegate external_param(m::Model, name::Symbol) => md

@modelegate connected_params(m::Model, comp_name::Symbol) => md

@modelegate unconnected_params(m::Model) => md

@modelegate add_connector_comps(m::Model) => md

# Forget any previously built model instance (i.e., after changing the model def).
# This should be called by all functions that modify the Model's underlying ModelDef.
function decache(m::Model)
    m.mi = nothing
end

"""
    connect_param!(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, 
        src_var_name::Symbol, backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst_par_name` of one component `dst_comp_name` of model `md`
to a variable `src_var_name` in another component `src_comp_name` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination 
component parameter should only be calculated for the second timestep and beyond.
"""
function connect_param!(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol, 
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_param!(m.md, dst_comp_name, dst_par_name, src_comp_name, src_var_name, backup; 
                      ignoreunits=ignoreunits, offset=offset)
end

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
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_param!(m.md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

function disconnect_param!(m::Model, comp_name::Symbol, param_name::Symbol)
    disconnect_param!(m.md, comp_name, param_name)
    decache(m)
end

function set_external_param!(m::Model, name::Symbol, value::ModelParameter)
    set_external_param!(m.md, name, value)
    decache(m)
end

function set_external_param!(m::Model, name::Symbol, value::Number; param_dims::Union{Void,Array{Symbol}} = nothing)
    set_external_param!(m.md, name, value; param_dims = param_dims)
    decache(m)
end

function set_external_param!(m::Model, name::Symbol, value::Union{AbstractArray, Range, Tuple}; param_dims::Union{Void,Array{Symbol}} = nothing)
    set_external_param!(m.md, name, value; param_dims = param_dims)
end

function add_internal_param_conn(m::Model, conn::InternalParameterConnection)
    add_internal_param_conn(m.md, conn)
    decache(m)
end

function set_leftover_params!(m::Model, parameters::Dict{T, Any}) where T
    set_leftover_params!(m.md, parameters)
    decache(m)
end

"""
    add_comp!(m::Model, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name;
        first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the model indicated by `m`. The component is added at the end of 
the list unless one of the keywords, `first`, `last`, `before`, `after`. If the `comp_name`
differs from that in the `comp_id`, a copy of `comp_id` is made and assigned the new name.
"""
function add_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                      first=nothing, last=nothing, before=nothing, after=nothing)
    add_comp!(m.md, comp_id, comp_name; first=first, last=last, before=before, after=after)
    decache(m)
    return ComponentReference(m, comp_name)
end

"""
    replace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        first::VoidSymbol=nothing, last::VoidSymbol=nothing,
        before::VoidSymbol=nothing, after::VoidSymbol=nothing)
        
Replace the component with name `comp_name` in model `md`  with the component
`comp_id` using the same name.  
"""
function replace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                           first::VoidSymbol=nothing, last::VoidSymbol=nothing,
                           before::VoidSymbol=nothing, after::VoidSymbol=nothing,
                           reconnect=true)
    replace_comp!(m.md, comp_id, comp_name; first=first, last=last, before=before, after=after, reconnect=reconnect)
    decache(m)
    return ComponentReference(m, comp_name)
end

"""
    components(m::Model)

Return an iterator on the components in model `m`.
"""
@modelegate components(m::Model) => mi

@modelegate compdefs(m::Model) => md

@modelegate compdef(m::Model, comp_name::Symbol) => md

@modelegate numcomponents(m::Model) => md

@modelegate first_and_step(m::Model) => md

@modelegate time_labels(m::Model) => md

# Return the number of timesteps a given component in a model will run for.
@modelegate getspan(m::Model, comp_name::Symbol) => md

"""
    datumdef(comp_def::ComponentDef, item::Symbol)

Return a DatumDef for `item` in the given component `comp_def`.
"""
function datumdef(comp_def::ComponentDef, item::Symbol)
    if haskey(comp_def.variables, item)
        return comp_def.variables[item]

    elseif haskey(comp_def.parameters, item)
        return comp_def.parameters[item]
    else
        error("Cannot access data item; :$item is not a variable or a parameter in component $(comp_def.comp_id).")
    end
end

datumdef(m::Model, comp_name::Symbol, item::Symbol) = datumdef(compdef(m.md, comp_name), item)

"""
    dimensions(m::Model, comp_name::Symbol, datum_name::Symbol)

Return the dimension names for the variable or parameter `datum_name`
in the given component `comp_name` in model `m`.
"""
dimensions(m::Model, comp_name::Symbol, datum_name::Symbol) = dimensions(compdef(m, comp_name), datum_name)

@modelegate dimension(m::Model, dim_name::Symbol) => md

# Allow access of the form my_model[:grosseconomy, :tfp]
@modelegate Base.getindex(m::Model, comp_name::Symbol, datum_name::Symbol) => mi

"""
    set_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, Range})

Set the values of `m` dimension `name` to integers 1 through `count`, if `keys`` is
an integer; or to the values in the vector or range if `keys`` is either of those types.
"""
function set_dimension!(m::Model, name::Symbol, keys::Union{Int, Vector, Tuple, Range})
    set_dimension!(m.md, name, keys)
    decache(m)
end

@modelegate check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol) => md

@modelegate parameter_names(m::Model, comp_name::Symbol) => md

@modelegate parameter_dimensions(m::Model, comp_name::Symbol, param_name::Symbol) => md

@modelegate parameter_unit(m::Model, comp_name::Symbol, param_name::Symbol) => md

parameter(m::Model, comp_def::ComponentDef, param_name::Symbol) = parameter(comp_def, param_name)

parameter(m::Model, comp_name::Symbol, param_name::Symbol) = parameter(m, compdef(m, comp_name), param_name)

"""
    parameters(m::Model, comp_name::Symbol)

Return a list of the parameter definitions for `comp_name` in model `m`.
"""
parameters(m::Model, comp_name::Symbol) = parameters(compdef(m, comp_name))

function variable(m::Model, comp_name::Symbol, var_name::Symbol)
    comp_def = compdef(m, comp_name)
    return comp_def.variables[var_name]
end

function variable_unit(m::Model, comp_name::Symbol, var_name::Symbol)
    var = variable(m, comp_id, var_name)
    return var.unit
end

function variable_dimensions(m::Model, comp_name::Symbol, var_name::Symbol)
    var = variable(m, comp_id, var_name)
    return var.dimensions
end

"""
    variables(m::Model, comp_name::Symbol)

Return a list of the variable definitions for `comp_name` in model `m`.
"""
variables(m::Model, comp_name::Symbol) = variables(compdef(m, comp_name))

@modelegate variable_names(m::Model, comp_name::Symbol) => md

"""
    set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims)

Add a one or two dimensional (optionally, time-indexed) array parameter `name` 
with value `value` to the model `m`.
"""
function set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims)
    set_external_array_param!(m.md, name, value, dims)
    decache(m)
end

"""
    set_external_scalar_param!(m::Model, name::Symbol, value::Any)

Add a scalar type parameter `name` with value `value` to the model `m`.
"""
function set_external_scalar_param!(m::Model, name::Symbol, value::Any)
    set_external_scalar_param!(m.md, name, value)
    decache(m)
end

"""
    delete!(m::ModelDef, component::Symbol

Delete a `component`` by name from a model `m`'s ModelDef, and nullify the ModelInstance.
"""
function Base.delete!(m::Model, comp_name::Symbol)
    delete!(m.md, comp_name)
    decache(m)
end

"""
    set_param!(m::Model, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter of a component `comp_name` in a model `m` to a given `value`. 
The `value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' 
is a list of the dimension names of the provided data, and will be used to check 
that they match the model's index labels.
"""
function set_param!(m::Model, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    set_param!(m.md, comp_name, param_name, value, dims)    
    decache(m)
end

"""
    run(m::Model)

Run model `m` once.
"""
function Base.run(m::Model; ntimesteps::Int=typemax(Int), 
                  dim_keys::Union{Void, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
    if numcomponents(m) == 0
        error("Cannot run a model with no components.")
    end

    if m.mi == nothing
        build(m)
    end

    # println("Running model...")
    run(m.mi, ntimesteps, dim_keys)
    nothing
end

#
# TBD: This function is currently used only in test/test_parametertypes. Is it still needed?
#
"""
    update_external_param(m::Model, name::Symbol, value)

Update the `value` of an external model parameter in model `m`, referenced by `name`.
"""
function update_external_param(m::Model, name::Symbol, value)
    ext_params = external_params(m)
    if ! haskey(ext_params, name)
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = ext_params[name]

    if isa(param, ScalarModelParameter)
        if ! (value isa typeof(param.value))
            try
                value = convert(typeof(param.value), value)
            catch e
                error("Cannot update parameter $name; expected type $(typeof(param.value)) but got $(typeof(value)).")
            end
        elseif size(value) != size(param.value)
            error("Cannot update parameter $name; expected array of size $(size(param.value)) but got array of size $(size(value)).")
        else
            param.value = value
        end

    else # ArrayModelParameter
        if !(typeof(value) <: AbstractArray)
            error("Cannot update an array parameter $name with a scalar value.")
        elseif size(value) != size(param.values)
            error("Cannot update parameter $name; expected array of size $(size(param.values)) but got array of size $(size(value)).")
        elseif !(eltype(value) <: eltype(param.values))
            try
                value = convert(Array{eltype(param.values)}, value)
            catch e
                error("Cannot update parameter $name; expected array of type $(eltype(param.values)) but got $(eltype(value)).")
            end
        else # perform the update
            if param.values isa TimestepArray
                param.values.data = value
            else
                param.values = value
            end
        end
    end
    decache(m)
end
