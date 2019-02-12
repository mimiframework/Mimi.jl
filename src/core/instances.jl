#
# Functions pertaining to instantiated models and their components
#

"""
    modeldef(mi)

Return the `ModelDef` contained by ModelInstance `mi`.
"""
modeldef(mi::ModelInstance) = mi.md

compinstance(mi::ModelInstance, name::Symbol) = mi.components[name]

compdef(ci::ComponentInstance) = compdef(ci.comp_id)

"""
    name(ci::ComponentInstance)

Return the name of the component `ci`.
"""
name(ci::ComponentInstance) = ci.comp_name

"""
    components(mi::ModelInstance)

Return an iterator on the components in model instance `mi`.
"""
components(mi::ModelInstance) = values(mi.components)

"""
    add_comp!(mi::ModelInstance, ci::ComponentInstance)

Add the component `ci` to the `ModelInstance` `mi`'s list of components, and add
the `first` and `last` of `mi` to the ends of the `firsts` and `lasts` lists of 
`mi`, respectively.
"""
function add_comp!(mi::ModelInstance, ci::ComponentInstance) 
    mi.components[name(ci)] = ci

    push!(mi.firsts, ci.first)
    push!(mi.lasts, ci.last)
end

# Setting/getting parameter and variable values

# Get the object stored for the given variable, not the value of the variable.
# This is used in the model building process to connect internal parameters.
@inline function get_property_obj(obj::ComponentInstanceParameters{NT}, name::Symbol) where {NT}
    return getproperty(nt(obj), name)
end

@inline function get_property_obj(obj::ComponentInstanceVariables{NT}, name::Symbol) where {NT}
    return getproperty(nt(obj), name)
end

@inline function _get_prop(nt::NT, name::Symbol) where {NT <: NamedTuple}
    obj = getproperty(nt, name)
    return fieldtype(NT, name) <: ScalarModelParameter ? obj.value : obj
end

@inline function Base.getproperty(obj::ComponentInstanceParameters{NT}, name::Symbol) where {NT}
    return _get_prop(nt(obj), name)
end

@inline function Base.getproperty(obj::ComponentInstanceVariables{NT}, name::Symbol) where {NT}
    return _get_prop(nt(obj), name)
end

@inline function Base.setproperty!(obj::ComponentInstanceParameters{NT}, name::Symbol, value::VTYPE) where {NT, VTYPE}
    prop_obj = get_property_obj(obj, name)
    T = fieldtype(NT, name)

    if T <: ScalarModelParameter
        return setproperty!(prop_obj, :value, value)
    else
        error("You cannot override indexed parameter $name::$T.")
    end
end

@inline function Base.setproperty!(obj::ComponentInstanceVariables{NT}, name::Symbol, value::VTYPE) where {NT, VTYPE}
    prop_obj = get_property_obj(obj, name)
    T = fieldtype(NT, name)

    if T <: ScalarModelParameter
        return setproperty!(prop_obj, :value, value)
    else
        error("You cannot override indexed variable $name::$T.")
    end
end

"""
    get_param_value(ci::ComponentInstance, name::Symbol)

Return the value of parameter `name` in component `ci`.
"""
function get_param_value(ci::ComponentInstance, name::Symbol)
    try 
        return getproperty(ci.parameters, name)
    catch err
        if isa(err, KeyError)
            error("Component $(ci.comp_id) has no parameter named $name")
        else
            rethrow(err)
        end
    end
end

"""
    get_var_value(ci::ComponentInstance, name::Symbol)

Return the value of variable `name` in component `ci`.
"""
function get_var_value(ci::ComponentInstance, name::Symbol)
    try
        # println("Getting $name from $(ci.variables)")
        return getproperty(ci.variables, name)
    catch err
        if isa(err, KeyError)
            error("Component $(ci.comp_id) has no variable named $name")
        else
            rethrow(err)
        end
    end
end

set_param_value(ci::ComponentInstance, name::Symbol, value) = setproperty!(ci.parameters, name, value)

set_var_value(ci::ComponentInstance, name::Symbol, value)  = setproperty!(ci.variables, name, value)

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

"""
    parameters(ci::ComponentInstance)

Return an iterable over the parameters in `ci`.
"""
parameters(ci::ComponentInstance) = ci.parameters


