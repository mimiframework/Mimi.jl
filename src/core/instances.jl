#
# Functions pertaining to instantiated models and their components
#

modeldef(mi::ModelInstance) = mi.md

compinstance(mi::ModelInstance, name::Symbol) = mi.components[name]

name(ci::ComponentInstance) = ci.comp_name

"""
    components(mi::ModelInstance)

Return an iterator on the components in model instance `mi`.
"""
components(mi::ModelInstance) = values(mi.components)

function addcomponent(mi::ModelInstance, ci::ComponentInstance) 
    mi.components[name(ci)] = ci
end

#
# Support for dot-overloading in run_timestep functions
#
function _index_pos(names, propname, var_or_par)
    index_pos = findfirst(names, propname)
    index_pos == 0 && error("Unknown $var_or_par name $propname.")
    return index_pos
end

function _property_expr(obj, types, index_pos)
    if types.parameters[index_pos] <: Ref
        return :(obj.values[$index_pos][])
    else
        return :(obj.values[$index_pos])
    end
end

@generated function getproperty(obj::ComponentInstanceParameters{NAMES, TYPES}, 
                                ::Val{PROPERTYNAME}) where {NAMES, TYPES, PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "parameter")
    return _property_expr(obj, TYPES, index_pos)
end

@generated function getproperty(obj::ComponentInstanceVariables{NAMES, TYPES}, 
                                ::Val{PROPERTYNAME}) where {NAMES, TYPES, PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "variable")
    return _property_expr(obj, TYPES, index_pos)
end

@generated function setproperty!(obj::ComponentInstanceVariables{NAMES, TYPES}, 
                                 ::Val{PROPERTYNAME}, value) where {NAMES, TYPES, PROPERTYNAME}
    index_pos = _index_pos(NAMES, PROPERTYNAME, "variable")

    if TYPES.parameters[index_pos] <: Ref
        return :(obj.values[$index_pos][] = value)
    else
        error("You cannot override indexed variable $PROPERTYNAME.")
    end
end

# Convenience functions that can be called with a name symbol rather than Val(name)
get_parameter_value(ci::ComponentInstance, name::Symbol) = getproperty(ci.pars, Val(name))

get_variable_value(ci::ComponentInstance, name::Symbol)  = getproperty(ci.vars, Val(name))

set_variable_value(ci::ComponentInstance, name::Symbol, value) = setproperty!(ci.vars, Val(name), value)

#
# TBD: relationship between ComponentInstanceVariable/Parameter and connection parameters isn't clear
#
# Allow values to be obtained from either parameter type using
# one method name.
value(param::ScalarModelParameter) = param.value

value(param::ArrayModelParameter) = param.values

"""
variables(mi::ModelInstance, componentname::Symbol)

List all the variables of `componentname` in the ModelInstance 'mi'.
NOTE: this variables function does NOT take in Nullable instances
"""
function variables(mi::ModelInstance, comp_name::Symbol)
    ci = compinstance(mi, comp_name)
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


function makeclock(mi::ModelInstance, ntimesteps, index_values)
    start = index_values[:time][1]
    stop = index_values[:time][min(length(index_values[:time]),ntimesteps)]
    duration = duration(index_values)
    return Clock(start, stop, duration)
end

function run(mi::ModelInstance, ntimesteps, index_values)
    if length(mi.components) == 0
        error("Cannot run the model: no components have been created.")
    end

    for (name, c) in mi.components
        resetvariables(c)
        init(c)
    end

    # components = [x for x in mi.components]
    components = collect(values(mi.components))
    newstyle = Vector{Bool}(length(components))
    offsets = mi.offsets
    final_times = mi.final_times

    clock = makeclock(mi, ntimesteps, index_values)
    duration = duration(index_values)
    comp_clocks = [Clock(offsets[i], final_times[i], duration) for i in collect(1:length(components))]

    while !finished(clock)
        for (i, (name, c)) in enumerate(components)
            if offsets[i] <= gettime(clock) <= final_times[i]
                ts = timestep(comp_clocks[i])              
                run_timestep(c.comp_id, c.parameters, c.variables, c.dimensions, ts)
                advance(comp_clocks[i])
            end
        end
        advance(clock)
    end
end

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