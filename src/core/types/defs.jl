#
# Types supporting structural definition of models and their components
#

# Objects with a `name` attribute
@class NamedObj <: MimiClass begin
    name::Symbol
end

"""
    nameof(obj::NamedDef) = obj.name

Return the name of `def`.  `NamedDef`s include `DatumDef`, `ComponentDef`,
`CompositeComponentDef`, and `VariableDefReference` and `ParameterDefReference`.
"""
Base.nameof(obj::AbstractNamedObj) = obj.name

# Deprecate old definition in favor of standard name
@deprecate name(obj::AbstractNamedObj) nameof(obj)

# Similar structure is used for variables and parameters (parameters merely adds `default`)
@class mutable DatumDef <: NamedObj begin
    comp_path::Union{Nothing, ComponentPath}
    datatype::DataType
    dim_names::Vector{Symbol}
    description::String
    unit::String
end

@class mutable VariableDef <: DatumDef

@class mutable ParameterDef <: DatumDef begin
    # ParameterDef adds a default value, which can be specified in @defcomp
    default::Any
end

@class mutable ComponentDef <: NamedObj begin
    comp_id::Union{Nothing, ComponentId}    # allow anonynous top-level (composite) ComponentDefs (must be referenced by a ModelDef)
    comp_path::Union{Nothing, ComponentPath}
    dim_dict::OrderedDict{Symbol, Union{Nothing, Dimension}}
    namespace::OrderedDict{Symbol, Any}
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    is_uniform::Bool

    # Store a reference to the AbstractCompositeComponent that contains this comp def.
    # That type is defined later, so we declare Any here. Parent is `nothing` for
    # detached (i.e., "template") components and is set when added to a composite.
    parent::Any


    function ComponentDef(self::ComponentDef, comp_id::Nothing)
        error("Leaf ComponentDef objects must have a valid ComponentId name (not nothing)")
    end

    # ComponentDefs are created "empty". Elements are subsequently added.
    function ComponentDef(self::AbstractComponentDef, comp_id::Union{Nothing, ComponentId}=nothing;
                          name::Union{Nothing, Symbol}=nothing)
        if comp_id === nothing
            # ModelDefs are anonymous, but since they're gensym'd, they can claim the Mimi package
            comp_id = ComponentId(Mimi, @or(name, gensym(nameof(typeof(self)))))
        end

        name = @or(name, comp_id.comp_name)
        NamedObj(self, name)

        self.comp_id = comp_id
        self.comp_path = nothing    # this is set in add_comp!() and ModelDef()

        self.dim_dict  = OrderedDict{Symbol, Union{Nothing, Dimension}}()
        self.namespace = OrderedDict{Symbol, Any}()
        self.first = self.last = nothing
        self.is_uniform = true
        self.parent = nothing
        return self
    end

    function ComponentDef(comp_id::Union{Nothing, ComponentId};
                          name::Union{Nothing, Symbol}=nothing)
        self = new()
        return ComponentDef(self, comp_id; name=name)
    end
end

ns(obj::AbstractComponentDef) = obj.namespace
comp_id(obj::AbstractComponentDef) = obj.comp_id
Base.pathof(obj::AbstractComponentDef) = obj.comp_path
dim_dict(obj::AbstractComponentDef) = obj.dim_dict
first_period(obj::AbstractComponentDef) = obj.first
last_period(obj::AbstractComponentDef) = obj.last
isuniform(obj::AbstractComponentDef) = obj.is_uniform

Base.parent(obj::AbstractComponentDef) = obj.parent

# Used by @defcomposite to communicate subcomponent information
struct SubComponent <: MimiStruct
    module_obj::Union{Nothing, Module}
    comp_name::Symbol
    alias::Union{Nothing, Symbol}
    bindings::Vector{Pair{Symbol, Any}}
end

# Stores references to the name of a component variable or parameter
# and the ComponentPath of the component in which it is defined
@class DatumReference <: NamedObj begin
    # name::Symbol is inherited from NamedObj
    root::AbstractComponentDef
    comp_path::ComponentPath
end

@class ParameterDefReference <: DatumReference

@class VariableDefReference  <: DatumReference

function dereference(ref::AbstractDatumReference)
    comp = find_comp(ref)
    return comp[ref.name]
end

# Might not be useful
# convert(::Type{VariableDef},  ref::VariableDefReference)  = dereference(ref)
# convert(::Type{ParameterDef}, ref::ParameterDefReference) = dereference(ref)


