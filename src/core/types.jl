using DataStructures
using LightGraphs

#
# 1. Types supporting parameterized Timestep and Clock objects
#

mutable struct Timestep{Start, Step, Stop}
	t::Int
end

# TBD: Consider renaming and simplifying this. (Not currently used.)
mutable struct TimestepNew
    start::Int      # the first year/month etc. that is relevant
    step::Int       # interval between periods, for constant timesteps
    stop::Int       # the final year/month etc. that is relevant
    current::Int    # the current period

    function TimestepNew(start::Int, step::Int, stop::Int, current::Int=1)
        self = new(start, step, stop)
        self.current = current
        return self
    end
end

mutable struct Clock
	ts::Timestep

	function Clock(start::Int, step::Int, stop::Int)
		self = new()
		self.ts = Timestep{start, step, stop}(1)
		return self
	end
end

# TBD: consider using this merged type in place of TimestepVector/TimestepMatrix
mutable struct TimestepArray{T, N}
    start::Int
    step::Int
	data::Array{T, N}

    function TimestepArray{T, N}(start::Int, step::Int, data::Array{T, N}) where {T, N}
		self = new(start, step, data)
		return self
	end

    function TimestepArray{T, N}(start::Int, step::Int, dims::Int...) where {T, N}
        num_dims = length(dims)
        
        if num_dims != N
            error("TimestepArray: number of dimensions ($num_dims) does not match declared value of N ($N)")
        end

        if ! num_dims in (1, 2)
            error("TimestepArray supports only 1 or 2 dimensions currently.")
        end

        data = Array{T, N}(dims...)
		self = new(start, step, data)
		self.data = Vector{T}(i)
		return self
	end
end

# TBD: Pseudo-constructors for consolidated version
# TimestepVector(start::Int, len::Int, data::Array{T, 1}) where T = TimestepArray{T, 1}(start, len, data)
# TimestepMatrix(start::Int, len::Int, data::Array{T, 2}) where T = TimestepArray{T, 2}(start, len, data)

# TimestepVector(start::Int, len::Int, T::DataType, dims::Int...) = TimestepArray{T, 1}(start, len, dims...)
# TimestepMatrix(start::Int, len::Int, T::DataType, dims::Int...) = TimestepArray{T, 2}(start, len, dims...)


abstract type AbstractTimestepMatrix end

# don't need to encode N (number of dimensions) as a type parameter because we 
# are hardcoding it as 1 for the vector case
mutable struct TimestepVector{T, Start, Step} <: AbstractTimestepMatrix
	data::Vector{T}

    function TimestepVector{T, Start, Step}(d::Vector{T}) where {T, Start, Step}
		v = new()
		v.data = d
		return v
	end

    function TimestepVector{T, Start, Step}(i::Int) where {T, Start, Step}
		v = new()
		v.data = Vector{T}(i)
		return v
	end
end

# don't need to encode N (number of dimensions) as a type parameter because we 
# are hardcoding it as 2 for the matrix case
mutable struct TimestepMatrix{T, Start, Step} <: AbstractTimestepMatrix
	data::Array{T, 2}

    function TimestepMatrix{T, Start, Step}(d::Array{T, 2}) where {T, Start, Step}
		m = new()
		m.data = d
		return m
	end

    function TimestepMatrix{T, Start, Step}(i::Int, j::Int) where {T, Start, Step}
		m = new()
		m.data = Array{T, 2}(i, j)
		return m
	end
end

#
# 2. Dimensions
#
abstract type AbstractDimension end

struct Dimension <: AbstractDimension
    dict::OrderedDict
    key_type::DataType

    function Dimension(keys::Vector)
        key_type = eltype(keys)
        dict = OrderedDict{key_type, Int64}(collect(zip(keys, 1:length(keys))))
        return new(dict, key_type)
    end

    function Dimension(rng::Range)
        return Dimension(collect(rng))
    end

    # Support Dimension(:foo, :bar, :baz)
    function Dimension(keys...)
        vector = [key for key in keys]
        return Dimension(vector)
    end
