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


modeldef(m::Model) = m.md

modelinstance(m::Model) = m.mi

@modelegate compinstance(m::Model, name::Symbol) => mi

@modelegate number_type(m::Model) => md

@modelegate external_param_conns(m::Model) => md

@modelegate internal_param_conns(m::Model) => md

@modelegate external_params(m::Model) => md

@modelegate external_param(m::Model, name::Symbol) => md

@modelegate external_param_values(m::Model, name::Symbol) => md

@modelegate connected_params(m::Model, comp_name::Symbol) => md

@modelegate unconnected_params(m::Model) => md

@modelegate add_connector_comps(m::Model) => md

# Forget any previously built model instance (i.e., after changing the model def).
# This should be called by all functions that modify the Model's underlying ModelDef.
function decache(m::Model)
    m.mi = nothing
end

function connect_parameter(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol, 
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_parameter(m.md, dst_comp_name, dst_par_name, src_comp_name, src_var_name, backup; 
                      ignoreunits=ignoreunits, offset=offset)
end

"""
    connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component, using `backup` to provide default values.
"""
function connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_parameter(m.md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

function set_external_param!(m::Model, name::Symbol, value::ModelParameter)
    set_external_param!(m.md, name, value)
    decache(m)
end

function add_internal_param_conn(m::Model, conn::InternalParameterConnection)
    add_internal_param_conn(m.md, conn)
    decache(m)
end

function set_leftover_params!(m::Model, parameters::Dict{String,Any})
    set_leftover_params!(m.md, parameters)
    decache(m)
end


function addcomponent(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                      start=nothing, stop=nothing, before=nothing, after=nothing)
    addcomponent(m.md, comp_id, comp_name, start=start, stop=stop, before=before, after=after)
    decache(m)
    return ComponentReference(m, comp_name)
end

"""
    components(m::Model)

List all the components in model `m`.
"""
@modelegate compdefs(m::Model) => md

@modelegate compdef(m::Model, comp_name::Symbol) => md

@modelegate numcomponents(m::Model) => md

@modelegate timelabels(m::Model) => md

@modelegate step_size(m::Model) => md

# Return the number of timesteps a given component in a model will run for.
@modelegate getspan(m::Model, comp_name::Symbol) => md

"""
    datumdef(comp_def::ComponentDef, item::Symbol)

Return a DatumDef for `item` in the given component.
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
    dimensions(m::Model, comp_def::ComponentDef, datum_name::Symbol)

Return the dimension names for the variable or parameter in the given component.
"""
dimensions(m::Model, comp_def::ComponentDef, datum_name::Symbol) = dimensions(datumdef(comp_def, datum_name))

"""
    dimensions(m::Model, comp_name::Symbol, datum_name::Symbol)

Return the dimension names for the variable or parameter in the given component.
"""
dimensions(m::Model, comp_name::Symbol, datum_name::Symbol) = dimensions(m, compdef(m, comp_name), datum_name)

@modelegate dimension(m::Model, dim_name::Symbol) => md

# TBD: this allows access of the form my_model[:grosseconomy, :tfp]
# It is not related to indices or dimensions.
@modelegate Base.getindex(m::Model, comp_name::Symbol, datum_name::Symbol) => mi

"""
    set_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, Range})

Set the values of `Model` dimension `name` to integers 1 through `count`, if keys is
an integer; or to the values in the vector or range if keys is either of those types.
"""
function set_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, Range})
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
    set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, AbstractTimestepMatrix}, dims)

Adds a one or two dimensional (optionally, time-indexed) array parameter to the model.
"""
function set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, AbstractTimestepMatrix}, dims)
    set_external_array_param!(m.md, name, value, dims)
    decache(m)
end

"""
    set_external_scalar_param!(m::Model, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_param!(m::Model, name::Symbol, value::Any)
    set_external_array_param!(m.md, name, value)
    decache(m)
end

"""
    delete!(m::ModelDef, component::Symbol

Delete a component by name from a models' ModelDef, and nullify the ModelInstance.
"""
function Base.delete!(m::Model, comp_name::Symbol)
    delete!(m.md, comp_name)
    decache(m)
end

function set_parameter!(m::Model, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    set_parameter!(m.md, comp_name, param_name, value, dims)    
    decache(m)
end

"""
    run(m::Model)

Run model `m` once.
"""
function Base.run(m::Model; ntimesteps=typemax(Int), dim_keys::Union{Void, Dict}=nothing)
    if numcomponents(m) == 0
        error("Cannot run a model with no components.")
    end

    if m.mi == nothing
        m.mi = build(m)
    end

    # println("Running model...")
    # run(m.mi, ntimesteps, indexvalues(m))
    run(m.mi, ntimesteps, dim_keys)
end

#
# TBD: This function is not currently used anywhere (and not tested!) Is it still needed?
#
"""
    update_external_param(m::Model, name::Symbol, value)

Update the value of an external model parameter, referenced by name.
"""
function update_external_param(m::Model, name::Symbol, value)
    if !(name in keys(m.external_params))
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = m.external_params[name]

    if isa(param, ScalarModelParameter)
        if !(typeof(value) <: typeof(param.value))
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
            if isa(param.values, TimestepVector) || isa(param.values, TimestepMatrix)
                param.values.data = value
            else
                param.values = value
            end
        end
    end
    m.mi = nothing
end
