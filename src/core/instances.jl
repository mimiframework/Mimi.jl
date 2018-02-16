#
# Functions pertaining to instantiated models and their components
#

#
# Support for dot-overloading in run_timestep functions
#
function _index_pos(names, propname, var_or_par)
    index_pos = findfirst(names, propname)
    index_pos == 0 && error("Unknown $var_or_par name $propname.")
    return index_pos
end

function _property_expr(obj::ComponentInstanceData, types, index_pos)
    if types.parameters[index_pos] <: Ref
        return :(obj.values[$index_pos][])
    else
        return :(obj.values[$index_pos])
    end
end

@generated function getproperty(obj::ComponentInstanceParameters{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "parameter")
    return _property_expr(obj, TYPES, index_pos)
end

@generated function getproperty(obj::ComponentInstanceVariables{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "variable")
    return _property_expr(obj, TYPES, index_pos)
end

@generated function setproperty!(v::ComponentInstanceVariables{NAMES,TYPES}, 
                                  ::Val{PROPERTYNAME}, value) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "variable")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.values[$index_pos][] = value)
    else
        error("You cannot override indexed variable $PROPERTYNAME.")
    end
end

# Convenience functions that can be called with a name symbol rather than Val(name)
function getproperty(obj::ComponentInstanceParameters{NAMES,TYPES}, name::Symbol) where {NAMES,TYPES}
    return getproperty(obj, Val(name))
end

function getproperty(obj::ComponentInstanceVariables{NAMES,TYPES}, name::Symbol) where {NAMES,TYPES}
    return getproperty(obj, Val(name))
end

function setproperty!(obj::ComponentInstanceVariables{NAMES,TYPES}, name::Symbol, value) where {NAMES,TYPES}
    return setproperty!(obj, Val(name), value)
end


get_parameter_value(ci::AbstractComponentInstance, name::Symbol) = getproperty(ci.pars, Val(name))

get_variable_value(ci::AbstractComponentInstance, name::Symbol)  = getproperty(ci.vars, Val(name))

set_variable_value(ci::AbstractComponentInstance, name::Symbol, value) = setproperty!(ci.vars, Val(name), value)

function getduration(index_values)
    values = index_values[:time]
    # N.B. assumes that all timesteps of the model are the same length
    return length(values) > 1 ? values[2] - values[1] : 1
end

#
# TBD: relationship between ComponentInstanceVariable/Parameter and connection parameters isn't clear
#
# Allow values to be obtained from either parameter type using
# one method name.
getvalue(param::ScalarModelParameter) = param.value

getvalue(param::ArrayModelParameter) = param.values


comp_instance(mi::ModelInstance, comp_id::ComponentId) = mi.components[comp_id]

# TBD: move all int/ext parameter stuff to ModelDef
external_parameter_connections(mi::ModelInstance) = mi.external_parameter_connections

internal_parameter_connections(mi::ModelInstance) = mi.internal_parameter_connections

external_parameter(mi::ModelInstance, name::Symbol) = mi.external_parameters[name]

external_parameter_values(mi::ModelInstance, name::Symbol) = mi.external_parameters[name].values


function add_internal_parameter_conn(mi::ModelInstance, conn::InternalParameterConnection)
    push!(mi.internal_parameter_connections, conn)
end

function set_external_parameter(mi::ModelInstance, name::Symbol, value::ModelParameter)
    mi.external_parameters[name] = value
end

"""
    components(mi::ModelInstance)

Return an iterator on the components in model instance `mi`.
"""
components(mi::ModelInstance) = values(mi.components)

getcomponent(mi::ModelInstance, comp_id::ComponentId) = mi.components[comp_id]

numcomponents(mi::ModelInstance) = length(mi.components)

"""
variables(mi::ModelInstance, componentname::Symbol)

List all the variables of `componentname` in the ModelInstance 'mi'.
NOTE: this variables function does NOT take in Nullable instances
"""
function variables(mi::ModelInstance, comp_id::ComponentId)
    ci = mi.components[comp_id]
    return variables(ci)
end

function getindex(mi::ModelInstance, comp_name::Symbol, name::Symbol)
    if !(comp_name in keys(mi.components))
        error("Component does not exist in current model")
    end
    
    comp_def = getcomp(mi, comp_name)
    vars = comp_def.vars
    pars = comp_def.pars

    if name in pars.names
        value = getproperty(pars, Val(name))
        return isa(value, PklVector) || isa(v.value, TimestepMatrix) ? value.data : value

    elseif name in vars.names
        value = getproperty(vars, Val(name))
        return isa(value, TimestepVector) || isa(value, TimestepMatrix) ? value.data : value

    else
        error("$name is not a parameter or a variable in component $comp_name.")
    end
end

# TBD: not called. Did I delete something?
function update_scalar_parameters(mi::ModelInstance, comp_name::Symbol)
    for conn in get_connections(mi, comp_name, :incoming)
        target = compdef(mi, conn.target_component_name)
        source = compdef(mi, conn.source_component_name)
        setproperty!(target.vars, Val(conn.target_parameter_name), 
                     getproperty(source.vars, Val(conn.source_variable_name)))
    end