end

#
# Simple optimization for ranges since indices are computable.
# Unclear whether this is really any better than simply using 
# a dict for all cases. Might scrap this in the end.
#
mutable struct RangeDimension <: AbstractDimension
    range::Range
 end

#
# 3. Types supporting Parameters and their connections
#

abstract type ModelParameter end

mutable struct ScalarModelParameter <: ModelParameter
    value
end

mutable struct ArrayModelParameter <: ModelParameter
    values
    dimensions::Vector{Symbol} # if empty, we don't have the dimensions' name information
end

abstract type AbstractConnection end

struct InternalParameterConnection <: AbstractConnection
    src_comp_name::Symbol
    src_var_name::Symbol
    dst_comp_name::Symbol
    dst_par_name::Symbol
    ignoreunits::Bool
    backup::Union{Symbol, Void} # a Symbol identifying the external param providing backup data, or nothing
    offset::Int

    function InternalParameterConnection(src_comp::Symbol, src_var::Symbol, dst_comp::Symbol, dst_par::Symbol,
                                         ignoreunits::Bool, backup::Union{Symbol, Void}=nothing; offset::Int=0)
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
abstract type DatumDef <: NamedDef end
#
# Do we need separate equivalent types for vars and params? Just defined one as, say, DatumDef?
#
mutable struct VariableDef <: DatumDef
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}          # TBD: why isn't this just Vector{Symbol}?
    description::String
    unit::String
end

mutable struct ParameterDef <: DatumDef
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}          # TBD: why isn't this just Vector{Symbol}?
    description::String
    unit::String
end

mutable struct DimensionDef <: NamedDef
    name::Symbol
end

mutable struct ComponentDef  <: NamedDef
    name::Symbol
    comp_id::ComponentId
    variables::OrderedDict{Symbol, VariableDef}
    parameters::OrderedDict{Symbol, ParameterDef}
    dimensions::OrderedDict{Symbol, DimensionDef}
    run_expr::Union{Void, Expr}   # the expression that will create the run_timestep function
    init_expr::Union{Void, Expr}  # the expression that will create the init function

    start::Int
    stop::Int

    # ComponentDefs are created "empty"; elements are subsequently added 
    # to them via addvariable, add_dimension, etc.
    function ComponentDef(comp_id::ComponentId)
        self = new()
        self.name = comp_id.comp_name
        self.comp_id = comp_id
        self.variables  = OrderedDict{Symbol, VariableDef}()
        self.parameters = OrderedDict{Symbol, ParameterDef}() 
        self.dimensions = OrderedDict{Symbol, DimensionDef}()
        self.run_expr   = nothing
        self.init_expr  = nothing
        self.start = self.stop = 0
        return self
    end
end

