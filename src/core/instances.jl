#
# Functions pertaining to instantiated models and their components
#

modeldef(mi::ModelInstance) = mi.md

compinstance(mi::ModelInstance, name::Symbol) = mi.components[name]

compdef(ci::ComponentInstance) = compdef(ci.comp_id)

# compdef(mi::ModelInstance, name::Symbol) = compdef(mi.components[name].comp_id)

name(ci::ComponentInstance) = ci.comp_name

"""
    components(mi::ModelInstance)

Return an iterator on the components in model instance `mi`.
"""
components(mi::ModelInstance) = values(mi.components)

function addcomponent(mi::ModelInstance, ci::ComponentInstance) 
    mi.components[name(ci)] = ci

    push!(mi.starts, ci.start)
    push!(mi.stops, ci.stop)
end

#
# Support for dot-overloading in run_timestep functions
#
function _index_pos(names, propname, var_or_par)
    index_pos = findfirst(names, propname)
    # println("findfirst($names, $propname) returned $index_pos")

    index_pos == 0 && error("Unknown $var_or_par name $propname.")
    return index_pos
end

# TBD: Allow assignment only to array slices, not entire arrays,
# and eliminate the ref for arrays.
function _property_expr(obj, types, index_pos)
    T = types.parameters[index_pos]
    # println("_property_expr() index_pos: $index_pos, T: $T")

    if T <: Ref
        ref_type = T.parameters[1]
        # println("_property_expr: ref_type: $ref_type")
        
        if ref_type <: Scalar
            value_type = ref_type.parameters[1]
            # println("_property_expr: scalar value_type: $value_type")
            ex = :(obj.values[$index_pos][].value::$(value_type)) # dereference Scalar instance
        else
            ex = :(obj.values[$index_pos][]::$(ref_type))
        end
 
        # println("_property_expr returning $ex")
        return ex

    # TBD: deprecated if we keep Refs for everything
    # else
    #     return :(obj.values[$index_pos])
    end
end

# Fallback get & set property funcs that revert to dot notation
@generated function getproperty(obj, ::Val{PROPERTY}) where {PROPERTY}
    return :(obj.$PROPERTY)
end

@generated function setproperty!(obj, ::Val{PROPERTY}, value) where {PROPERTY}
    return :(obj.$PROPERTY = value)
end

# Special case support for Dicts so we can use dot notation on dimension.
# The run() func passes a Dict of dimensions by name as the "d" parameter.
# Here we return a range representing the indices into that list of values.
# TBD: Need to revise this in v0.7 so we don't affect all Dicts.
@generated function getproperty(obj::Dict, ::Val{PROPERTY}) where {PROPERTY}
    return :(obj[PROPERTY])
end

# Setting/getting parameter and variable values
@generated function getproperty(obj::ComponentInstanceParameters{NAMES, TYPES}, 
                                ::Val{PROPERTY}) where {NAMES, TYPES, PROPERTY}
    index_pos = _index_pos(NAMES, PROPERTY, "parameter")
    return _property_expr(obj, TYPES, index_pos)
end

@generated function getproperty(obj::ComponentInstanceVariables{NAMES, TYPES}, 
                                ::Val{PROPERTY}) where {NAMES, TYPES, PROPERTY}
    index_pos = _index_pos(NAMES, PROPERTY, "variable")
    return _property_expr(obj, TYPES, index_pos)
end


@generated function setproperty!(obj::ComponentInstanceParameters{NAMES, TYPES}, 
                                 ::Val{PROPERTY}, value) where {NAMES, TYPES, PROPERTY}
    index_pos = _index_pos(NAMES, PROPERTY, "parameter")
    T = TYPES.parameters[index_pos].parameters[1]   # get down to the Scalar{xxx}
    return T <: Scalar ? :(obj.values[$index_pos][].value = value) : :(obj.values[$index_pos][] = value)   
    # return :(obj.values[$index_pos][] = value)

    #
    # TBD: now that everything is a Ref, this isn't necessary, but still need to catch this error!
    #
    # if TYPES.parameters[index_pos] <: Ref
    #     return :(obj.values[$index_pos][] = value)
    # else
    #     return :(obj.values[$index_pos] = value)
    #     # T = TYPES.parameters[index_pos]
    #     # error("You cannot override indexed parameter $PROPERTY::$T.")
    # end
