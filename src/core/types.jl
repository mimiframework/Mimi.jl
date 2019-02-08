using Classes
using DataStructures

# Having all our structs/classes subtype these simplifies "show" methods
abstract type MimiStruct end
@class MimiClass <: Class

const AbstractMimiType = Union{MimiStruct, AbstractMimiClass}

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
    src_comp_name::Symbol
    src_var_name::Symbol
    dst_comp_name::Symbol
    dst_par_name::Symbol
    ignoreunits::Bool
    backup::Union{Symbol, Nothing} # a Symbol identifying the external param providing backup data, or nothing
    offset::Int

    function InternalParameterConnection(src_comp::Symbol, src_var::Symbol, dst_comp::Symbol, dst_par::Symbol,
                                         ignoreunits::Bool, backup::Union{Symbol, Nothing}=nothing; offset::Int=0)
        self = new(src_comp, src_var, dst_comp, dst_par, ignoreunits, backup, offset)
        return self
    end
end

struct ExternalParameterConnection  <: AbstractConnection
    comp_name::Symbol
    param_name::Symbol      # name of the parameter in the component
    external_param::Symbol  # name of the parameter stored in external_params
end

#
# 4. Types supporting structural definition of models and their components
#

# To identify components, @defcomp creates a variable with the name of 
# the component whose value is an instance of this type.
struct ComponentId <: MimiStruct
    module_name::Symbol
    comp_name::Symbol
end

# Identifies the path through multiple composites to a leaf component
# TBD: Could be just a tuple of Symbols since they are unique at each level.
const ComponentPath = NTuple{N, Symbol} where N

ComponentPath(names::Vector{Symbol}) = Tuple(names)

# The equivalent of ".." in the file system.
Base.parent(path::ComponentPath) = path[1:end-1]

ComponentId(m::Module, comp_name::Symbol) = ComponentId(nameof(m), comp_name)

#
# TBD: consider a naming protocol that adds Cls to class struct names 
# so it's obvious in the code.
#

# Objects with a `name` attribute
@class NamedObj <: MimiClass begin
    name::Symbol
end

"""
    nameof(obj::NamedDef) = obj.name 

Return the name of `def`.  `NamedDef`s include `DatumDef`, `ComponentDef`, 
`CompositeComponentDef`, and `DatumReference`.
"""
@method Base.nameof(obj::NamedObj) = obj.name

# Stores references to the name of a component variable or parameter
# and the ComponentId of the component in which it is defined
@class DatumReference <: NamedObj begin
    # TBD: should be a ComponentPath
    comp_id::ComponentId                # TBD: should this be a ComponentPath?
end

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

    function ComponentDef(self::ComponentDef, comp_id::Nothing)
        error("Leaf ComponentDef objects must have a valid ComponentId name (not nothing)")
    end

    # ComponentDefs are created "empty". Elements are subsequently added.
    function ComponentDef(self::AbstractComponentDef, comp_id::Union{Nothing, ComponentId}=nothing; 
                          name::Union{Nothing, Symbol}=nothing)
        if name === nothing
            name = (comp_id === nothing ? gensym(nameof(typeof(self))) : comp_id.comp_name)
        end

        NamedObj(self, name)
        self.comp_id = comp_id
        self.comp_path = nothing    # this is set in add_comp!()
        self.variables  = OrderedDict{Symbol, VariableDef}()
        self.parameters = OrderedDict{Symbol, ParameterDef}() 
        self.dim_dict   = OrderedDict{Symbol, Union{Nothing, Dimension}}()
        self.first = self.last = nothing
        self.is_uniform = true
        return self
    end

    function ComponentDef(comp_id::Union{Nothing, ComponentId}; 
                          name::Union{Nothing, Symbol}=nothing)
        self = new()
        return ComponentDef(self, comp_id, name=name)
    end    
end

@method comp_id(obj::ComponentDef) = obj.comp_id
@method dim_dict(obj::ComponentDef) = obj.dim_dict
@method first_period(obj::ComponentDef) = obj.first
@method last_period(obj::ComponentDef) = obj.last
@method isuniform(obj::ComponentDef) = obj.is_uniform

