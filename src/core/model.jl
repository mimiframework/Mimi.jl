#
# User facing struct that unifies a ModelDef and a ModelInstance and delegates
# function calls to one or the other as appropriate.
#
using MacroTools

import Base: delete!

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

@modelegate number_type(m::Model) => md

@modelegate compinstance(m::Model, name::Symbol) => md

@modelegate external_param_conns(m::Model) => md

@modelegate internal_param_conns(m::Model) => md

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

function connect_parameter(m::Model, 
                           dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol;
                           ignoreunits::Bool = false)
    connect_parameter(m.md, dst_comp_name, dst_par_name, src_comp_name, src_var_name; ignoreunits=ignoreunits)
end

"""
    connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol};
                           ignoreunits::Bool = false)
    connect_parameter(m.md, dst[1], dst[2], src[1], src[2], ignoreunits=ignoreunits)
end

# TBD: combine these method signatures by defaulting backup::Union{Void,Array}=nothing

"""
    connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component, using `backup` to provide default values.
"""
function connect_parameter(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Array; ignoreunits::Bool = false)
    connect_parameter(m.md, dst[1], dst[2], src[1], src[2], backup; ignoreunits = ignoreunits)
end

function set_external_param(m::Model, name::Symbol, value::ModelParameter)
    set_external_param(m.md, name, value)
    decache(m)
end

function add_internal_param_conn(m::Model, conn::InternalParameterConnection)
    add_internal_param_conn(m.md, conn)
    decache(m)
end

function set_leftover_params(m::Model, parameters::Dict{String,Any})
    set_leftover_params(m.md, parameters)
    decache(m)
end


function addcomponent(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                      start=nothing, final=nothing, before=nothing, after=nothing)
    addcomponent(m.md, comp_id, comp_name, start=start, final=final, before=before, after=after)
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

@modelegate duration(m::Model) => md

# Return the number of timesteps a given component in a model will run for.
@modelegate getspan(m::Model, comp_name::Symbol) => md

@modelegate indexcounts(m::Model) => md

@modelegate indexcount(m::Model, idx::Symbol) => md

@modelegate indexvalues(m::Model) => md

@modelegate indexvalues(m::Model, idx::Symbol) => md

"""
    _getdatumdef(comp_def::ComponentDef, item::Symbol)

Return a VariableDef or ParameterDef for `item` in the given component.
"""
function _getdatumdef(comp_def::ComponentDef, item::Symbol)
    if haskey(comp_def.variables, item)
        return comp_def.variables[item]

    elseif haskey(comp_def.parameters, item)
        return comp_def.parameters[item]
    else
        error("Cannot access data item; $name is not a variable or a parameter in component $component.")
    end
end

_getdatumdef(m::Model, comp_name::Symbol, item::Symbol) = _getdatumdef(compdef(m.md, comp_name), item)

# _getdatumdef(m::Model, comp_id::ComponentId, item::Symbol) = _getdatumdef(m.md, compdef(comp_id), item)


"""
    indexlabels(m::Model, component::Symbol, name::Symbol)

Return the index labels of the variable or parameter in the given component.
"""
function indexlabels(m::Model, comp_name::Symbol, datum_name::Symbol)
    datum = _getdatumdef(m, comp_name, datum_name)
    return datum.dimensions
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getindex(m.mi, component, name)
end

"""
    setindex(m::Model, name::Symbol, valuerange::Range)

Set the values of `Model`'s index `name` to the values in the given `range`.
"""
function setindex(m::Model, name::Symbol, range::Range)
    setindex(m.md, name, range)
    decache(m)
end

"""
    setindex(m::Model, name::Symbol, count::Int)

Set the values of `Model`'s' index `name` to integers 1 through `count`.
"""
function setindex(m::Model, name::Symbol, count::Int)
    setindex(m.md, name, count)
    decache(m)
end

function setindex{T}(m::Model, name::Symbol, values::Vector{T})
    setindex(m.md, name, values)
    decache(m)
end

@modelegate check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol) => md

@modelegate parameter_dimensions(m::Model, comp_name::Symbol, param_name::Symbol) => md

@modelegate parameter_unit(m::Model, comp_name::Symbol, param_name::Symbol) => md

# TBD: this might not be right...
parameter(m::Model, comp_def::ComponentDef, param_name::Symbol) = parameter(comp_def, param_name)

parameter(m::Model, comp_name::Symbol, param_name::Symbol) = parameter(m, compdef(m, comp_name), param_name)

function parameters(m::Model, comp_name::Symbol)
    comp_def = compdef(m, comp_name)
    return collect(keys(comp_def.parameters))
end

function variable(m::Model, comp_name::Symbol, param_name::Symbol)
    comp_def = compdef(m, comp_id)
    return comp_def.variables[param_name]
end

function variable_unit(m::Model, comp_name::Symbol, param_name::Symbol)
    var = variable(m, comp_id, param_name)
    return var.unit
end

function variable_dimensions(m::Model, comp_name::Symbol, param_name::Symbol)
    var = variable(m, comp_id, param_name)
    return var.dimensions
end

"""
    variables(m::Model, comp_name::Symbol)

List all the variables of `comp_name` in model `m`.
"""
function variables(m::Model, comp_name::Symbol)
    comp_def = compdef(m, comp_name)
    return collect(keys(comp_def.variables))
end


"""
    set_external_array_param(m::Model, name::Symbol, value::AbstractTimestepMatrix, dims)

Adds a one or two dimensional time-indexed array parameter to the model.
"""
function set_external_array_param(m::Model, name::Symbol, value::AbstractTimestepMatrix, dims)
    set_external_array_param(m.md, name, value, dims)
    decache(m)
end

"""
    set_external_array_param(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter to the model.
"""
function set_external_array_param(m::Model, name::Symbol, value::AbstractArray, dims)
    set_external_array_param(m.md, name, value, dims)
    decache(m)
end

"""
    set_external_scalar_param(m::Model, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_param(m::Model, name::Symbol, value::Any)
    set_external_array_param(m.md, name, value)
    decache(m)
end

"""
    delete!(m::ModelDef, component::Symbol

Delete a component by name from a models' ModelDef, and nullify the ModelInstance.
"""
function delete!(m::Model, comp_name::Symbol)
    delete!(m.md, comp_name)
    decache(m)
end

function set_parameter(m::Model, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    set_parameter(m.md, comp_name, param_name, value, dims)    
    decache(m)
end

"""
    run(m::Model)

Run model `m` once.
"""
function run(m::Model; ntimesteps=typemax(Int))
    if numcomponents(m) == 0
        error("Cannot run a model with no components.")
    end

    if m.mi == nothing
        m.mi = build(m)
    end

    println("Running model...")
    run(m.mi, ntimesteps, indexvalues(m))
end