end

@generated function setproperty!(obj::ComponentInstanceVariables{NAMES, TYPES}, 
                                 ::Val{PROPERTY}, value) where {NAMES, TYPES, PROPERTY}
    index_pos = _index_pos(NAMES, PROPERTY, "variable")
    T = TYPES.parameters[index_pos].parameters[1]
    # println("setproperty!(TYPES: $TYPES, T: $T, value: $value)")
    return T <: Scalar ? :(obj.values[$index_pos][].value = value) : :(obj.values[$index_pos][] = value)   
    # return :(obj.values[$index_pos][] = value)

    #
    # TBD: now that everything is a Ref, this isn't necessary, but still need to catch this error!
    #
    # if TYPES.variables[index_pos] <: Ref
    #     return :(obj.values[$index_pos][] = value)
    # else
    #     T = TYPES.variables[index_pos]
    #     error("You cannot override indexed variable $PROPERTY::$T.")
    # end
end

function get_parameter_ref(ci::ComponentInstance, name::Symbol)
    pars = ci.parameters
    index_pos = _index_pos(pars.names, name, "parameter")
    return ci.parameters.values[index_pos]
end

function get_variable_ref(ci::ComponentInstance, name::Symbol)
    vars = ci.variables
    index_pos = _index_pos(vars.names, name, "variable")
    return vars.values[index_pos]
end

function set_parameter_ref(ci::ComponentInstance, name::Symbol, ref::Ref)
    pars = ci.parameters
    index_pos = _index_pos(pars.names, name, "parameter")
    ci.parameters.values[index_pos].x = ref.x
end

function set_variable_ref(ci::ComponentInstance, name::Symbol, ref::Ref)
    vars = ci.variables
    index_pos = _index_pos(vars.names, name, "variable")
    vars.values[index_pos].x = ref.x
end

# Convenience functions that can be called with a name symbol rather than Val(name)
function get_parameter_value(ci::ComponentInstance, name::Symbol)
    try 
        return getproperty(ci.parameters, Val(name))
    catch err
        if isa(err, KeyError)
            error("Component $(ci.comp_id) has no parameter named $name")
        else
            rethrow(err)
        end
    end
end

function get_variable_value(ci::ComponentInstance, name::Symbol)
    try
        # println("Getting $name from $(ci.variables)")
        return getproperty(ci.variables, Val(name))
    catch err
        if isa(err, KeyError)
            error("Component $(ci.comp_id) has no variable named $name")
        else
            rethrow(err)
        end
    end
end

set_parameter_value(ci::ComponentInstance, name::Symbol, value) = setproperty!(ci.parameters, Val(name), value)

set_variable_value(ci::ComponentInstance, name::Symbol, value)  = setproperty!(ci.variables, Val(name), value)

# Allow values to be obtained from either parameter type using one method name.
value(param::ScalarModelParameter) = param.value

value(param::ArrayModelParameter)  = param.values

dimensions(obj::ArrayModelParameter) = obj.dimensions

dimensions(obj::ScalarModelParameter) = []

"""
    variables(mi::ModelInstance, comp_name::Symbol)

Return the `ComponentInstanceVariables` for `comp_name` in ModelInstance 'mi'.
"""
variables(mi::ModelInstance, comp_name::Symbol) = variables(compinstance(mi, comp_name))

variables(ci::ComponentInstance) = ci.variables

"""
    parameters(mi::ModelInstance, comp_name::Symbol)

Return the `ComponentInstanceParameters` for `comp_name` in ModelInstance 'mi'.
"""
parameters(mi::ModelInstance, comp_name::Symbol) = parameters(compinstance(mi, comp_name))

parameters(ci::ComponentInstance) = ci.parameters