# Define type aliases to avoid repeating these in several places
global const BindingsDef = Vector{Pair{T where T <: AbstractDatumReference, Union{Int, Float64, DatumReference}}}
global const ExportsDef  = Dict{Symbol, AbstractDatumReference}

@class mutable CompositeComponentDef <: ComponentDef begin
    comps_dict::OrderedDict{Symbol, AbstractComponentDef}
    bindings::BindingsDef

    exports::ExportsDef
    
    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}
    external_params::Dict{Symbol, ModelParameter}

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    sorted_comps::Union{Nothing, Vector{Symbol}}

    function CompositeComponentDef(self::AbstractCompositeComponentDef, 
                                   comp_id::ComponentId, 
                                   comps::Vector{<: AbstractComponentDef},
                                   bindings::BindingsDef,
                                   exports::ExportsDef)
    
        # TBD: OrderedDict{ComponentId, AbstractComponentDef}
        comps_dict = OrderedDict{Symbol, AbstractComponentDef}([nameof(cd) => cd for cd in comps])
        in_conns = Vector{InternalParameterConnection}() 
        ex_conns = Vector{ExternalParameterConnection}()
        ex_params = Dict{Symbol, ModelParameter}()
        backups = Vector{Symbol}()
        sorted_comps = nothing
        
        ComponentDef(self, comp_id)         # superclass init [TBD: allow for alternate comp_name?]
        CompositeComponentDef(self, comps_dict, bindings, exports, in_conns, ex_conns, 
                              ex_params, backups, sorted_comps)
        return self
    end

    function CompositeComponentDef(comp_id::ComponentId, comps::Vector{<: AbstractComponentDef},
                                   bindings::BindingsDef,
                                   exports::ExportsDef)

        self = new()
        return CompositeComponentDef(self, comp_id, comps, bindings, exports)
    end

    # Creates an empty composite compdef with all containers allocated but empty
    function CompositeComponentDef(self::Union{Nothing, AbstractCompositeComponentDef}=nothing)
        self = (self === nothing ? new() : self)

        comp_id  = ComponentId(@__MODULE__, gensym(nameof(typeof(self))))
        comps    = Vector{T where T <: AbstractComponentDef}()
        bindings = BindingsDef()
        exports  = ExportsDef()
        return CompositeComponentDef(self, comp_id, comps, bindings, exports)
    end
end

# TBD: these should dynamically and recursively compute the lists
@method internal_param_conns(obj::CompositeComponentDef) = obj.internal_param_conns
@method external_param_conns(obj::CompositeComponentDef) = obj.external_param_conns

@method external_params(obj::CompositeComponentDef) = obj.external_params
@method external_param(obj::CompositeComponentDef, name::Symbol) = obj.external_params[name]

@method exported_names(obj::CompositeComponentDef) = keys(obj.exports)
@method is_exported(obj::CompositeComponentDef, name::Symbol) = haskey(obj.exports, name)

@method add_backup!(obj::CompositeComponentDef, backup) = push!(obj.backups, backup)

@method is_leaf(c::ComponentDef) = true
@method is_leaf(c::CompositeComponentDef) = false
@method is_composite(c::ComponentDef) = !is_leaf(c)

@class mutable ModelDef <: CompositeComponentDef begin
    number_type::DataType
    dirty::Bool

    function ModelDef(number_type::DataType=Float64)
        self = new()
        CompositeComponentDef(self)  # call super's initializer
        self.comp_path = (self.name,)
        return ModelDef(self, number_type, false)
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

@method nt(obj::ComponentInstanceData) = getfield(obj, :nt)
@method types(obj::ComponentInstanceData) = typeof(nt(obj)).parameters[2].parameters
@method Base.names(obj::ComponentInstanceData)  = keys(nt(obj))
@method Base.values(obj::ComponentInstanceData) = values(nt(obj))

