using Classes
using DataStructures

"""
    @or(args...)

Return the first argument whose value is not `nothing`
"""
macro or(a, b)
    esc(:($a === nothing ? $b : $a))
end

# Having all our structs/classes subtype these simplifies "show" methods
abstract type MimiStruct end
@class MimiClass <: Class

const AbstractMimiType = Union{MimiStruct, AbstractMimiClass}

# To identify components, @defcomp creates a variable with the name of
# the component whose value is an instance of this type.
struct ComponentId <: MimiStruct
    module_name::Symbol
    comp_name::Symbol
end

ComponentId(m::Module, comp_name::Symbol) = ComponentId(nameof(m), comp_name)

# ComponentPath identifies the path through multiple composites to a leaf comp.
struct ComponentPath <: MimiStruct
    names::NTuple{N, Symbol} where N
end

ComponentPath(names::Vector{Symbol}) = ComponentPath(Tuple(names))
ComponentPath(names::Vararg{Symbol}) = ComponentPath(names)

ComponentPath(path::ComponentPath, name::Symbol) = ComponentPath(path.names..., name)

ComponentPath(path1::ComponentPath, path2::ComponentPath) = ComponentPath(path1.names..., path2.names...)

ComponentPath(::Nothing, name::Symbol) = ComponentPath(name)

const ParamPath = Tuple{ComponentPath, Symbol}

#
# 1. Types supporting parameterized Timestep and Clock objects
#

abstract type AbstractTimestep <: MimiStruct end

struct FixedTimestep{FIRST, STEP, LAST} <: AbstractTimestep
    t::Int
end

struct VariableTimestep{TIMES} <: AbstractTimestep
    t::Int
    current::Int

    function VariableTimestep{TIMES}(t::Int = 1) where {TIMES}
        # The special case below handles when functions like next_step step beyond
        # the end of the TIMES array.  The assumption is that the length of this
        # last timestep, starting at TIMES[end], is 1.
        current::Int = t > length(TIMES) ? TIMES[end] + 1 : TIMES[t]

        return new(t, current)
    end
end

mutable struct Clock{T <: AbstractTimestep} <: MimiStruct
	ts::T

	function Clock{T}(FIRST::Int, STEP::Int, LAST::Int) where T
		return new(FixedTimestep{FIRST, STEP, LAST}(1))
    end

    function Clock{T}(TIMES::NTuple{N, Int} where N) where T
        return new(VariableTimestep{TIMES}())
    end
end

mutable struct TimestepArray{T_TS <: AbstractTimestep, T, N} <: MimiStruct
	data::Array{T, N}

    function TimestepArray{T_TS, T, N}(d::Array{T, N}) where {T_TS, T, N}
		return new(d)
	end

    function TimestepArray{T_TS, T, N}(lengths::Int...) where {T_TS, T, N}
		return new(Array{T, N}(undef, lengths...))
	end
end

# Since these are the most common cases, we define methods (in time.jl)
# specific to these type aliases, avoiding some of the inefficiencies
# associated with an arbitrary number of dimensions.
const TimestepMatrix{T_TS, T} = TimestepArray{T_TS, T, 2}
const TimestepVector{T_TS, T} = TimestepArray{T_TS, T, 1}

#
# 2. Dimensions
#

abstract type AbstractDimension <: MimiStruct end

const DimensionKeyTypes   = Union{AbstractString, Symbol, Int, Float64}
const DimensionRangeTypes = Union{UnitRange{Int}, StepRange{Int, Int}}

struct Dimension{T <: DimensionKeyTypes} <: AbstractDimension
    dict::OrderedDict{T, Int}

    function Dimension(keys::Vector{T}) where {T <: DimensionKeyTypes}
        dict = OrderedDict(collect(zip(keys, 1:length(keys))))
        return new{T}(dict)
    end

    function Dimension(rng::T) where {T <: DimensionRangeTypes}
        return Dimension(collect(rng))
    end

    Dimension(i::Int) = Dimension(1:i)

    # Support Dimension(:foo, :bar, :baz)
    function Dimension(keys::T...) where {T <: DimensionKeyTypes}
        vector = [key for key in keys]
        return Dimension(vector)
    end
