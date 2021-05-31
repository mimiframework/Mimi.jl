#
# Functions pertaining to instantiated models and their components
#

"""
    modeldef(mi)

Return the `ModelDef` contained by ModelInstance `mi`.
"""
modeldef(mi::ModelInstance) = mi.md

compmodule(obj::AbstractComponentInstance) = compmodule(obj.comp_id)
compname(obj::AbstractComponentInstance)   = compname(obj.comp_id)

"""
    add_comp!(obj::AbstractCompositeComponentInstance, ci::AbstractComponentInstance)

Add the (leaf or composite) component `ci` to a composite's list of components.
"""
function add_comp!(obj::AbstractCompositeComponentInstance, ci::AbstractComponentInstance)
    obj.comps_dict[nameof(ci)] = ci
    return nothing
end

#
# Setting/getting parameter and variable values
#

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
        error("You cannot override indexed variable $name::$T. Make sure you are using proper indexing syntax in the `run_timestep` function: v.varname[t] = ...")
    end
end

comp_paths(obj::AbstractComponentInstanceData) = getfield(obj, :comp_paths)

"""
    get_param_value(ci::AbstractComponentInstance, name::Symbol)

Return the value of parameter `name` in (leaf or composite) component `ci`.
"""
function get_param_value(ci::AbstractComponentInstance, name::Symbol)
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
    get_var_value(ci::AbstractComponentInstance, name::Symbol)

Return the value of variable `name` in component `ci`.
"""
function get_var_value(ci::AbstractComponentInstance, name::Symbol)
    try
        vars = ci.variables
        # @info ("Getting $name from $vars")
        return getproperty(vars, name)
    catch err
        if isa(err, KeyError)
            error("Component $(ci.comp_id) has no variable named $name")
        else
            rethrow(err)
        end
    end
end

"""
    set_param_value(ci::AbstractComponentInstance, name::Symbol, value)

Set the value of parameter `name` in component `ci` to `value`.
"""
set_param_value(ci::AbstractComponentInstance, name::Symbol, value) = setproperty!(ci.parameters, name, value)

"""
    set_var_value(ci::AbstractComponentInstance, name::Symbol, value)

Set the value of variable `name` in component `ci` to `value`.
"""
set_var_value(ci::AbstractComponentInstance, name::Symbol, value) = setproperty!(ci.variables, name, value)

"""
    variables(obj::AbstractCompositeComponentInstance, comp_name::Symbol)

Return the `ComponentInstanceVariables` for `comp_name` in CompositeComponentInstance `obj`.
"""
variables(obj::AbstractCompositeComponentInstance, comp_name::Symbol) = variables(compinstance(obj, comp_name))

variables(obj::AbstractComponentInstance) = obj.variables


function variables(m::Model)
    if ! is_built(m)
        error("Must build model to access variable instances. Use variables(modeldef(m)) to get variable definitions.")
    end
    return variables(modelinstance(m))
end

"""
    parameters(obj::AbstractComponentInstance, comp_name::Symbol)

Return the `ComponentInstanceParameters` for `comp_name` in CompositeComponentInstance `obj`.
"""
parameters(obj::AbstractCompositeComponentInstance, comp_name::Symbol) = parameters(compinstance(obj, comp_name))

parameters(obj::AbstractComponentInstance) = obj.parameters

function Base.getindex(mi::ModelInstance, names::NTuple{N, Symbol}) where N
    obj = mi

    # skip past first element if same as root node
    if length(names) > 0 && head(obj.comp_path) == names[1]
        names = names[2:end]
    end

    for name in names
        if has_comp(obj, name)
            obj = obj[name]
        else
            error("Component $(obj.comp_path) does not have sub-component :$name")
        end
    end
    return obj
end

Base.getindex(mi::ModelInstance, comp_path::ComponentPath) = getindex(mi, comp_path.names)

Base.getindex(mi::ModelInstance, path_str::AbstractString) = getindex(mi, ComponentPath(mi.md, path_str))

function Base.getindex(obj::AbstractCompositeComponentInstance, comp_name::Symbol)
    if ! has_comp(obj, comp_name)
        error("Component :$comp_name does not exist in the given composite")
    end
    return compinstance(obj, comp_name)
end

# TBD we could probably combine the two _get_datum methods into one that takes a
# ci::AbstractComponentInstance, but for now it seems there are enough differences
# that keeping them separate is cleaner
function _get_datum(ci::CompositeComponentInstance, datum_name::Symbol)
    vars = variables(ci)

    if datum_name in keys(vars) # could merge with method below if made names(NamedTuple) = keys(NamedTuple)
        which = vars
    else
        pars = parameters(ci)
        if datum_name in keys(pars) # could merge with method below if made names(NamedTuple) = keys(NamedTuple)
            which = pars
        else
            error("$datum_name is not a parameter or a variable in component $(ci.comp_path).")
        end
    end
    
    ref = getproperty(which, datum_name)
    
    return _get_datum(ci.comps_dict[ref.comp_name], ref.datum_name)
end

function _get_datum(ci::LeafComponentInstance, datum_name::Symbol)
    vars = variables(ci)

    if datum_name in names(vars) 
        which = vars
    else
        pars = parameters(ci)
        if datum_name in names(pars)
            which = pars
        else
            error("$datum_name is not a parameter or a variable in component $(ci.comp_path).")
        end
    end

    value = getproperty(which, datum_name)

    if value isa TimestepArray
        return value.data isa SubArray ? parent(value.data) : value.data
    else
        return value
    end
end

function Base.getindex(mi::ModelInstance, key::AbstractString, datum::Symbol)
    _get_datum(mi[key], datum)
end

function Base.getindex(mi::ModelInstance, comp_path::ComponentPath, datum::Symbol)
    _get_datum(mi[comp_path], datum)
end

@delegate Base.getindex(m::Model, comp_path::ComponentPath, datum::Symbol) => mi 

function Base.getindex(obj::AbstractCompositeComponentInstance, comp_name::Symbol, datum::Symbol)
    ci = obj[comp_name]
    return _get_datum(ci, datum)
end



"""
    dim_count(mi::ModelInstance, dim_name::Symbol)

