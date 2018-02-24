#
# Functions pertaining to instantiated models and their components
#

modeldef(mi::ModelInstance) = mi.md

compinstance(mi::ModelInstance, name::Symbol) = mi.components[name]

compdef(ci::ComponentInstance) = compdef(ci.comp_id)

name(ci::ComponentInstance) = ci.comp_name

"""
    components(mi::ModelInstance)

Return an iterator on the components in model instance `mi`.
"""
components(mi::ModelInstance) = values(mi.components)

function addcomponent(mi::ModelInstance, ci::ComponentInstance) 
    mi.components[name(ci)] = ci

    push!(mi.offsets, ci.offset)
    push!(mi.final_times, ci.final)
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
function get_parameter_value(ci::ComponentInstance, name::Symbol)
    try 
        return getproperty(ci.pars, Val(name))
    catch
        error("Component $(ci.comp_id) has no parameter named $name")
    end
end

function get_variable_value(ci::ComponentInstance, name::Symbol)
    try
        return getproperty(ci.vars, Val(name))
    catch
        error("Component $(ci.comp_id) has no variable named $name")
    end
end

set_parameter_value(ci::ComponentInstance, name::Symbol, value) = setproperty!(ci.pars, Val(name), value)

set_variable_value(ci::ComponentInstance, name::Symbol, value)  = setproperty!(ci.vars, Val(name), value)

# Allow values to be obtained from either parameter type using one method name.
value(param::ScalarModelParameter) = param.value

value(param::ArrayModelParameter)  = param.values

dimensions(obj::ArrayModelParameter) = obj.dimensions

"""
variables(mi::ModelInstance, componentname::Symbol)

List all the variables of `componentname` in the ModelInstance 'mi'.
NOTE: this variables function does NOT take in Nullable instances
"""
function variables(mi::ModelInstance, comp_name::Symbol)
    ci = compinstance(mi, comp_name)
    return variables(ci)
end

variables(ci::ComponentInstance) = variables(ci.comp_id)

function getindex(mi::ModelInstance, comp_name::Symbol, name::Symbol)
    if !(comp_name in keys(mi.components))
        error("Component does not exist in current model")
    end
    
    comp_def = compdef(mi, comp_name)
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
    indexcount(mi::ModelInstance, idx_name::Symbol)

Returns the size of index `idx_name`` in model instance `mi`.
"""
indexcount(mi::ModelInstance, idx_name::Symbol) = mi.index_counts[idx_name]

"""
    indexvalues(m::Model, i::Symbol)

Return the values of index i in model m.
"""
function indexvalues(mi::ModelInstance, idx_name::Symbol)
    try
        return mi.index_values[idx_name]
    catch
        error("Index $idx_name was not found in model.")
    end
end

function make_clock(mi::ModelInstance, ntimesteps, index_values)
    start = index_values[:time][1]
    stop = index_values[:time][min(length(index_values[:time]),ntimesteps)]
    duration = duration(index_values)
    return Clock(start, stop, duration)
end

function reset_variables(ci::ComponentInstance)
    println("reset_variables($(ci.comp_id))")
end

function init(ci::ComponentInstance)
    println("init($(ci.comp_id))")
    reset_variables(ci)
end

function run_timestep(ci::ComponentInstance, comp_clock::Clock)
    ts = timestep(comp_clock)
    run_timestep(ci.comp_id, ci.parameters, ci.variables, ci.dimensions, ts)
    advance(comp_clock)
end

function run(mi::ModelInstance, ntimesteps, index_values)
    if length(mi.components) == 0
        error("Cannot run the model: no components have been created.")
    end

    components = collect(components(mi))
    map(init, components)

    starts = mi.offsets
    stops  = mi.final_times

    duration = duration(index_values)
    comp_clocks = [Clock(starts[i], stops[i], duration) for i in 1:length(components)]
    
    clock = make_clock(mi, ntimesteps, index_values)

    while ! finished(clock)
        for (ci, start, stop, comp_clock) in zip(components, starts, stops, comp_clocks)
            if within(clock, start, stop)
                run_timestep(ci, comp_clock)
            end
        end
        advance(clock)
    end
end
