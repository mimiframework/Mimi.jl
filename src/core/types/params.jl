#
# Types supporting Parameters and their connections
#

abstract type ModelParameter end

# The `copy` field records whether Mimi took a copy of the caller's value when the
# parameter was set. It is `true` by default, which is the historical behaviour: the
# value is converted into storage Mimi owns, so the caller may go on using their own
# array however they like.
#
# Setting a parameter with `copy = false` instead aliases the caller's array all the
# way through to `run_timestep`, which is what makes it possible to back a parameter
# with a large or memory-mapped array without duplicating it. In exchange the caller
# promises not to mutate it, and Mimi refuses the operations that would mutate it on
# their behalf -- attaching a random variable to it, or updating it through a built
# ModelInstance. See `_check_no_copy_mutation`.
mutable struct ScalarModelParameter{T} <: ModelParameter
    value::T
    is_shared::Bool
    copy::Bool

    function ScalarModelParameter{T}(value::T; is_shared::Bool = false, copy::Bool = true) where T
        new(value, is_shared, copy)
    end

    function ScalarModelParameter{T}(value::T, is_shared::Bool, copy::Bool = true) where T
        new(value, is_shared, copy)
    end

    function ScalarModelParameter{T1}(value::T2; is_shared::Bool = false, copy::Bool = true) where {T1, T2}
        try
            new(T1(value), is_shared, copy)
        catch err
            error("Failed to convert $value::$T2 to $T1")
        end
    end
end

mutable struct ArrayModelParameter{T} <: ModelParameter
    values::T
    dim_names::Vector{Symbol} # if empty, we don't have the dimensions' name information
    is_shared::Bool
    copy::Bool

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}; is_shared::Bool = false, copy::Bool = true) where T
        new(values, dims, is_shared, copy)
    end

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}, is_shared::Bool, copy::Bool = true) where T
        new(values, dims, is_shared, copy)
    end
end

ScalarModelParameter(value) = ScalarModelParameter{typeof(value)}(value)
ScalarModelParameter(value, is_shared) = ScalarModelParameter{typeof(value)}(value, is_shared)
ScalarModelParameter(value, is_shared, copy) = ScalarModelParameter{typeof(value)}(value, is_shared, copy)

Base.convert(::Type{ScalarModelParameter{T}}, value::Number) where {T} = ScalarModelParameter{T}(T(value))

# NB: there is deliberately no `convert(::Type{T}, ::ScalarModelParameter{T})`
# method here. An unconstrained `Type{T}` in argument position 1 supersedes the
# generic `Base.convert` methods and so invalidates every poorly-inferred
# `convert` call site in Base and in our dependencies -- ~1450 method instances,
# which is a large fraction of the compiled code we cache during precompilation.
# Callers that may hold a `ScalarModelParameter` unwrap it with `value(param)`
# instead; component code never sees one, because `_get_prop` already returns
# `.value` (see core/instances.jl).

ArrayModelParameter(value, dims::Vector{Symbol}) = ArrayModelParameter{typeof(value)}(value, dims)
ArrayModelParameter(value, dims::Vector{Symbol}, is_shared::Bool) = ArrayModelParameter{typeof(value)}(value, dims, is_shared)
ArrayModelParameter(value, dims::Vector{Symbol}, is_shared::Bool, copy::Bool) = ArrayModelParameter{typeof(value)}(value, dims, is_shared, copy)

# Allow values to be obtained from either parameter type using one method name.
value(param::ArrayModelParameter)  = param.values
value(param::ScalarModelParameter) = param.value

Base.copy(obj::ScalarModelParameter{T}) where T = ScalarModelParameter(obj.value, obj.is_shared, obj.copy)
Base.copy(obj::ArrayModelParameter{T}) where T = ArrayModelParameter(obj.values, obj.dim_names, obj.is_shared, obj.copy)