end

"""
    indexcount(mi::ModelInstance, idx::Symbol)

Returns the size of index `idx`` in model instance `mi`.
"""
indexcount(mi::ModelInstance, idx::Symbol) = mi.index_counts[idx]

"""
    indexvalues(m::Model, i::Symbol)

Return the values of index i in model m.
"""
indexvalues(mi::ModelInstance, idx::Symbol) = mi.index_values[idx]


function instantiate(comp_def::ComponentDef, par_values, var_values)
    vars = variables(comp_def)
    pars = parameters(comp_def)

    # TBD: could store these types for faster instantiation in multi-trial analyses]
    pnames = map(obj -> obj.name, pars)
    vnames = map(obj -> obj.name, vars)
    ptypes = map(obj -> obj.datatype, pars)
    vtypes = map(obj -> obj.datatype, vars)

    pars_type = ComponentInstanceVariables{pnames, ptypes}
    vars_type = ComponentInstanceParameters{vnames, vtypes}

    ci = ComponentInstance{vars_type, pars_type}(comp_def, par_values, var_values)
end

"""
    get_unconnected_parameters(m::Model)

Return a list of tuples (componentname, parametername) of parameters
that have not been connected to a value in the model.
"""
function get_unconnected_parameters(mi::ModelInstance)
    unset_params = Vector{Tuple{Symbol,Symbol}}()
    
    for (name, c) in components(mi)
        params = get_parameter_names(mi, c)
        set_params = get_set_parameters(mi, c)
        append!(unset_params, map(x->(name, x), setdiff(params, set_params)))
    end

    return unset_params
end

"""
    set_leftover_parameters(m::Model, parameters::Dict{Any,Any})

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary. This method assumes the dictionary
keys are strings that match the names of unset parameters in the model.
"""
function set_leftover_parameters(mi::ModelInstance, parameters::Dict{String,Any})
    parameters = Dict(lowercase(k) => v for (k, v) in parameters)
    leftovers = get_unconnected_parameters(mi)
    external_params = mi.external_params
    md = mi.model_def

    for (comp_name, param_name) in leftovers
        # check whether we need to set the external parameter
        if ! haskey(mi.external_params, param_name)
            value = parameters[lowercase(string(param_name))]
            param_dims = dimensions(mi, comp_name, param_name)
            num_dims = length(param_dims)

            if num_dims == 0    # scalar case
                set_external_scalar_parameter(mi, param_name, value)

            else
                if num_dims in (1, 2) && param_dims[1] == :time   # array case
                    value = convert(Array{md.numberType}, value)
                    offset = indexvalues(md, :time)[1]
                    duration = getduration(indexvalues(md))
                    T = eltype(value)
                    values = get_timestep_instance(T, offset, duration, num_dims, value)
                else
                    values = value
                end
                set_external_array_parameter(mi, param_name, values, nothing)
            end
        end
        connectparameter(mi, comp_name, param_name, param_name)
    end
    nothing
end


function makeclock(mi::ModelInstance, ntimesteps, index_values)
    start = index_values[:time][1]
    stop = index_values[:time][min(length(index_values[:time]),ntimesteps)]
    duration = getduration(index_values)
    return Clock(start, stop, duration)
end

function run(mi::ModelInstance, ntimesteps, index_values)
    if length(mi.components) == 0
        error("Cannot run the model: no components have been created.")
    end

    for (name, c) in mi.components
        resetvariables(c)
        # update_scalar_parameters(mi, name)        # was dropped in DA's version
        init(c)
    end

    # components = [x for x in mi.components]
    components = collect(values(mi.components))
    newstyle = Vector{Bool}(length(components))
    offsets = mi.offsets
    final_times = mi.final_times

    # Was dropped in DA's version
    # for i in collect(1:length(components))
    #     c = components[i][2]
    #     newstyle[i] = method_exists(run_timestep, (typeof(c), Timestep))
    # end

    clock = makeclock(mi, ntimesteps, index_values)
    duration = getduration(index_values)
    comp_clocks = [Clock(offsets[i], final_times[i], duration) for i in collect(1:length(components))]

    while !finished(clock)
        for (i, (name, c)) in enumerate(components)
            if offsets[i] <= gettime(clock) <= final_times[i]

                # was dropped in DA's version
                # if newstyle[i]
                #     run_timestep(c, gettimestep(comp_clocks[i]))
                #     move_forward(comp_clocks[i])
                # else
                #     run_timestep(c, gettimeindex(clock)) #int version (old way)
                # end

                ts = gettimestep(comp_clocks[i])
                
                run_timestep(c.comp_id, c.parameters, c.variables, c.dimensions, ts)

                move_forward(comp_clocks[i])
            end
        end
        move_forward(clock)
    end
end
