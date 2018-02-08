# deprecated
# abstract type ComponentState end

struct ComponentInstanceInfo
    name::Symbol
    component_type::DataType        # TBD: components are no longer unique types, so need to redo this
    offset::Int
    final::Int
end

abstract type Parameter end

mutable struct ScalarModelParameter <: Parameter
    value
end

struct InternalParameterConnection
    source_variable_name::Symbol
    source_component_name::Symbol
    target_parameter_name::Symbol
    target_component_name::Symbol
    ignoreunits::Bool
    backup # either nothing, or a Symbol matching the name of the external parameter to be used as backup data
    function InternalParameterConnection(src_var::Symbol, src_comp::Symbol, target_par::Symbol, target_comp::Symbol, ignoreunits::Bool, backup::Union{Symbol, Void}=nothing)
        ipc = new(src_var, src_comp, target_par, target_comp, ignoreunits, backup)
        return ipc
    end
end

struct ExternalParameterConnection
    component_name::Symbol
    param_name::Symbol #name of the parameter in the component
    external_parameter::Symbol #name of the parameter stored in m.external_parameters
end

mutable struct ArrayModelParameter <: Parameter
    values
    dims::Vector{Symbol} # if empty, we don't have the dimensions' name information

    function ArrayModelParameter(values, dims::Vector{Symbol})
        amp = new()
        amp.values = values
        amp.dims = dims
        return amp
    end
end

#
# Provides user-facing API to ModelInstance and ModelDef
#
mutable struct Model
    indices_counts::Dict{Symbol,Int}
    indices_values::Dict{Symbol,Vector{Any}}
    time_labels::Vector
    external_parameters::Dict{Symbol,Parameter}
    numberType::DataType
    internal_parameter_connections::Vector{InternalParameterConnection}
    external_parameter_connections::Vector{ExternalParameterConnection}
    components2::OrderedDict{Symbol, ComponentInstanceInfo}
    mi::Nullable{ModelInstance}

    function Model(numberType::DataType=Float64)
        m = new()
        m.indices_counts = Dict{Symbol,Int}()
        m.indices_values = Dict{Symbol, Vector{Any}}()
        # m.time_labels = Vector{Any}()
        m.external_parameters = Dict{Symbol, Parameter}()
        m.numberType = numberType
        m.internal_parameter_connections = Vector{InternalParameterConnection}()
        m.external_parameter_connections = Vector{ExternalParameterConnection}()
        m.components2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        m.mi = Nullable{ModelInstance}()
        return m
    end
end