function Base.getindex(mi::ModelInstance, comp_name::Symbol, datum_name::Symbol)
    if !(comp_name in keys(mi.components))
        error("Component :$comp_name does not exist in current model")
    end
    
    comp_inst = compinstance(mi, comp_name)
    vars = comp_inst.variables
    pars = comp_inst.parameters

    if datum_name in names(vars)
        which = vars
    elseif datum_name in names(pars)
        which = pars
    else
        error("$datum_name is not a parameter or a variable in component $comp_name.")
    end

    value = getproperty(which, datum_name)

    return value isa TimestepArray ? value.data : value
end

"""
    dim_count(mi::ModelInstance, dim_name::Symbol)

Return the size of index `dim_name` in model instance `mi`.
"""
dim_count(mi::ModelInstance, dim_name::Symbol) = dim_count(mi.md, dim_name)

"""
    dim_key_dict(mi::ModelInstance)

Return a dict of dimension keys for all dimensions in model instance `mi`.
"""
dim_key_dict(mi::ModelInstance) = dim_key_dict(mi.md)

"""
    dim_keys(mi::ModelInstance, dim_name::Symbol)
    
Return keys for dimension `dim_name` in model instance `mi`.
"""
dim_keys(mi::ModelInstance, dim_name::Symbol) = dim_keys(mi.md, dim_name)

dim_value_dict(mi::ModelInstance) = dim_value_dict(mi.md)

function make_clock(mi::ModelInstance, ntimesteps, time_keys::Vector{Int})
    last  = time_keys[min(length(time_keys), ntimesteps)]

    if isuniform(time_keys)
        first, stepsize = first_and_step(time_keys)
        return Clock{FixedTimestep}(first, stepsize, last)

    else
        last_index = findfirst(isequal(last), time_keys)
        times = (time_keys[1:last_index]...,)
        return Clock{VariableTimestep}(times)
    end
end

function reset_variables(ci::ComponentInstance)
    # println("reset_variables($(ci.comp_id))")
    vars = ci.variables

    for (name, T) in zip(names(vars), types(vars))
        value = getproperty(vars, name)

        if (T <: AbstractArray || T <: TimestepArray) && eltype(value) <: AbstractFloat
            fill!(value, NaN)

        elseif T <: AbstractFloat || (T <: ScalarModelParameter && T.parameters[1] <: AbstractFloat)            
            setproperty!(vars, name, NaN)

        elseif (T <: ScalarModelParameter)    # integer or bool
            setproperty!(vars, name, 0)
        end
    end
end

function init(mi::ModelInstance)
    for ci in components(mi)
        init(ci)
    end
end

function init(ci::ComponentInstance)
    reset_variables(ci)
    if ci.init !== nothing
        ci.init(ci.parameters, ci.variables, DimDict(ci.dim_dict))
    end
end

function run_timestep(ci::ComponentInstance, clock::Clock)
    if ci.run_timestep === nothing
        return
    end

    pars = ci.parameters
    vars = ci.variables
    dims = ci.dim_dict
    t = clock.ts

    ci.run_timestep(pars, vars, DimDict(dims), t)
    advance(clock)
    nothing
end

function _run_components(mi::ModelInstance, clock::Clock,
                         firsts::Vector{Int}, lasts::Vector{Int}, comp_clocks::Vector{Clock{T}}) where {T <: AbstractTimestep}
    comp_instances = components(mi)
    tups = collect(zip(comp_instances, firsts, lasts, comp_clocks))
    
    while ! finished(clock)
        for (ci, first, last, comp_clock) in tups
            if first <= gettime(clock) <= last
                run_timestep(ci, comp_clock)
            end
        end
        advance(clock)
    end
    nothing
end

function Base.run(mi::ModelInstance, ntimesteps::Int=typemax(Int), 
                  dimkeys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
    if length(mi.components) == 0
        error("Cannot run the model: no components have been created.")
    end

    t::Vector{Int} = dimkeys === nothing ? dim_keys(mi.md, :time) : dimkeys[:time]
    
    firsts = mi.firsts
    lasts = mi.lasts

    if isuniform(t)
        _, stepsize = first_and_step(t)
        comp_clocks = [Clock{FixedTimestep}(first, stepsize, last) for (first, last) in zip(firsts, lasts)]
    else
        comp_clocks = Array{Clock{VariableTimestep}}(undef, length(firsts))
        for i = 1:length(firsts)
            first_index = findfirst(isequal(firsts[i]), t)
            last_index  = findfirst(isequal(lasts[i]), t)
            times = (t[first_index:last_index]...,)
            comp_clocks[i] = Clock{VariableTimestep}(times)
        end
    end

    clock = make_clock(mi, ntimesteps, t)

    init(mi)    # call module's (or fallback) init function

    _run_components(mi, clock, firsts, lasts, comp_clocks)
    nothing
end
