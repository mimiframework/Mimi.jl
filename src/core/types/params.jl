#
# Types supporting Parameters and their connections
#

abstract type ModelParameter <: MimiStruct end

mutable struct ScalarModelParameter{T} <: ModelParameter
    value::T
    is_shared::Bool

    function ScalarModelParameter{T}(value::T; is_shared::Bool = false) where T
        new(value, is_shared)
    end

    function ScalarModelParameter{T}(value::T, is_shared::Bool) where T
        new(value, is_shared)
    end

    function ScalarModelParameter{T1}(value::T2; is_shared::Bool = false) where {T1, T2}
        try
            new(T1(value), is_shared)
        catch err
            error("Failed to convert $value::$T2 to $T1")
        end
    end
end

mutable struct ArrayModelParameter{T} <: ModelParameter
    values::T
    dim_names::Vector{Symbol} # if empty, we don't have the dimensions' name information
    is_shared::Bool

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}; is_shared::Bool = false) where T
        new(values, dims, is_shared)
    end

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}, is_shared::Bool) where T
        new(values, dims, is_shared)
    end
end

ScalarModelParameter(value) = ScalarModelParameter{typeof(value)}(value)
ScalarModelParameter(value, is_shared) = ScalarModelParameter{typeof(value)}(value, is_shared)

Base.convert(::Type{ScalarModelParameter{T}}, value::Number) where {T} = ScalarModelParameter{T}(T(value))
Base.convert(::Type{T}, s::ScalarModelParameter{T}) where {T} = T(s.value)

ArrayModelParameter(value, dims::Vector{Symbol}) = ArrayModelParameter{typeof(value)}(value, dims)
ArrayModelParameter(value, dims::Vector{Symbol}, is_shared::Bool) = ArrayModelParameter{typeof(value)}(value, dims, is_shared)

# Allow values to be obtained from either parameter type using one method name.
value(param::ArrayModelParameter)  = param.values
value(param::ScalarModelParameter) = param.value

Base.copy(obj::ScalarModelParameter{T}) where T = ScalarModelParameter(obj.value, obj.is_shared)
Base.copy(obj::ArrayModelParameter{T}) where T = ArrayModelParameter(obj.values, obj.dim_names, obj.is_shared)

dim_names(obj::ArrayModelParameter) = obj.dim_names
dim_names(obj::ScalarModelParameter) = []

is_shared(obj::ArrayModelParameter) = obj.is_shared
is_shared(obj::ScalarModelParameter) = obj.is_shared

abstract type AbstractConnection <: MimiStruct end

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
