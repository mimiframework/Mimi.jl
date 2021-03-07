#
# Types supporting Parameters and their connections
#

abstract type ModelParameter <: MimiStruct end

# TBD: rename as ScalarParameter, ArrayParameter, and AbstractParameter?

mutable struct ScalarModelParameter{T} <: ModelParameter
    value::T

    function ScalarModelParameter{T}(value::T) where T
        new(value)
    end

    function ScalarModelParameter{T1}(value::T2) where {T1, T2}
        try
            new(T1(value))
        catch err
            error("Failed to convert $value::$T2 to $T1")
        end
    end
end

mutable struct ArrayModelParameter{T} <: ModelParameter
    values::T
    dim_names::Vector{Symbol} # if empty, we don't have the dimensions' name information

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}) where T
        new(values, dims)
    end
end

ScalarModelParameter(value) = ScalarModelParameter{typeof(value)}(value)

Base.convert(::Type{ScalarModelParameter{T}}, value::Number) where {T} = ScalarModelParameter{T}(T(value))

Base.convert(::Type{T}, s::ScalarModelParameter{T}) where {T} = T(s.value)

ArrayModelParameter(value, dims::Vector{Symbol}) = ArrayModelParameter{typeof(value)}(value, dims)

# Allow values to be obtained from either parameter type using one method name.
value(param::ArrayModelParameter)  = param.values
value(param::ScalarModelParameter) = param.value

Base.copy(obj::ScalarModelParameter{T}) where T = ScalarModelParameter(obj.value)
Base.copy(obj::ArrayModelParameter{T}) where T = ArrayModelParameter(obj.values, obj.dim_names)

dim_names(obj::ArrayModelParameter) = obj.dim_names
dim_names(obj::ScalarModelParameter) = []

abstract type AbstractConnection <: MimiStruct end

struct InternalParameterConnection <: AbstractConnection
    src_comp_path::ComponentPath
    src_var_name::Symbol
    dst_comp_path::ComponentPath
    dst_par_name::Symbol
    ignoreunits::Bool
    backup::Union{Symbol, Nothing} # a Symbol identifying the external param providing backup data, or nothing
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
    external_param::Symbol  # name of the parameter stored in external_params
end

# Converts symbol to component path
function ExternalParameterConnection(comp_name::Symbol, param_name::Symbol, external_param::Symbol)
    return ExternalParameterConnection(ComponentPath(comp_name), param_name, external_param)
end

Base.pathof(obj::ExternalParameterConnection) = obj.comp_path
Base.nameof(obj::ExternalParameterConnection) = obj.param_name