Return the size of index `dim_name` in model instance `mi`.
"""
@delegate dim_count(mi::ModelInstance, dim_name::Symbol) => md

function reset_variables(ci::AbstractComponentInstance)
    # @info "reset_variables($(ci.comp_id))"
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

function reset_variables(obj::AbstractCompositeComponentInstance)
    for ci in components(obj)
        reset_variables(ci)
    end
    return nothing
end

function init(ci::AbstractComponentInstance, dims::DimValueDict)
    # @info "init($(ci.comp_id))"
    reset_variables(ci)

    if ci.init != nothing
        ci.init(parameters(ci), variables(ci), dims)
    end
    return nothing
end

function init(obj::AbstractCompositeComponentInstance, dims::DimValueDict)
    for ci in components(obj)
        init(ci, dims)
    end
    return nothing
end

_runnable(ci::AbstractComponentInstance, clock::Clock) = (ci.first <= gettime(clock) <= ci.last)

function get_shifted_ts(ci, ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}    
    if ci.first == FIRST && ci.last == LAST
        return ts
    else
        # shift the timestep over by (ci.first - FIRST)/STEP
        return FixedTimestep{ci.first,STEP,ci.last}(ts.t - Int((ci.first - FIRST)/STEP))
    end
end

function get_shifted_ts(ci, ts::VariableTimestep{TIMES}) where {TIMES}
    if ci.first == TIMES[1] && ci.last == TIMES[end]
        return ts
    else
        # shift the timestep over by the number of timesteps between the model first and the ts first
        idx_start = findfirst(TIMES .== ci.first)
        idx_finish = findfirst(TIMES .== ci.last)
        return VariableTimestep{TIMES[idx_start:idx_finish]}(ts.t - idx_start + 1)
    end
end

function run_timestep(ci::AbstractComponentInstance, clock::Clock, dims::DimValueDict)
    if ci.run_timestep !== nothing && _runnable(ci, clock)
        ci.run_timestep(parameters(ci), variables(ci), dims, get_shifted_ts(ci, clock.ts))
    end

    return nothing
end

function run_timestep(cci::AbstractCompositeComponentInstance, clock::Clock, dims::DimValueDict)
    if _runnable(cci, clock)
        for ci in components(cci)
            run_timestep(ci, clock, dims)
        end
    end
    return nothing
end

"""
    Base.run(mi::ModelInstance, ntimesteps::Int=typemax(Int),
            dimkeys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
            
Run the `ModelInstance` `mi` once with `ntimesteps` and dimension keys `dimkeys`.
"""
function Base.run(mi::ModelInstance, ntimesteps::Int=typemax(Int),
                  dimkeys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)

    if length(components(mi)) == 0
        error("Cannot run the model: no components have been created.")
    end

    time_keys::Vector{Int} = dimkeys === nothing ? dim_keys(mi.md, :time) : dimkeys[:time]

    # truncate time_keys if caller so desires
    if ntimesteps < length(time_keys)
        time_keys = time_keys[1:ntimesteps]
    end

    clock = Clock(time_keys)

    # Get the dimensions dictionary
    dim_val_dict = DimValueDict(dim_dict(mi.md), clock)

    # recursively initializes all components
    init(mi, dim_val_dict)

    while ! finished(clock)
        run_timestep(mi, clock, dim_val_dict)
        advance(clock)
    end

    nothing
end
