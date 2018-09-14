#
# 1. Types supporting parameterized Timestep and Clock objects
#

abstract type AbstractTimestep end

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

mutable struct Clock{T <: AbstractTimestep}
	ts::T

	function Clock{T}(FIRST::Int, STEP::Int, LAST::Int) where T
		return new(FixedTimestep{FIRST, STEP, LAST}(1))
    end
    
    function Clock{T}(TIMES::NTuple{N, Int} where N) where T
        return new(VariableTimestep{TIMES}())
    end
end

mutable struct TimestepArray{T_TS <: AbstractTimestep, T, N}
	data::Array{T, N}

    function TimestepArray{T_TS, T, N}(d::Array{T, N}) where {T_TS, T, N}
		return new(d)
	end

    function TimestepArray{T_TS, T, N}(lengths::Int...) where {T_TS, T, N}
		return new(Array{T, N}(lengths...))
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

abstract type AbstractDimension end

const DimensionKeyTypes   = Union{AbstractString, Symbol, Int, Float64}
const DimensionRangeTypes = Union{UnitRange{Int}, StepRange{Int, Int}}

struct Dimension <: AbstractDimension
    dict::OrderedDict{DimensionKeyTypes, Int}
    key_type::DataType

    function Dimension(keys::Vector{T}) where T <: DimensionKeyTypes
        dict = OrderedDict{T, Int}(collect(zip(keys, 1:length(keys))))
        return new(dict, T)
    end

    function Dimension(rng::DimensionRangeTypes)
        return Dimension(collect(rng))
    end

    Dimension(i::Int) = Dimension(1:i)

    # Support Dimension(:foo, :bar, :baz)
    function Dimension(keys::T...) where T <: DimensionKeyTypes
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
abstract type ModelParameter end

# TBD: rename ScalarParameter, ArrayParameter, and AbstractParameter?

mutable struct ScalarModelParameter{T} <: ModelParameter
    value::T

    function ScalarModelParameter{T}(value::T) where T
        new(value)
    end
end

mutable struct ArrayModelParameter{T} <: ModelParameter
    values::T
    dimensions::Vector{Symbol} # if empty, we don't have the dimensions' name information

    function ArrayModelParameter{T}(values::T, dims::Vector{Symbol}) where T
        new(values, dims)
    end
end

ScalarModelParameter(value) = ScalarModelParameter{typeof(value)}(value)

Base.convert(::Type{ScalarModelParameter{T}}, value::Number) where {T} = ScalarModelParameter{T}(T(value))

Base.convert(::Type{T}, s::ScalarModelParameter{T}) where {T} = T(s.value)

ArrayModelParameter(value, dims::Vector{Symbol}) = ArrayModelParameter{typeof(value)}(value, dims)


abstract type AbstractConnection end

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
    external_param::Symbol  # name of the parameter stored in md.external_params
end

#
# 4. Types supporting structural definition of models and their components
#

# To identify components, we create a variable with the name of the component
# whose value is an instance of this type, e.g.
# const global adder = ComponentId(module_name, comp_name) 
struct ComponentId
    module_name::Symbol
    comp_name::Symbol
end

# Indicates that the object has a `name` attribute
abstract type NamedDef end

# Supertype for vars and params
# abstract type DatumDef <: NamedDef end

# The same structure is used for variables and parameters
mutable struct DatumDef <: NamedDef
    name::Symbol
    datatype::DataType
    dimensions::Vector{Symbol}
    description::String
    unit::String
    datum_type::Symbol          # :parameter or :variable
    default::Any                # used only for Parameters

    function DatumDef(name::Symbol, datatype::DataType, dimensions::Vector{Symbol}, 
                      description::String, unit::String, datum_type::Symbol,
                      default::Any=nothing)
        self = new()
        self.name = name
        self.datatype = datatype
        self.dimensions = dimensions
        self.description = description
        self.unit = unit
        self.datum_type = datum_type
        self.default = default
        return self
    end

end

mutable struct DimensionDef <: NamedDef
    name::Symbol
end

mutable struct ComponentDef  <: NamedDef
    name::Symbol
    comp_id::ComponentId
    variables::OrderedDict{Symbol, DatumDef}
    parameters::OrderedDict{Symbol, DatumDef}
    dimensions::OrderedDict{Symbol, DimensionDef}
    first::Int
    last::Int

    # ComponentDefs are created "empty"; elements are subsequently added 
    # to them via addvariable, add_dimension!, etc.
    function ComponentDef(comp_id::ComponentId)
        self = new()
        self.name = comp_id.comp_name
        self.comp_id = comp_id
        self.variables  = OrderedDict{Symbol, DatumDef}()
        self.parameters = OrderedDict{Symbol, DatumDef}() 
        self.dimensions = OrderedDict{Symbol, DimensionDef}()
        self.first = self.last = 0
        return self
    end
end

