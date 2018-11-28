# Objects with a `name` attribute
@class Named begin
    name::Symbol
end

@method name(obj::Named) = obj.name

@class DimensionDef <: Named

# Similar structure is used for variables and parameters (parameters has `default`)
@class mutable VarDef <: Named begin
    datatype::DataType
    dimensions::Vector{Symbol}
    description::String
    unit::String
end

@class mutable ParDef <: VarDef begin
    # ParDef adds a default value, which can be specified in @defcomp
    default::Any
end


@class mutable ComponentDef <: Named begin
    comp_id::Union{Nothing, ComponentId}    # allow anonynous top-level (composite) ComponentDefs (must be referenced by a ModelDef)
    name::Symbol                            # Union{Nothing, Symbol} ?
    variables::OrderedDict{Symbol, VarDef}
    parameters::OrderedDict{Symbol, ParDef}
    dimensions::OrderedDict{Symbol, DimensionDef}
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    is_uniform::Bool

    # ComponentDefs are created "empty". Elements are subsequently added.
    function ComponentDef(self::_ComponentDef_, comp_id::Union{Nothing, ComponentId}, comp_name::Symbol=comp_id.comp_name)
        if (is_leaf(self) && comp_id === nothing)
            error("Leaf ComponentDef objects must have a Symbol name (not nothing)")
        end

        self.comp_id = comp_id
        self.name = comp_name
        self.variables  = OrderedDict{Symbol, DatumDef}()
        self.parameters = OrderedDict{Symbol, DatumDef}() 
        self.dimensions = OrderedDict{Symbol, DimensionDef}()
        self.first = self.last = nothing
        self.is_uniform = true
        return self
    end

    function ComponentDef(comp_id::Union{Nothing, ComponentId}, comp_name::Symbol=comp_id.comp_name)
        return ComponentDef(new(), comp_id, comp_name)
    end

    # ComponentDef() = ComponentDef(nothing, gensym("anonymous"))
end

@class mutable CompositeDef <: ComponentDef begin
    comps_dict::OrderedDict{Symbol, _ComponentDef_}
    bindings::Vector{Pair{DatumReference, BindingTypes}}
    exports::Vector{Pair{DatumReference, Symbol}}
    
    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    sorted_comps::Union{Nothing, Vector{Symbol}}

    function CompositeDef(comps::Vector{T},
                                   bindings::Vector{Pair{DatumReference, BindingTypes}},
                                   exports::Vector{Pair{DatumReference, Symbol}}) where {T <: _ComponentDef_}
        self = new()

        # superclass initialization
        # ComponentDef(self, comp_id, comp_name)

        self.comps_dict = OrderedDict{Symbol, T}([name(cd) => cd for cd in comps])
        self.bindings = bindings
        self.exports = exports
        self.internal_param_conns = Vector{InternalParameterConnection}() 
        self.external_param_conns = Vector{ExternalParameterConnection}()
        self.external_params = Dict{Symbol, ModelParameter}()
        self.backups = Vector{Symbol}()
        self.sorted_comps = nothing

        return self
    end

    function CompositeDef()
        comps    = Vector{<: _ComponentDef_}()
        bindings = Vector{Pair{DatumReference, BindingTypes}}()
        exports  = Vector{Pair{DatumReference, Symbol}}()
        return CompositeDef(comps, bindings, exports)
    end
end

@method is_leaf(comp::ComponentDef) = true
@method is_leaf(comp::CompositeDef) = false
@method is_composite(comp::ComponentDef) = !is_leaf(comp)

# TBD: Does a ModelDef contain a CompositeDef, or is it a subclass?

@class mutable ModelDef <: CompositeDef begin
    dimensions::Dict{Symbol, Dimension}             # TBD: use the one in ccd instead
    number_type::DataType
    
    # TBD: these methods assume sub-elements rather than subclasses
    function ModelDef(ccd::CompositeDef, number_type::DataType=Float64)
        dimensions = Dict{Symbol, Dimension}()
        return new(ccd, dimensions, number_type)
    end

    function ModelDef(number_type::DataType=Float64)
        # passes an anonymous top-level (composite) ComponentDef
        return ModelDef(ComponentDef(), number_type)
    end
end

#
# 5. Types supporting instantiated models and their components
#

# Supertype for variables and parameters in component instances
@class InstanceData{NT <: NamedTuple} begin
    nt::NT
end

@class InstanceParameters{NT <: NamedTuple} <: InstanceData

function InstanceParameters(names, types, values)
    NT = NamedTuple{names, types}
    InstanceParameters{NT}(NT(values))
end

function InstanceParameters{NT}(values::T) where {NT <: NamedTuple, T <: AbstractArray}
    InstanceParameters{NT}(NT(values))
end


@class InstanceVariables{NT <: NamedTuple} <: InstanceData

function InstanceVariables(names, types, values)
    NT = NamedTuple{names, types}
    InstanceVariables{NT}(NT(values))
end

function InstanceVariables{NT}(values::T) where {NT <: NamedTuple, T <: AbstractArray}
    InstanceVariables{NT}(NT(values))
end

# A container class that wraps the dimension dictionary when passed to run_timestep()
# and init(), so we can safely implement Base.getproperty(), allowing `d.regions` etc.
struct DimDict
    dict::Dict{Symbol, Vector{Int}}