end

#
# Simple optimization for ranges since indices are computable.
# Unclear whether this is really any better than simply using
# a dict for all cases. Might scrap this in the end.
#
mutable struct RangeDimension{T <: DimensionRangeTypes} <: AbstractDimension
    range::T
 end

#
# 3. Types supporting Parameters and their connections
#
abstract type ModelParameter <: MimiStruct end

# TBD: rename ScalarParameter, ArrayParameter, and AbstractParameter?

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
    offset::Int

    function InternalParameterConnection(src_path::ComponentPath, src_var::Symbol,
                                         dst_path::ComponentPath, dst_par::Symbol,
                                         ignoreunits::Bool, backup::Union{Symbol, Nothing}=nothing; offset::Int=0)
        self = new(src_path, src_var, dst_path, dst_par, ignoreunits, backup, offset)
        return self
    end
end

struct ExternalParameterConnection  <: AbstractConnection
    comp_path::ComponentPath
    param_name::Symbol      # name of the parameter in the component
    external_param::Symbol  # name of the parameter stored in external_params
end

#
# 4. Types supporting structural definition of models and their components
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

# TBD: if DatumReference refers to the "registered" components, then ComponentId
# is adequate for locating it. As David suggested, having separate types for the
# registered components and the user's ModelDef structure would be clarifying.

# Similar structure is used for variables and parameters (parameters merely adds `default`)
@class mutable DatumDef <: NamedObj begin
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
    variables::OrderedDict{Symbol, VariableDef}
    parameters::OrderedDict{Symbol, ParameterDef}
    dim_dict::OrderedDict{Symbol, Union{Nothing, Dimension}}
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    is_uniform::Bool

    # Store a reference to the AbstractCompositeComponent that contains this comp def.
    # That type is defined later, so we declare Any here.
    parent::Union{Nothing, Any}

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
        self.variables  = OrderedDict{Symbol, VariableDef}()
        self.parameters = OrderedDict{Symbol, ParameterDef}()
        self.dim_dict   = OrderedDict{Symbol, Union{Nothing, Dimension}}()
        self.first = self.last = nothing
        self.is_uniform = true
        self.parent = nothing
        return self
    end

    function ComponentDef(comp_id::Union{Nothing, ComponentId};
                          name::Union{Nothing, Symbol}=nothing)
        self = new()
        return ComponentDef(self, comp_id, name=name)
    end
end

comp_id(obj::AbstractComponentDef) = obj.comp_id
pathof(obj::AbstractComponentDef) = obj.comp_path
dim_dict(obj::AbstractComponentDef) = obj.dim_dict
first_period(obj::AbstractComponentDef) = obj.first
last_period(obj::AbstractComponentDef) = obj.last
isuniform(obj::AbstractComponentDef) = obj.is_uniform

# Stores references to the name of a component variable or parameter
# and the ComponentPath of the component in which it is defined
@class DatumReference <: NamedObj begin
    root::AbstractComponentDef
    comp_path::ComponentPath
end

@class ParameterDefReference <: DatumReference
@class VariableDefReference  <: DatumReference

# Used by @defcomposite to communicate subcomponent information
struct SubComponent <: MimiStruct
    module_name::Union{Nothing, Symbol}
    comp_name::Symbol
    alias::Union{Nothing, Symbol}
    exports::Vector{Union{Symbol, Pair{Symbol, Symbol}}}
    bindings::Vector{Pair{Symbol, Any}}
end

# Define type aliases to avoid repeating these in several places
global const Binding = Pair{AbstractDatumReference, Union{Int, Float64, AbstractDatumReference}}
global const ExportsDict = Dict{Symbol, AbstractDatumReference}

