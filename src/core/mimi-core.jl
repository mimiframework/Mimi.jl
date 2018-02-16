#
# TBD: All of these should become methods of either ModelInstance or ModelDef, with delegation function on m::Model in model.jl
#

"""
    set_external_array_parameter(m::Model, name::Symbol, value::TimestepVector, dims)

Adds a one dimensional time-indexed array parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::TimestepVector, dims)
    p = ArrayModelParameter(value, [:time])
    set_external_parameter(m, name, p)
end

"""
    set_external_array_parameter(m::Model, name::Symbol, value::TimestepMatrix, dims)

Adds a two dimensional time-indexed array parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::TimestepMatrix, dims)
    p = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_parameter(m, name, p)
end

"""
    set_external_array_parameter(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::AbstractArray, dims)
    numtype = number_type(m)

    if !(typeof(value) <: Array{numtype})
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{numtype}(value)
    end
    p = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_parameter(m, name, p)
    # m.external_parameters[name] = p
end

"""
    set_external_scalar_parameter(m::Model, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_parameter(m::Model, name::Symbol, value::Any)
    if typeof(value) <: AbstractArray
        value = convert(Array{m.numberType}, value)
    end
    p = ScalarModelParameter(value)
    set_external_parameter(m, name, p)
    # m.external_parameters[name] = p
end


# Return the number of timesteps a given component in a model will run for.
function getspan(m::Model, comp_id::ComponentId)
    duration = getduration(indexvalues(m))
    ci = comp_instance(m, comp_id)
    start = comp_instance.offset
    final = comp_instance.final
    return Int((final - start) / duration + 1)
end

"""
    update_external_parameter(m::Model, name::Symbol, value)

Update the value of an external model parameter, referenced by name.
"""
function update_external_parameter(m::Model, name::Symbol, value)
    if !(name in keys(m.external_parameters))
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = m.external_parameters[name]

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
    m.mi = Nullable{ModelInstance}()
end

"""
Return list of parameters that have been set for component c in model m.
"""
function get_set_parameters(m::Model, c::ComponentInstance)
    ext_connections = Iterators.filter(x->x.component_name==c.name, m.external_parameter_connections)
    ext_set_params = map(x->x.param_name, ext_connections)

    int_connections = Iterators.filter(x->x.target_component_name==c.name, m.internal_parameter_connections)
    int_set_params = map(x->x.target_parameter_name, int_connections)

    return union(ext_set_params, int_set_params)
end

# TBD: Should this use m, rather the global ComponentDef registry? Why is 'm' passed?
"""
Return a list of all parameter names for a given component in a model m.
"""
function get_parameter_names(m::Model, component::ComponentInstance)
    _dict = compdefs()
    _module = module_name(component.component_type.name.module)
    _metacomponent = _dict[(_module, component.component_type.name.name)]
    return keys(_metacomponent.parameters)
end

# TBD: revise
# returns the {name:parameter} dictionary
function get_parameters(m::Model, component::ComponentInstance)
    return parameters(component.comp_def)
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getindex(get(m.mi), component, name)
end

"""
    getdatum(m::Model, comp_def::ComponentDef, item::Symbol)

Return a VariableDef or ParameterDef for `item` in the given component.
"""
function getdatum(m::Model, comp_def::ComponentDef, item::Symbol)
    if haskey(comp_def.variables, item)
        return comp_def.variables[item]

    elseif haskey(comp_def.parameters, item)
        return comp_def.parameters[item]
    else
        error("Cannot access data item; $name is not a variable or a parameter in component $component.")
    end
end

getdatum(m::Model, comp_name::Symbol, item::Symbol) = getdatum(compdef(m, comp_name), item)

getdatum(m::Model, comp_id::ComponentId, item::Symbol) = getdatum(m, compdef(comp_id), item)


"""
    indexlabels(m::Model, component::Symbol, name::Symbol)

Return the index labels of the variable or parameter in the given component.
"""
function indexlabels(m::Model, comp_name::Symbol, datum_name::Symbol)
    datum = getdatum(m, comp_name, datum_name)
    return datum.dimensions
end

indexlabels(m::Model, comp_id::ComponentId, name::Symbol) = indexlabels(m, compdef(comp_id), name)

# Maybe deprecated; maybe not.
#
# TBD: this seems redundant with, less useful than, and more complicated than indexlabels.
# It also seems to be used only by getdataframe, as is the getdiminfoforvar(), below.
#
# function getvardiminfo(mi::ModelInstance, comp_name::Symbol, var_name::Symbol)
#     if ! haskey(mi.components, comp_name)
#         error("Component $comp_name not found in model")
#     end
#     comp_type = typeof(mi.components[comp_name])

#     meta_module_name    = Symbol(supertype(comp_type).name.module)
#     meta_component_name = Symbol(supertype(comp_type).name.name)

#     vardiminfo = getdiminfoforvar((meta_module_name,meta_compo_name), var_name)
#     return vardiminfo
# end

# function getdiminfoforvar(s, name)
#     defs = compdefs()
#     defs[s].variables[name].dimensions
# end


function run_timestep(anything, p, v, d, t)
    t = typeof(anything)
    println("Generic run_timestep called for $t.")
end

function init(s)
end

function resetvariables(s)
    typeofs = typeof(s)
    println("Generic resetvariables called for $typeofs.")
end

# Deprecated
# Helper function for macro: collects all the keyword arguments in a function call to a dictionary.
# function collectkw(args::Vector{Any})
#     kws = Dict{Symbol, Any}()
#     for arg in args
#         if isa(arg, Expr) && arg.head == :kw
#             kws[arg.args[1]] = arg.args[2]
#         end
#     end

#     kws
# end