end

# Special case support for Dicts so we can use dot notation on dimension.
# The run_timestep() and init() funcs pass a DimDict of dimensions by name 
# as the "d" parameter.
@inline function Base.getproperty(dimdict::DimDict, property::Symbol)
    return getfield(dimdict, :dict)[property]
end

@method nt(obj::InstanceData) = getfield(obj, :nt)
@method Base.names(obj::InstanceData)  = keys(nt(obj))
@method Base.values(obj::InstanceData) = values(nt(obj))
@method types(obj::InstanceData) = typeof(nt(obj)).parameters[2].parameters

@class mutable ComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} begin
    comp_name::Symbol
    comp_id::ComponentId
    variables::TV
    parameters::TP
    dim_dict::Dict{Symbol, Vector{Int}}
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    init::Union{Nothing, Function}
    run_timestep::Union{Nothing, Function}

    function ComponentInstance{TV, TP}(comp_def::ComponentDef, vars::TV, pars::TP,
                                       name::Symbol=name(comp_def)) where
                {TV <: InstanceVariables, TP <: InstanceParameters}

        self = new{TV, TP}()
        self.comp_id = comp_id = comp_def.comp_id
        self.comp_name = name
        self.dim_dict = Dict{Symbol, Vector{Int}}()     # set in "build" stage
        self.variables = vars
        self.parameters = pars
        self.first = comp_def.first
        self.last = comp_def.last

        comp_module = Base.eval(Main, comp_id.module_name)

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # All ComponentInstances use a standard method that just loops over inner components.
        # TBD: use FunctionWrapper here?
        function get_func(name)
            func_name = Symbol("$(name)_$(self.comp_name)")
            try
                Base.eval(comp_module, func_name)
            catch err
                nothing
            end        
        end

        # `is_composite` indicates a ComponentInstance used to store summary
        # data for ComponentInstance and is not itself runnable.
        self.run_timestep = is_composite(self) ? nothing : get_func("run_timestep")
        self.init         = is_composite(self) ? nothing : get_func("init")

        return self
    end
end

function ComponentInstance(comp_def::ComponentDef, vars::TV, pars::TP, 
                           name::Symbol=name(comp_def)) where
                            {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
    ComponentInstance{TV, TP}(comp_def, vars, pars, name, subcomps=subcomps)
end

@class mutable CompositeInstance <: ComponentInstance begin
    comps_dict::OrderedDict{Symbol, _ComponentInstance_}
    firsts::Vector{Int}        # in order corresponding with components
    lasts::Vector{Int}
    clocks::Vector{Clock}

    function CompositeInstance(comps::Vector{T}) where {T <: _ComponentInstance_}
        self = new()
        self.comps_dict = OrderedDict{Symbol, _ComponentInstance_}([ci.comp_name => ci for ci in comps])
        self.firsts = Vector{Int}()
        self.lasts  = Vector{Int}()
        self.clocks = Vector{Clock}()
        return self
    end
end

@method is_leaf(ci::ComponentInstance) = true
@method is_leaf(ci::CompositeInstance) = false
@method is_composite(ci::ComponentInstance) = !is_leaf(ci)

# TBD: @class or container?
# ModelInstance holds the built model that is ready to be run
mutable struct ModelInstance <: CompositeInstance
    md::ModelDef
    cci::Union{Nothing, CompositeInstance}

    function ModelInstance(md::ModelDef, cci::Union{Nothing, CompositeComponentInstance}=nothing)
        return new(md, cci)
    end
end

#
# 6. User-facing Model types providing a simplified API to model definitions and instances.
#
"""
    Model

A user-facing API containing a `ModelInstance` (`mi`) and a `ModelDef` (`md`).  
This `Model` can be created with the optional keyword argument `number_type` indicating
the default type of number used for the `ModelDef`.  If not specified the `Model` assumes
a `number_type` of `Float64`.
"""
mutable struct Model
    md::ModelDef
    mi::Union{Nothing, ModelInstance}
    
    function Model(number_type::DataType=Float64)
        return new(ModelDef(number_type), nothing)
    end

    # Create a copy of a model, e.g., to create marginal models
    function Model(m::Model)
        return new(deepcopy(m.md), nothing)
    end
end

""" 
    MarginalModel

A Mimi `Model` whose results are obtained by subtracting results of one `base` Model 
from those of another `marginal` Model` that has a difference of `delta`.
"""
struct MarginalModel
    base::Model
    marginal::Model
    delta::Float64

    function MarginalModel(base::Model, delta::Float64=1.0)
        return new(base, Model(base), delta)
    end
end

function Base.getindex(mm::MarginalModel, comp_name::Symbol, name::Symbol)
    return (mm.marginal[comp_name, name] .- mm.base[comp_name, name]) ./ mm.delta
end

#
# 7. Reference types provide more convenient syntax for interrogating Components
#

"""
    ComponentReference

A container for a component, for interacting with it within a model.
"""
struct ComponentReference
    model::Model
    comp_name::Symbol
end

"""
    VariableReference
    
A container for a variable within a component, to improve connect_param! aesthetics,
by supporting subscripting notation via getindex & setindex .
"""
struct VariableReference
    model::Model
    comp_name::Symbol
    var_name::Symbol
end
