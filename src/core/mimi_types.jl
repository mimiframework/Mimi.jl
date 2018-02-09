struct ComponentInstanceInfo
    name::Symbol
    # component_type::DataType        # TBD: components are no longer unique types, so need to redo this
    comp_def::ComponentDef
    offset::Int
    final::Int

    function ComponentInstanceInfo(name::Symbol, offset::Int, final::Int)
        self = new()
        self.name = name
        self.offset = offset
        self.final = final
        # self.comp_def = ??
    end
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

    function InternalParameterConnection(src_var::Symbol, src_comp::Symbol, target_par::Symbol, target_comp::Symbol, 
                                         ignoreunits::Bool, backup::Union{Symbol, Void}=nothing)
        self = new(src_var, src_comp, target_par, target_comp, ignoreunits, backup)
        return self
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
        self = new()
        self.values = values
        self.dims = dims
        return self
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
    components2::OrderedDict{Symbol, ComponentInstanceInfo}                 # TBD: rename 'components'; use ComponentKey instead of Symbol
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

#
# A "model" whose results are obtained by subtracting results of one model from those of another.
#
type MarginalModel
    base::Model
    marginal::Model
    delta::Float64
end

function getindex(m::MarginalModel, component::Symbol, name::Symbol)
    return (m.marginal[component, name] .- m.base[component, name]) ./ m.delta
end
