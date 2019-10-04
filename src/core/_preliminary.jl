# Preliminary file to think through David's suggestion of splitting defs between "registered" 
# readonly "templates"  and user-constructed models so it's clear which functions operate on 
# templates vs defs within a model.

@class ComponentDef <: NamedObj begin
    comp_id::Union{Nothing, ComponentId}
    variables::OrderedDict{Symbol, VariableDef}
    parameters::OrderedDict{Symbol, ParameterDef}
    dim_names::Set{Symbol}
end

@class CompositeComponentDef <: ComponentDef begin
    comps_dict::OrderedDict{Symbol, AbstractComponentDef}
    exports::ExportsDict
    internal_param_conns::Vector{InternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}
end

# Define these for building out a ModelDef, which reference the
# central definitions using the classes above.

@class mutable ModelComponentDef <: NamedObj begin
    comp_id::ComponentId    # references registered component def
    comp_path::Union{Nothing, ComponentPath}
    dim_dict::OrderedDict{Symbol, Union{Nothing, Dimension}}
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    is_uniform::Bool
end

@class mutable ModelCompositeComponentDef <: ModelComponentDef begin
    comps_dict::OrderedDict{Symbol, AbstractModelComponentDef}
    bindings::Vector{Binding}
    exports::ExportsDict
    external_param_conns::Vector{ExternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    sorted_comps::Union{Nothing, Vector{Symbol}}
end