@class mutable CompositeComponentDef <: ComponentDef begin
    comps_dict::OrderedDict{Symbol, AbstractComponentDef}
    bindings::Vector{Binding}
    exports::ExportsDict

    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}

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
        self.comps_dict = OrderedDict{Symbol, AbstractComponentDef}()
        self.bindings = Vector{Binding}()
        self.exports  = ExportsDict()
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
        subcomp_id = ComponentId(@or(c.module_name, calling_module), c.comp_name)
        subcomp = compdef(subcomp_id)

        x = printable(subcomp === nothing ? nothing : subcomp_id)
        y = printable(composite === nothing ? nothing : comp_id)
        # @info "CompositeComponentDef calling add_comp!($y, $x)"

        add_comp!(composite, subcomp, @or(c.alias, c.comp_name), exports=c.exports)
    end
    return composite
end

# TBD: these should dynamically and recursively compute the lists
internal_param_conns(obj::AbstractCompositeComponentDef) = obj.internal_param_conns
external_param_conns(obj::AbstractCompositeComponentDef) = obj.external_param_conns

# TBD: should only ModelDefs have external params?
external_params(obj::AbstractCompositeComponentDef) = obj.external_params

exported_names(obj::AbstractCompositeComponentDef) = keys(obj.exports)
is_exported(obj::AbstractCompositeComponentDef, name::Symbol) = haskey(obj.exports, name)

add_backup!(obj::AbstractCompositeComponentDef, backup) = push!(obj.backups, backup)

is_leaf(c::AbstractComponentDef) = true
is_leaf(c::AbstractCompositeComponentDef) = false
is_composite(c::AbstractComponentDef) = !is_leaf(c)

ComponentPath(obj::AbstractCompositeComponentDef, name::Symbol) = ComponentPath(obj.comp_path, name)

@class mutable ModelDef <: CompositeComponentDef begin
    number_type::DataType
    dirty::Bool

    function ModelDef(number_type::DataType=Float64)
        self = new()
        CompositeComponentDef(self)  # call super's initializer
        
        # TBD: now set in CompositeComponentDef(self); delete if that works better
        # self.comp_path = ComponentPath(self.name)

        return ModelDef(self, number_type, false)       # call @class-generated method
    end
end

#
# 5. Types supporting instantiated models and their components
#

# Supertype for variables and parameters in component instances
@class ComponentInstanceData{NT <: NamedTuple} <: MimiClass begin
    nt::NT
    comp_paths::Vector{ComponentPath}   # records the origin of each datum
end

nt(obj::AbstractComponentInstanceData) = getfield(obj, :nt)
types(obj::AbstractComponentInstanceData) = typeof(nt(obj)).parameters[2].parameters
Base.names(obj::AbstractComponentInstanceData)  = keys(nt(obj))
Base.values(obj::AbstractComponentInstanceData) = values(nt(obj))

# Centralizes the shared functionality from the two component data subtypes.
function _datum_instance(subtype::Type{<: AbstractComponentInstanceData},
                         names, types, values, paths)
    # @info "_datum_instance: names=$names, types=$types"
    NT = NamedTuple{Tuple(names), Tuple{types...}}
    return subtype(NT(values), Vector{ComponentPath}(paths))
end

@class ComponentInstanceParameters <: ComponentInstanceData begin
    function ComponentInstanceParameters(nt::NT, paths::Vector{ComponentPath}) where {NT <: NamedTuple}
        return new{NT}(nt, paths)
    end

    function ComponentInstanceParameters(names::Vector{Symbol},
                                         types::Vector{DataType},
                                         values::Vector{Any},
                                         paths)
        return _datum_instance(ComponentInstanceParameters, names, types, values, paths)
    end
end