# Declarative definition of a model, used to create a ModelInstance
mutable struct ModelDef
    module_name::Symbol     # the module in which this model was defined

    # Components keyed by symbolic name, allowing a given component
    # to occur multiple times within a model.
    comp_defs::OrderedDict{Symbol, ComponentDef}

    dimensions::Dict{Symbol, Dimension}

    number_type::DataType

    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    external_params::Dict{Symbol, ModelParameter}

    sorted_comps::Union{Nothing, Vector{Symbol}}

    is_uniform::Bool
    
    function ModelDef(number_type=Float64)
        self = new()
        self.module_name = nameof(@__MODULE__)
        self.comp_defs = OrderedDict{Symbol, ComponentDef}()
        self.dimensions = Dict{Symbol, Dimension}()
        self.number_type = number_type
        self.internal_param_conns = Vector{InternalParameterConnection}() 
        self.external_param_conns = Vector{ExternalParameterConnection}()
        self.external_params = Dict{Symbol, ModelParameter}()
        self.backups = Vector{Symbol}()
        self.sorted_comps = nothing
        self.is_uniform = true
        return self
    end
end

#
# 5. Types supporting instantiated models and their components
#

# Supertype for variables and parameters in component instances
abstract type ComponentInstanceData end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `p` argument. The main role of this type
# is to provide the convenient `p.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the parameters
struct ComponentInstanceParameters{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each parameter. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    values::TYPES
    names::NTuple{N, Symbol} where N
    types::DataType

    function ComponentInstanceParameters{NAMES,TYPES}(values) where {NAMES,TYPES}
        # println("comp inst params:\n  values=$values\n\n  names=$NAMES\n\n  types=$TYPES\n\n")
        return new(Tuple(values), NAMES, TYPES)
    end
end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `v` argument. The main role of this type
# is to provide the convenient `v.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the variables
struct ComponentInstanceVariables{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each variable. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    values::TYPES
    names::NTuple{N, Symbol} where N
    types::DataType

    function ComponentInstanceVariables{NAMES,TYPES}(values) where {NAMES,TYPES}
        # println("comp inst vars:\n  values=$values\n\n  names=$NAMES\n\n  types=$TYPES\n\n")
        return new(Tuple(values), NAMES, TYPES)
    end
end

mutable struct ComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
    comp_name::Symbol
    comp_id::ComponentId
    variables::TV
    parameters::TP
    dim_dict::Dict{Symbol, Vector{Int}}

    first::Int
    last::Int

    run_timestep::Union{Nothing, Function}
    
    function ComponentInstance{TV, TP}(comp_def::ComponentDef, 
                               vars::TV, pars::TP, 
                               name::Symbol=name(comp_def)) where {TV <: ComponentInstanceVariables, 
                                                                   TP <: ComponentInstanceParameters}
        self = new{TV, TP}()
        self.comp_id = comp_id = comp_def.comp_id
        self.comp_name = name
        self.dim_dict = Dict{Symbol, Vector{Int}}()     # set in "build" stage
        self.variables = vars
        self.parameters = pars
        self.first = comp_def.first
        self.last = comp_def.last        

        comp_module = eval(Main, comp_id.module_name)

        # the try/catch allows components with no run_timestep function (as in some of our test cases)
        self.run_timestep = func = try 
            eval(comp_module, Symbol("run_timestep_$(comp_id.module_name)_$(comp_id.comp_name)"))
        catch err
            nothing
        end
           
        return self
    end
end

# This type holds the values of a built model and can actually be run.
mutable struct ModelInstance
    md::ModelDef

    # Ordered list of components (including hidden ConnectorComps)
    components::OrderedDict{Symbol, ComponentInstance}
  
    firsts::Vector{Int}        # in order corresponding with components
    lasts::Vector{Int}

    function ModelInstance(md::ModelDef)
        self = new()
        self.md = md
        self.components = OrderedDict{Symbol, ComponentInstance}()    
        self.firsts = Vector{Int}()
        self.lasts = Vector{Int}()
        return self
    end
end

#
# 6. User-facing Model types providing a simplified API to model definitions and instances.
#

#
# Provides user-facing API to ModelInstance and ModelDef
#
mutable struct Model
    md::ModelDef
    mi::Union{Nothing, ModelInstance}

    function Model(number_type::DataType=Float64)
        return new(ModelDef(number_type), nothing)
    end

    # Create a copy of a model, e.g., to create marginal models
    function Model(m::Model)
        return new(copy(m.md), nothing)
    end
end

#
# A "model" whose results are obtained by subtracting results of one model from those of another.
#
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
A container for a component, for interacting with it within a model.
"""
struct ComponentReference
    model::Model
    comp_name::Symbol
end

"""
A container for a variable within a component, to improve connect_parameter aesthetics,
by supporting subscripting notation via getindex & setindex .
"""
struct VariableReference
    model::Model
    comp_name::Symbol
    var_name::Symbol
end