# Centralizes the shared functionality from the two component data subtypes.
function _datum_instance(subtype::Type{<: AbstractComponentInstanceData}, 
                         names, types, values, paths)
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
    variables::TV
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
        self.first = comp_def.first !== nothing ? comp_def.first : time_bounds[1]
        self.last  = comp_def.last  !== nothing ? comp_def.last  : time_bounds[2]

        # @info "ComponentInstance evaluating $(comp_id.module_name)"        
        comp_module = Main.eval(comp_id.module_name)

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # CompositeComponentInstances use a standard method that just loops over inner components.
        # TBD: use FunctionWrapper here?
        function get_func(name)
            if is_composite(self)
                return nothing
            end

            func_name = Symbol("$(name)_$(self.comp_id.comp_name)")
            try
                Base.eval(comp_module, func_name)
            catch err
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

@method function ComponentInstance(comp_def::ComponentDef, vars::TV, pars::TP,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def)) where
        {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

    self = ComponentInstance{TV, TP}()
    return ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
end

# These can be called on CompositeComponentInstances and ModelInstances
@method compdef(obj::ComponentInstance) = compdef(comp_id(obj))
# @method dim_value_dict(obj::ComponentInstance) = obj.dim_value_dict
@method has_dim(obj::ComponentInstance, name::Symbol) = haskey(obj.dim_value_dict, name)
@method dimension(obj::ComponentInstance, name::Symbol) = obj.dim_value_dict[name]
@method first_period(obj::ComponentInstance) = obj.first
@method last_period(obj::ComponentInstance)  = obj.last

@class mutable CompositeComponentInstance <: ComponentInstance begin
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}
    
    function CompositeComponentInstance(self::AbstractCompositeComponentInstance,
                                        comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))
        comps_dict = OrderedDict{Symbol, AbstractComponentInstance}()

        for ci in comps
            comps_dict[ci.comp_name] = ci
        end
        
        (vars, pars) = _comp_instance_vars_pars(comps)
        ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
        CompositeComponentInstance(self, comps_dict)
        return self
    end

    # Constructs types of vars and params from sub-components
    function CompositeComponentInstance(comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))
        (vars, pars) = _comp_instance_vars_pars(comps)
        self = new{typeof(vars), typeof(pars)}()
        CompositeComponentInstance(self, comps, comp_def, time_bounds, name)
    end
end

# These methods can be called on ModelInstances as well
@method components(obj::CompositeComponentInstance) = values(obj.comps_dict)
@method has_comp(obj::CompositeComponentInstance, name::Symbol) = haskey(obj.comps_dict, name)
@method compinstance(obj::CompositeComponentInstance, name::Symbol) = obj.comps_dict[name]

@method is_leaf(ci::ComponentInstance) = true
@method is_leaf(ci::CompositeComponentInstance) = false
@method is_composite(ci::ComponentInstance) = !is_leaf(ci)

#
# TBD: Should include only exported vars and pars, right?
# TBD: Use (from build.jl) _combine_exported_vars & _pars?
#
"""
Create a single ComponentInstanceParameters type reflecting those of a composite 
component's parameters, and similarly for its variables.
"""
function _comp_instance_vars_pars(comps::Vector{<: AbstractComponentInstance})
    vtypes  = DataType[]
    vnames  = Symbol[]
    vvalues = []
    vpaths  = []
    
    ptypes  = DataType[]
    pnames  = Symbol[]
    pvalues = []
    ppaths  = []

    for comp in comps
        v = comp.variables
        p = comp.parameters

        append!(vnames, names(v))
        append!(pnames, names(p))

        append!(vtypes, types(v))
        append!(ptypes, types(p))

        append!(vvalues, values(v))
        append!(pvalues, values(p))

        append!(vpaths, comp_paths(v))
        append!(ppaths, comp_paths(p))
    end

    vars = ComponentInstanceVariables(vnames, vtypes, vvalues, vpaths)
    pars = ComponentInstanceParameters(pnames, ptypes, pvalues, ppaths)

    return vars, pars
end

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

"""
    ComponentReference

A container for a component, for interacting with it within a model.
"""
struct ComponentReference <: MimiStruct
    model::Model
    comp_name::Symbol
end

"""
    VariableReference
    
A container for a variable within a component, to improve connect_param! aesthetics,
by supporting subscripting notation via getindex & setindex .
"""
struct VariableReference <: MimiStruct
    model::Model
    comp_name::Symbol
    var_name::Symbol
end
