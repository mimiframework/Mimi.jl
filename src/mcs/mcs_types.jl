using Distributions
using Statistics

@enum ScenarioLoopPlacement OUTER INNER

"""
    RandomVariable{T}

A RandomVariable can be "assigned" to different model parameters. Its
value can be used directly or applied by adding to, or multiplying by, 
reference values for the indicated parameter. Note that the distribution
must be instantiated, e.g., call as RandomVariable(:foo, Normal()), not
RandomVariable(:foo, Normal).
"""
struct RandomVariable{T}
    name::Symbol
    dist::T 

    function RandomVariable(name::Symbol, dist::T) where T
        self = new{T}(name, dist)
        return self
    end
end

Base.eltype(rv::RandomVariable) = eltype(rv.dist)

distribution(rv::RandomVariable) = rv.dist

abstract type PseudoDistribution end

"""     ReshapedDistribution
A pseudo-distribution that returns a reshaped array of values from the
stored distribution and dimensions.

Example:
    rd = ReshapedDistribution([5, 5], Dirichlet(25,1))
"""
struct ReshapedDistribution <: PseudoDistribution
    dims::Vector{Int}
    dist::Distribution
end

function Base.rand(rd::ReshapedDistribution, draws::Int=1)
    return [reshape(rand(rd.dist), rd.dims...) for i in 1:draws]
end


# SampleStore is a faux Distribution that implements base.rand() 
# to yield stored values.
mutable struct SampleStore{T} <: PseudoDistribution
    values::Vector{T}       # generally Int or Float64
    idx::Int                # index of next value to return
    dist::Union{Nothing, Distribution, PseudoDistribution}  # original distribution, if any

    function SampleStore(values::Vector{T}, dist::Union{Nothing, Distribution, PseudoDistribution}=nothing) where T
        return new{T}(values, 1, dist)
    end
end

Base.eltype(ss::SampleStore) = eltype(ss.values)

#
# TBD: maybe have a different SampleStore subtype for values drawn from a dist
# versus those loaded from a file, which would be treated as immutable?
#

function Statistics.quantile(ss::SampleStore{T}, q::Float64) where T
    return quantile(sort(ss.values), q)
end


# TBD: This interpolates values between those in the vector. Is this reasonable?
# Probably shouldn't use correlation on values loaded from a file rather than 
# from a proper distribution.
function Statistics.quantile(ss::SampleStore{T}, probs::AbstractArray) where T
    return quantile(sort(ss.values), probs)
end

Base.length(ss::SampleStore{T}) where T = length(ss.values)

Base.iterate(ss::SampleStore{T}) where T = iterate(ss.values)
Base.iterate(ss::SampleStore{T}, idx) where T = iterate(ss.values, idx)

struct TransformSpec
    compname::Union{Nothing, Symbol} # if this is not nothing we assume the paramname is a shared model parameter
    paramname::Symbol
    op::Symbol
    rvname::Symbol
    dims::Vector{Any}

    function TransformSpec(paramname::Symbol, op::Symbol, rvname::Symbol, dims::Vector{T}=[]) where T
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
        return new(nothing, paramname, op, rvname, dims)
    end 

    function TransformSpec(compname::Union{Nothing, Symbol}, paramname::Symbol, op::Symbol, rvname::Symbol, dims::Vector{T}=[]) where T
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
        return new(compname, paramname, op, rvname, dims)
    end 
end

struct TransformSpec_ModelParams
    paramnames::Vector{Symbol}
    op::Symbol
    rvname::Symbol
    dims::Vector{Any}

    function TransformSpec_ModelParams(paramnames::Vector{Symbol}, op::Symbol, rvname::Symbol, dims::Vector{T}=[]) where T
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
        return new(paramnames, op, rvname, dims)
    end 
end

"""
    Base.rand(s::SampleStore{T}, n::Int=1) where T

Pseudo `rand`` function that just returns the next `n` values from the vector of
stored values. Currently does not support cycling through results multiple times,
but you can `reset` the `SampleStore` to reuse it.
"""
function Base.rand(s::SampleStore{T}, n::Int=1) where T
    idx = s.idx
    s.idx = next_idx = idx + n
    return n > 1 ? s.values[idx:(next_idx - 1)] : s.values[idx]
end

function Base.reset(s::SampleStore{T}) where T
    s.idx = 1
    return nothing
end

abstract type AbstractSimulationData end

