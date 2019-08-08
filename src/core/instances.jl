#
# Functions pertaining to instantiated models and their components
#

"""
    modeldef(mi)

Return the `ModelDef` contained by ModelInstance `mi`.
"""
modeldef(mi::ModelInstance) = mi.md

"""
    add_comp!(obj::AbstractCompositeComponentInstance, ci::AbstractComponentInstance)

Add the (leaf or composite) component `ci` to a composite's list of components, and add
the `first` and `last` of `mi` to the ends of the composite's `firsts` and `lasts` lists.
"""
function add_comp!(obj::AbstractCompositeComponentInstance, ci::AbstractComponentInstance)
    obj.comps_dict[nameof(ci)] = ci

    # push!(obj.firsts, first_period(ci))         # TBD: perhaps this should be set when time is set?
    # push!(obj.lasts,  last_period(ci))
    nothing
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
        error("You cannot override indexed variable $name::$T.")
    end
end

comp_paths(obj::AbstractComponentInstanceData) = getfield(obj, :comp_paths)

"""
    get_param_value(ci::ComponentInstance, name::Symbol)

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
    get_var_value(ci::ComponentInstance, name::Symbol)

Return the value of variable `name` in component `ci`.
"""
function get_var_value(ci::AbstractComponentInstance, name::Symbol)
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

set_param_value(ci::AbstractComponentInstance, name::Symbol, value) = setproperty!(ci.parameters, name, value)

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

function _get_datum(ci::AbstractComponentInstance, datum_name::Symbol)
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

    return value isa TimestepArray ? value.data : value
end

function Base.getindex(mi::ModelInstance, key::AbstractString, datum::Symbol)
    _get_datum(mi[key], datum)
end

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
        ci.init(ci.parameters, ci.variables, dims)
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

function run_timestep(ci::AbstractComponentInstance, clock::Clock, dims::DimValueDict)
    if ci.run_timestep !== nothing && _runnable(ci, clock)
        ci.run_timestep(ci.parameters, ci.variables, dims, clock.ts)
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

function Base.run(mi::ModelInstance, ntimesteps::Int=typemax(Int),
                  dimkeys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)

    if (ncomps = length(components(mi))) == 0
        error("Cannot run the model: no components have been created.")
    end

    time_keys::Vector{Int} = dimkeys === nothing ? dim_keys(mi.md, :time) : dimkeys[:time]

    # truncate time_keys if caller so desires
    if ntimesteps < length(time_keys)
        time_keys = time_keys[1:ntimesteps]
    end

    # TBD: Pass this, but substitute t from above?
    dim_val_dict = DimValueDict(dim_dict(mi.md))

    # recursively initializes all components
    init(mi, dim_val_dict)

    clock = Clock(time_keys)
    while ! finished(clock)
        run_timestep(mi, clock, dim_val_dict)
        advance(clock)
    end

    nothing
end