# Define type aliases to avoid repeating these in several places
global const Binding = Pair{AbstractDatumReference, Union{Int, Float64, AbstractDatumReference}}

# Define which types can appear in the namespace dict for leaf and composite compdefs
global const LeafNamespaceElement      = AbstractDatumDef
global const CompositeNamespaceElement = Union{AbstractComponentDef, AbstractDatumReference}
global const NamespaceElement          = Union{LeafNamespaceElement, CompositeNamespaceElement}

@class mutable CompositeComponentDef <: ComponentDef begin
    bindings::Vector{Binding}

    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}               # TBD: make key (ComponentPath, Symbol)?

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    sorted_comps::Union{Nothing, Vector{Symbol}}

    function CompositeComponentDef(comp_id::Union{Nothing, ComponentId}=nothing)
        self = new()
        CompositeComponentDef(self, comp_id)
        return self
    end

    function CompositeComponentDef(self::AbstractCompositeComponentDef, comp_id::Union{Nothing, ComponentId}=nothing)
        ComponentDef(self, comp_id) # call superclass' initializer

        self.comp_path = ComponentPath(self.name)
        self.bindings = Vector{Binding}()
        self.internal_param_conns = Vector{InternalParameterConnection}()
        self.external_param_conns = Vector{ExternalParameterConnection}()
        self.external_params = Dict{Symbol, ModelParameter}()
        self.backups = Vector{Symbol}()
        self.sorted_comps = nothing
    end
end

# Used by @defcomposite
function CompositeComponentDef(comp_id::ComponentId, alias::Symbol, subcomps::Vector{SubComponent},
                               calling_module::Module)
    # @info "CompositeComponentDef($comp_id, $alias, $subcomps)"
    composite = CompositeComponentDef(comp_id)

    for c in subcomps
        # @info "subcomp $c: module: $(printable(c.module_obj)), calling module: $(nameof(calling_module))"
        comp_module = @or(c.module_obj, calling_module)
        subcomp_id = ComponentId(comp_module, c.comp_name)
        subcomp = compdef(subcomp_id)
        add_comp!(composite, subcomp, @or(c.alias, c.comp_name))
    end
    return composite
end

add_backup!(obj::AbstractCompositeComponentDef, backup) = push!(obj.backups, backup)

internal_param_conns(obj::AbstractCompositeComponentDef) = obj.internal_param_conns
external_param_conns(obj::AbstractCompositeComponentDef) = obj.external_param_conns

external_params(obj::AbstractCompositeComponentDef) = obj.external_params

is_leaf(c::AbstractComponentDef) = true
is_leaf(c::AbstractCompositeComponentDef) = false
is_composite(c::AbstractComponentDef) = !is_leaf(c)

ComponentPath(obj::AbstractCompositeComponentDef, name::Symbol) = ComponentPath(obj.comp_path, name)

ComponentPath(obj::AbstractCompositeComponentDef, path::AbstractString) = comp_path(obj, path)

ComponentPath(obj::AbstractCompositeComponentDef, names::Symbol...) = ComponentPath(obj.comp_path.names..., names...)

@class mutable ModelDef <: CompositeComponentDef begin
    number_type::DataType
    dirty::Bool

    function ModelDef(number_type::DataType=Float64)
        self = new()
        CompositeComponentDef(self)  # call super's initializer
        return ModelDef(self, number_type, false)       # call @class-generated method
    end
end

#
# Reference types offer a more convenient syntax for interrogating Components.
#

# A container for a component, for interacting with it within a model.
@class ComponentReference <: MimiClass begin
    parent::AbstractComponentDef
    comp_path::ComponentPath
end

# Define access methods via getfield() since we override dot syntax
Base.parent(comp_ref::AbstractComponentReference) = getfield(comp_ref, :parent)
Base.pathof(comp_ref::AbstractComponentReference) = getfield(comp_ref, :comp_path)

function ComponentReference(parent::AbstractComponentDef, name::Symbol)
    return ComponentReference(parent, ComponentPath(parent.comp_path, name))
end

# A container for a variable within a component, to improve connect_param! aesthetics,
# by supporting subscripting notation via getindex & setindex .
@class VariableReference <: ComponentReference begin
    var_name::Symbol
end

var_name(comp_ref::VariableReference) = getfield(comp_ref, :var_name)