function Base.getindex(mi::ModelInstance, comp_name::Symbol, datum_name::Symbol)
    if !(comp_name in keys(mi.components))
        error("Component does not exist in current model")
    end
    
    comp_inst = compinstance(mi, comp_name)
    vars = comp_inst.variables
    pars = comp_inst.parameters

    if datum_name in vars.names
        which = vars
    elseif datum_name in pars.names
        which = pars
    else
        error("$datum_name is not a parameter or a variable in component $comp_name.")
    end

    value = getproperty(which, Val(datum_name))
    # return isa(value, PklVector) || isa(value, TimestepMatrix) ? value.data : value
    return isa(value, AbstractTimestepMatrix) ? value.data : value
end

"""
    dim_count(mi::ModelInstance, dim_name::Symbol)

Returns the size of index `dim_name`` in model instance `mi`.
"""
dim_count(mi::ModelInstance, dim_name::Symbol) = dim_count(mi.md, dim_name)

dim_key_dict(mi::ModelInstance) = dim_key_dict(mi.md)

dim_value_dict(mi::ModelInstance) = dim_value_dict(mi.md)

function make_clock(mi::ModelInstance, ntimesteps, time_keys::Vector{Int})
    start = time_keys[1]
    stop  = time_keys[min(length(time_keys), ntimesteps)]
    step  = step_size(time_keys)
    return Clock(start, step, stop)
end

function reset_variables(ci::ComponentInstance)
    # println("reset_variables($(ci.comp_id))")
    vars = ci.variables

    for (name, ref) in zip(vars.names, vars.types.parameters)
        # Everything is held in a Ref{}, so get the parameters to that...
        T = ref.parameters[1]
        value = getproperty(vars, Val(name))

        if (T <: AbstractArray || T <: AbstractTimestepMatrix) && eltype(value) <: AbstractFloat
            fill!(value, NaN)

        elseif T <: AbstractFloat || (T <: Scalar && T.parameters[1] <: AbstractFloat)            
            setproperty!(vars, Val(name), NaN)

        elseif (T <: Scalar)    # integer or bool
            setproperty!(vars, Val(name), 0)
        end
    end
end

function init(mi::ModelInstance)
    for ci in components(mi)
        init(mi, ci)
    end
end

# Fall-back for components without init methods
init(module_name, comp_name, p::ComponentInstanceParameters, v::Mimi.ComponentInstanceVariables, 
     d::Union{Void, Dict}) = nothing

function init(mi::ModelInstance, ci::ComponentInstance)
    reset_variables(ci)
    module_name = compmodule(ci.comp_id)

    init(Val(module_name), Val(ci.comp_name), ci.parameters, ci.variables, ci.dim_dict)
end

function run_timestep(::Val{TM}, ::Val{TC}, ci::ComponentInstance, clock::Clock) where {TM,TC} 
    pars = ci.parameters
    vars = ci.variables
    dims = ci.dim_dict
    t = timeindex(clock)

    run_timestep(Val(TM), Val(TC), pars, vars, dims, t)
    advance(clock)
    nothing
end

function _run_components(mi::ModelInstance, comp_instances::Vector{ComponentInstance}, clock::Clock,
                         starts::Vector{Int}, stops::Vector{Int}, comp_clocks::Vector{Clock})
    while ! finished(clock)
        for (ci, start, stop, comp_clock) in zip(comp_instances, starts, stops, comp_clocks)
            if start <= gettime(clock) <= stop
                module_name = compmodule(ci.comp_id)
                comp_name = compname(ci.comp_id)
                run_timestep(Val(module_name), Val(comp_name), ci, comp_clock)
            end
        end
        advance(clock)
    end
end

function Base.run(mi::ModelInstance, ntimesteps::Int=typemax(Int), 
                  dimkeys::Union{Void, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
    if length(mi.components) == 0
        error("Cannot run the model: no components have been created.")
    end

    t::Vector{Int} = dimkeys == nothing ? dim_keys(mi.md, :time) : dimkeys[:time]

    starts = mi.starts
    stops = mi.stops
    step  = step_size(t)

    comp_clocks = [Clock(start, step, stop) for (start, stop) in zip(starts, stops)]
    
    clock = make_clock(mi, ntimesteps, t)

    init(mi)    # call module's (or fallback) init function

    comp_instances = collect(components(mi))

    _run_components(mi, comp_instances, clock, starts, stops, comp_clocks)
end