@class ComponentInstanceVariables <: ComponentInstanceData begin
    function ComponentInstanceVariables(nt::NT, paths::Vector{ComponentPath}) where {NT <: NamedTuple}
        return new{NT}(nt, paths)
    end

    function ComponentInstanceVariables(names::Vector{Symbol},
                                        types::Vector{DataType},
                                        values::Vector{Any},
                                        paths)
        return _datum_instance(ComponentInstanceVariables, names, types, values, paths)
    end
end

# A container class that wraps the dimension dictionary when passed to run_timestep()
# and init(), so we can safely implement Base.getproperty(), allowing `d.regions` etc.
struct DimValueDict <: MimiStruct
    dict::Dict{Symbol, Vector{Int}}

    function DimValueDict(dim_dict::AbstractDict)
        d = Dict([name => collect(values(dim)) for (name, dim) in dim_dict])
        new(d)
    end
end

# Special case support for Dicts so we can use dot notation on dimension.
# The run_timestep() and init() funcs pass a DimValueDict of dimensions by name
# as the "d" parameter.
Base.getproperty(obj::DimValueDict, property::Symbol) = getfield(obj, :dict)[property]

@class mutable ComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: MimiClass begin
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    variables::TV                   # TBD: write functions to extract these from type instead of storing?
    parameters::TP
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    init::Union{Nothing, Function}
    run_timestep::Union{Nothing, Function}

    function ComponentInstance(self::AbstractComponentInstance,
                               comp_def::AbstractComponentDef,
                               vars::TV, pars::TP,
                               time_bounds::Tuple{Int,Int},
                               name::Symbol=nameof(comp_def)) where
                {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

        self.comp_id = comp_id = comp_def.comp_id
        self.comp_path = comp_def.comp_path
        self.comp_name = name
        self.variables = vars
        self.parameters = pars

        # If first or last is `nothing`, substitute first or last time period
        self.first = @or(comp_def.first, time_bounds[1])
        self.last  = @or(comp_def.last,  time_bounds[2])

        # @info "ComponentInstance evaluating $(comp_id.module_name)"
        module_name = comp_id.module_name
        comp_module = getfield(Main, module_name)

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # CompositeComponentInstances use a standard method that just loops over inner components.
        # TBD: use FunctionWrapper here?
        function get_func(name)
            if is_composite(self)
                return nothing
            end

            func_name = Symbol("$(name)_$(nameof(comp_module))_$(self.comp_id.comp_name)")
            try
                getfield(comp_module, func_name)
            catch err
                # @info "Eval of $func_name in module $comp_module failed"
                nothing
            end
        end

        # `is_composite` indicates a ComponentInstance used to store summary
        # data for ComponentInstance and is not itself runnable.
        self.init         = get_func("init")
        self.run_timestep = get_func("run_timestep")

        return self
    end

    # Create an empty instance with the given type parameters
    function ComponentInstance{TV, TP}() where {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
        return new{TV, TP}()
    end
end

function ComponentInstance(comp_def::AbstractComponentDef, vars::TV, pars::TP,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def)) where
        {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

    self = ComponentInstance{TV, TP}()
    return ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
end

# These can be called on CompositeComponentInstances and ModelInstances
compdef(obj::AbstractComponentInstance) = compdef(comp_id(obj))
pathof(obj::AbstractComponentInstance) = obj.comp_path
has_dim(obj::AbstractComponentInstance, name::Symbol) = haskey(obj.dim_value_dict, name)
dimension(obj::AbstractComponentInstance, name::Symbol) = obj.dim_value_dict[name]
first_period(obj::AbstractComponentInstance) = obj.first
last_period(obj::AbstractComponentInstance)  = obj.last

#
# Include only exported vars and pars
#
"""
Return the ComponentInstanceParameters/Variables exported by the given list of
component instances.
"""
function _comp_instance_vars_pars(comp_def::AbstractCompositeComponentDef,
								  comps::Vector{<: AbstractComponentInstance})
    vdict = Dict([:types => [], :names => [], :values => [], :paths => []])
    pdict = Dict([:types => [], :names => [], :values => [], :paths => []])

    root = get_root(comp_def)   # to find comp_defs by path

    comps_dict = Dict([comp.comp_name => comp for comp in comps])

    for (export_name, dr) in comp_def.exports
        datum_comp = find_comp(dr)
        datum_name = nameof(dr)
        ci = comps_dict[nameof(datum_comp)]

        datum = (is_parameter(dr) ? ci.parameters : ci.variables)
        d = (is_parameter(dr) ? pdict : vdict)

        # Find the position of the desired field in the named tuple
        # so we can extract it's datatype.
        pos = findfirst(isequal(datum_name), names(datum))
        datatypes = types(datum)
        dtype = datatypes[pos]
        value = getproperty(datum, datum_name)
        
        push!(d[:names],  export_name)
        push!(d[:types],  dtype)
        push!(d[:values], value)
        push!(d[:paths],  dr.comp_path)
    end

    vars = ComponentInstanceVariables(Vector{Symbol}(vdict[:names]), Vector{DataType}(vdict[:types]), 
                                      Vector{Any}(vdict[:values]), Vector{ComponentPath}(vdict[:paths]))

    pars = ComponentInstanceParameters(Vector{Symbol}(pdict[:names]), Vector{DataType}(pdict[:types]), 
                                       Vector{Any}(pdict[:values]), Vector{ComponentPath}(pdict[:paths]))                                      
    return vars, pars
end

@class mutable CompositeComponentInstance <: ComponentInstance begin
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}

    function CompositeComponentInstance(self::AbstractCompositeComponentInstance,
                                        comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        vars::ComponentInstanceVariables,
                                        pars::ComponentInstanceParameters,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))

        comps_dict = OrderedDict{Symbol, AbstractComponentInstance}()
        for ci in comps
            comps_dict[ci.comp_name] = ci
        end

        ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
        CompositeComponentInstance(self, comps_dict)
        return self
    end

    # Constructs types of vars and params from sub-components
    function CompositeComponentInstance(comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))
        (vars, pars) = _comp_instance_vars_pars(comp_def, comps)
        self = new{typeof(vars), typeof(pars)}()
        CompositeComponentInstance(self, comps, comp_def, vars, pars, time_bounds, name)
    end