"""
    SimulationDef
    
Holds all the data that defines a simulation.
"""
mutable struct SimulationDef{T}
    rvdict::OrderedDict{Symbol, RandomVariable}
    translist::Vector{TransformSpec}
    savelist::Vector{Tuple{Symbol, Symbol}}
    nt_type::Any                    # a generated NamedTuple type to hold data for a single trial
    data::T                         # data specific to a given sensitivity analysis method
    payload::Any                    # opaque (to Mimi) data the user wants access to in callbacks

    function SimulationDef{T}(rvlist::Vector, 
                           translist::Vector{TransformSpec}, 
                           savelist::Vector{Tuple{Symbol, Symbol}},
                           data::T) where T <: AbstractSimulationData
        self = new()
        self.rvdict = OrderedDict([rv.name => rv for rv in rvlist])
        self.translist = translist
        self.savelist = savelist

        names = (keys(self.rvdict)...,)
        types = [eltype(fld) for fld in values(self.rvdict)]
        self.nt_type = NamedTuple{names, Tuple{types...}}

        self.data = data
        self.payload = nothing

        return self
    end
end

"""
    SimulationInstance{T}
    
Holds all the data that defines simulation results.
"""
mutable struct SimulationInstance{T}
    trials::Int
    current_trial::Int
    current_data::Any               # holds data for current_trial when current_trial > 0
    sim_def::SimulationDef{T} where T <: AbstractSimulationData
    models::Vector{M} where M <: AbstractModel
    results::Vector{Dict{Tuple, DataFrame}}
    payload::Any
    translist_modelparams::Vector{TransformSpec_ModelParams} 

    function SimulationInstance{T}(sim_def::SimulationDef{T}) where T <: AbstractSimulationData
        self = new()
        self.trials = 0
        self.current_trial = 0
        self.current_data = nothing
        self.sim_def = deepcopy(sim_def)
        self.payload = deepcopy(self.sim_def.payload)

        # This will mirror self.sim_def.translist, but can only be created after 
        # models are added because it looks for the actual model parameter 
        # names for unshared parameters used in the statements, and tries to resolve
        # ones written as shared parameters but which may in actuality be unshared
        # ie. defaults
        self.translist_modelparams = Vector{TransformSpec_ModelParams}(undef, 0)

        # These are parallel arrays; each model has a corresponding results dict
        self.models = Vector{AbstractModel}(undef, 0)
        self.results = [Dict{Tuple, DataFrame}()]

        return self
    end
end

"""
    SimulationDef{T}() where T <: AbstractSimulationData

Allow creation of an "empty" SimulationDef instance.
"""
function SimulationDef{T}() where T <: AbstractSimulationData
    SimulationDef{T}([], TransformSpec[], Tuple{Symbol, Symbol}[], T())
end

"""
    set_payload!(sim_def::SimulationDef, payload)

Attach a user's `payload` to the `SimulationDef`. A copy of the payload object
will be stored in the `SimulationInstance` at run time so it can be
accessed in scenario and pre-/post-trial callback functions. The value
is not used by Mimi in any way; it can be anything useful to the user.
"""
set_payload!(sim_def::SimulationDef, payload) = (sim_def.payload = payload)

"""
    payload(sim_def::SimulationDef)

Return the `payload` value set by the user via `set_payload!()`.
"""
payload(sim_def::SimulationDef) = sim_def.payload

"""
    payload(sim_inst::SimulationInstance)

Return the copy of the `payload` value stored in the `SimulationInstance` set by the user via `set_payload!()`.
"""
payload(sim_inst::SimulationInstance) = sim_inst.payload

struct MCSData <: AbstractSimulationData end

const MonteCarloSimulationDef = SimulationDef{MCSData}
const MonteCarloSimulationInstance = SimulationInstance{MCSData}

struct SimIterator{NT, T}
    sim_inst::SimulationInstance{T}

    function SimIterator{NT, T}(sim_inst::SimulationInstance{T}) where {NT <: NamedTuple, T <: AbstractSimulationData}
        return new{NT, T}(sim_inst)
    end
end

function getdataframe(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; model::Int = 1)
    return sim_inst.results[model][(comp_name, datum_name)]
end

function Base.getindex(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; model::Int = 1)
    error("getindex method for `SimulationInstance` has been replaced with getdataframe function for consistency of return type, please use getdataframe instead")
end