# Declarative definition of a model used to create a ModelInstance
mutable struct ModelDef
    module_name::Symbol     # the module in which this model was defined

    # Components keyed by symbolic name, allowing a given component
    # to occur multiple times within a model.
    comp_defs::OrderedDict{Symbol, ComponentDef}

    # TBD: replace this trio of structures with the Dimension type
    # - change run() to get the model's Dict{Symbol, Dimension}
    # - fix copy(md::ModelDef) (see notes there)
    # - indexcounts() => dim_counts(md) = Dict([name => length(value) for (name, value) in md.dimensions])
    # - indexvalues() => dim_keys(md) = Dict([name => value for (name, value) in md.dimensions])
    # - timelabels() => keys(dimension(m, :time))
    #      Though better to do: dim = dimension(md, :time); v = values(dim); k = keys(dim); l = length(dim)
    index_counts::Dict{Symbol, Int}
    index_values::Dict{Symbol, Vector{Any}}
    # time_labels::Vector

    dimensions::Dict{Symbol, Dimension}

    number_type::DataType

    # TBD: Should conns be Vector{AbstractConnection}, or two parameters for internal/external?
    # Internal connections that the ModelDef will know about.
    internal_param_conns::Vector{InternalParameterConnection}
    external_param_conns::Vector{ExternalParameterConnection}

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    backups::Vector{Symbol}

    external_params::Dict{Symbol, ModelParameter}

    funcs_generated::Bool

    sorted_comps::Union{Void, Vector{Symbol}}

    function ModelDef(number_type=Float64)
        self = new()
        self.module_name = module_name(current_module())
        self.comp_defs = OrderedDict{Symbol, ComponentDef}()
        self.index_counts = Dict{Symbol, Int}()
        self.index_values = Dict{Symbol, Vector{Any}}()
        self.dimensions = Dict{Symbol, Dimension}()
        self.number_type = number_type
        # self.time_labels = Vector()
        self.internal_param_conns = Vector{InternalParameterConnection}() 
        self.external_param_conns = Vector{ExternalParameterConnection}()
        self.external_params = Dict{Symbol, ModelParameter}()
        self.backups = Vector{Symbol}()
        self.funcs_generated = false
        self.sorted_comps = nothing
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
    names::Tuple
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
    names::Tuple
    types::DataType

    function ComponentInstanceVariables{NAMES,TYPES}(values) where {NAMES,TYPES}
        # println("comp inst vars:\n  values=$values\n\n  names=$NAMES\n\n  types=$TYPES\n\n")
        return new(Tuple(values), NAMES, TYPES)
    end
end

mutable struct ComponentInstance
    comp_name::Symbol
    comp_id::ComponentId
    vars::ComponentInstanceVariables        # TBD: rename variables and parameters to be consistent with ComponentDef
    pars::ComponentInstanceParameters
    dimensions::Vector{Symbol}  # was "indices" previously

    start::Int
    stop::Int
    
    function ComponentInstance(comp_def::ComponentDef, 
                               vars::ComponentInstanceVariables, 
                               pars::ComponentInstanceParameters, 
                               name::Symbol=name(comp_def))
        self = new()
        self.comp_id = comp_def.comp_id
        self.comp_name = name
        self.dimensions = map(dim -> dim.name, dimensions(comp_def))
        self.vars = vars
        self.pars = pars
        self.start = comp_def.start
        self.stop = comp_def.stop

        return self
    end
end

# This type holds the values of a built model and can actually be run.
mutable struct ModelInstance
    md::ModelDef

    # Ordered list of components (including hidden ConnectorComps)
    components::OrderedDict{Symbol, ComponentInstance}

    conns::Vector{InternalParameterConnection}  # or should this be in ModelDef?
   
    starts::Vector{Int}        # in order corresponding with components
    stops::Vector{Int}

    function ModelInstance(md::ModelDef)
        self = new()
        self.md = md
        self.components = OrderedDict{Symbol, ComponentInstance}() 
        self.conns = Vector{InternalParameterConnection}()
        self.starts = Vector{Int}()
        self.stops = Vector{Int}()
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
    mi::Union{Void, ModelInstance}

    function Model(number_type::DataType=Float64)
        self = new()
        self.md = ModelDef(number_type)
        self.mi = nothing
        return self
    end
end

#
# A "model" whose results are obtained by subtracting results of one model from those of another.
#
struct MarginalModel
    base::Model
    marginal::Model
    delta::Float64
end

function getindex(mm::MarginalModel, comp_name::Symbol, name::Symbol)
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

#
# TBD: VariableReference appears to be unused other than in an unused setindex! method.
# Deprecated, or for user API?
#
"""
A container for a variable within a component, to improve connect_parameter aesthetics,
by supporting subscripting notation via getindex & setindex .
"""
struct VariableReference
    model::Model
    comp_name::Symbol
    var_name::Symbol
end