end

# These methods can be called on ModelInstances as well
components(obj::AbstractCompositeComponentInstance) = values(obj.comps_dict)
has_comp(obj::AbstractCompositeComponentInstance, name::Symbol) = haskey(obj.comps_dict, name)
compinstance(obj::AbstractCompositeComponentInstance, name::Symbol) = obj.comps_dict[name]

is_leaf(ci::AbstractComponentInstance) = true
is_leaf(ci::AbstractCompositeComponentInstance) = false
is_composite(ci::AbstractComponentInstance) = !is_leaf(ci)

# ModelInstance holds the built model that is ready to be run
@class ModelInstance <: CompositeComponentInstance begin
    md::ModelDef

    # Similar to generated constructor, but extract {TV, TP} from argument.
    function ModelInstance(cci::CompositeComponentInstance{TV, TP}, md::ModelDef) where
            {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
        return ModelInstance{TV, TP}(cci, md)
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
mutable struct Model <: MimiStruct
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
struct MarginalModel <: MimiStruct
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

# A container for a component, for interacting with it within a model.
@class ComponentReference <: MimiClass begin
    parent::AbstractComponentDef
    comp_path::ComponentPath
end

function ComponentReference(parent::AbstractComponentDef, name::Symbol)
    return ComponentReference(parent, ComponentPath(parent.comp_path, name))
end

# A container for a variable within a component, to improve connect_param! aesthetics,
# by supporting subscripting notation via getindex & setindex .
@class VariableReference <: ComponentReference begin
    var_name::Symbol
end