#
# Deep-copying a parameter set with `copy = false` aliases its values instead of
# duplicating them.
#
# `build` deepcopies the ModelDef so that later edits to the model definition cannot
# change an already-built instance. For an ordinary parameter that still happens. For
# one the caller asked us not to copy, duplicating the array at build time would
# defeat the entire point, so we alias it -- safely, because nothing mutates such a
# parameter's storage: `_update_array_param!` installs new storage rather than writing
# into the old one, and the two operations that would write in place (attaching a
# random variable, and `update_param!` on a ModelInstance) are refused for it.
#
# The TimestepArray wrapper is always freshly allocated either way, so reassigning its
# `data` field on one side is never visible on the other; only the underlying array is
# aliased.
_alias_param_values(v::TimestepArray{T_TS, T, N, ti}) where {T_TS, T, N, ti} =
    TimestepArray{T_TS, T, N, ti}(v.data)
_alias_param_values(v) = v

function Base.deepcopy_internal(obj::ArrayModelParameter{T}, stackdict::IdDict) where T
    haskey(stackdict, obj) && return stackdict[obj]
    values = obj.copy ? Base.deepcopy_internal(obj.values, stackdict) : _alias_param_values(obj.values)
    new_obj = ArrayModelParameter{T}(values, Base.copy(obj.dim_names), obj.is_shared, obj.copy)
    stackdict[obj] = new_obj
    return new_obj
end

function Base.deepcopy_internal(obj::ScalarModelParameter{T}, stackdict::IdDict) where T
    haskey(stackdict, obj) && return stackdict[obj]
    value = obj.copy ? Base.deepcopy_internal(obj.value, stackdict) : obj.value
    new_obj = ScalarModelParameter{T}(value, obj.is_shared, obj.copy)
    stackdict[obj] = new_obj
    return new_obj
end

"""
    _check_no_copy_mutation(param::ModelParameter, name::Symbol, what::AbstractString)

Throw an informative error if `param` was set with `copy = false`, since its storage
is the caller's own array and Mimi must not write into it on their behalf.
"""
function _check_no_copy_mutation(param::ModelParameter, name::Symbol, what::AbstractString)
    param.copy && return nothing
    error("Cannot $what model parameter :$name, because it was set with ",
          "`copy = false` and so its storage belongs to the caller rather than to ",
          "the model. Set it again without `copy = false` if you need to modify it ",
          "in place.")
end

dim_names(obj::ArrayModelParameter) = obj.dim_names
dim_names(obj::ScalarModelParameter) = []

is_shared(obj::ArrayModelParameter) = obj.is_shared
is_shared(obj::ScalarModelParameter) = obj.is_shared

abstract type AbstractConnection end

struct InternalParameterConnection <: AbstractConnection
    src_comp_path::ComponentPath
    src_var_name::Symbol
    dst_comp_path::ComponentPath
    dst_par_name::Symbol
    ignoreunits::Bool
    backup::Union{Symbol, Nothing} # a Symbol identifying the model param providing backup data, or nothing
    backup_offset::Union{Int, Nothing}

    function InternalParameterConnection(src_path::ComponentPath, src_var::Symbol,
                                         dst_path::ComponentPath, dst_par::Symbol,
                                         ignoreunits::Bool, backup::Union{Symbol, Nothing}=nothing;
                                         backup_offset::Union{Int, Nothing}=nothing)
        self = new(src_path, src_var, dst_path, dst_par, ignoreunits, backup, backup_offset)
        return self
    end
end

struct ExternalParameterConnection  <: AbstractConnection
    comp_path::ComponentPath
    param_name::Symbol      # name of the parameter in the component
    model_param_name::Symbol  # name of the parameter stored in model_params
end

# Converts symbol to component path
function ExternalParameterConnection(comp_name::Symbol, param_name::Symbol, model_param_name::Symbol)
    return ExternalParameterConnection(ComponentPath(comp_name), param_name, model_param_name)
end

Base.pathof(obj::ExternalParameterConnection) = obj.comp_path
Base.nameof(obj::ExternalParameterConnection) = obj.param_name

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

function Base.getproperty(epc::ExternalParameterConnection, field::Symbol)
    if field == :external_param
        @warn "ExternalParameterConnection's `external_param` field is renamed to `model_param_name`, please change code accordingly."
        field = :model_param_name
    end
    return getfield(epc, field)
end
