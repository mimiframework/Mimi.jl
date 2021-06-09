#
# Types supporting structural definition of models and their components
#

# Objects with a `name` attribute
@class NamedObj <: MimiClass begin
    name::Symbol
end

"""
    nameof(obj::NamedDef) = obj.name

Return the name of `def`.  `NamedDef`s include `DatumDef`, `ComponentDef`, and `CompositeComponentDef`
"""
Base.nameof(obj::AbstractNamedObj) = obj.name

# Similar structure is used for variables and parameters (parameters merely adds `default`)
@class mutable DatumDef <: NamedObj begin
    comp_path::Union{Nothing, ComponentPath}
    datatype::DataType
    dim_names::Vector{Symbol}
    description::String
    unit::String
end

Base.pathof(obj::AbstractDatumDef) = obj.comp_path

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

        # self.comp_path = nothing    # this is set in add_comp!() and ModelDef()
        self.comp_path = ComponentPath(name)    # this is set in add_comp!() and ModelDef()

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
end

# UnnamedReferences are stored in CompositeParameterDefs or CompositeVariableDefs
# to point to subcomponents' parameters or variables.
struct UnnamedReference
    comp_name::Symbol   # name of the referenced subcomponent
    datum_name::Symbol  # name of the parameter or variable in the subcomponent's namespace
end

@class CompositeParameterDef <: ParameterDef begin
    refs::Vector{UnnamedReference}
end

# Create a CompositeParameterDef from a list of compdefs/pnames
function CompositeParameterDef(name::Symbol, comp_path::ComponentPath, pairs::Vector{Pair{T, Symbol}}, kwargs) where T <: AbstractComponentDef
    # Create the necessary references
    refs = [UnnamedReference(nameof(comp), param_name) for (comp, param_name) in pairs]

    # Unpack the kwargs
    datatype = kwargs[:datatype]
    dim_names = kwargs[:dim_names]
    description = kwargs[:description]
    unit = kwargs[:unit]
    default = kwargs[:default]

    return CompositeParameterDef(name, comp_path, datatype, dim_names, description, unit, default, refs)
end

# Create a CompositeParameterDef from one subcomponent's ParameterDef (used by import_params!)
function CompositeParameterDef(obj, param_ref)
    subcomp_name = param_ref.comp_name
    pname = param_ref.datum_name

    pardef = obj.namespace[subcomp_name].namespace[pname]
    return CompositeParameterDef(pname, pathof(obj), pardef.datatype, pardef.dim_names, pardef.description, pardef.unit, pardef.default, [param_ref])
end

@class CompositeVariableDef <: VariableDef begin
    ref::UnnamedReference
end

function CompositeVariableDef(name::Symbol, comp_path::ComponentPath, subcomp::AbstractComponentDef, vname::Symbol)
    vardef = subcomp.namespace[vname]
    comp_name = subcomp.name
    return CompositeVariableDef(name, comp_path, vardef.datatype, vardef.dim_names, vardef.description, vardef.unit, UnnamedReference(comp_name, vname))
end

# Define which types can appear in the namespace dict for leaf and composite compdefs
global const LeafNamespaceElement      = AbstractDatumDef
global const CompositeDatumDef         = Union{AbstractCompositeParameterDef, AbstractCompositeVariableDef}
global const CompositeNamespaceElement = Union{AbstractComponentDef, CompositeDatumDef}
global const NamespaceElement          = Union{LeafNamespaceElement, CompositeNamespaceElement}

@class mutable CompositeComponentDef <: ComponentDef begin
    internal_param_conns::Vector{InternalParameterConnection}

    # Names of model params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    function CompositeComponentDef(comp_id::Union{Nothing, ComponentId}=nothing)
        self = new()
        CompositeComponentDef(self, comp_id)
        return self
    end

    function CompositeComponentDef(self::AbstractCompositeComponentDef, comp_id::Union{Nothing, ComponentId}=nothing)
        ComponentDef(self, comp_id) # call superclass' initializer

        self.comp_path = ComponentPath(self.name)
        self.internal_param_conns = Vector{InternalParameterConnection}()
        self.backups = Vector{Symbol}()
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

is_leaf(c::AbstractComponentDef) = true
is_leaf(c::AbstractCompositeComponentDef) = false
is_composite(c::AbstractComponentDef) = !is_leaf(c)

ComponentPath(obj::AbstractCompositeComponentDef, name::Symbol) = ComponentPath(obj.comp_path, name)

ComponentPath(obj::AbstractCompositeComponentDef, path::AbstractString) = comp_path(obj, path)

ComponentPath(obj::AbstractCompositeComponentDef, names::Symbol...) = ComponentPath(obj.comp_path.names..., names...)

@class mutable ModelDef <: CompositeComponentDef begin
    external_param_conns::Vector{ExternalParameterConnection}
    model_params::Dict{Symbol, ModelParameter}

    number_type::DataType
    dirty::Bool

    function ModelDef(number_type::DataType=Float64)
        self = new()
        CompositeComponentDef(self)  # call super's initializer

        ext_conns  = Vector{ExternalParameterConnection}()
        model_params = Dict{Symbol, ModelParameter}()

        # N.B. @class-generated method
        return ModelDef(self, ext_conns, model_params, number_type, false)
    end
end

external_param_conns(md::ModelDef) = md.external_param_conns

model_params(md::ModelDef) = md.model_params

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
    return ComponentReference(parent, ComponentPath(pathof(parent), name))
end

# A container for a variable within a component, to improve connect_param! aesthetics,
# by supporting subscripting notation via getindex & setindex .
@class VariableReference <: ComponentReference begin
    var_name::Symbol
end

var_name(comp_ref::VariableReference) = getfield(comp_ref, :var_name)

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

# -- throw errors --

# -- throw warnings --

@deprecate external_params(md::ModelDef) model_params(md)

# Deprecate old definition in favor of standard name
@deprecate name(obj::AbstractNamedObj) nameof(obj)
