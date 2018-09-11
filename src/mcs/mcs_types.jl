using IterableTables
using NamedTuples
using Distributions

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


@enum ScenarioLoopPlacement OUTER INNER
@enum SamplingOptions LHS RANDOM

# SampleStore is a faux Distribution that implements base.rand() 
# to yield stored values.
mutable struct SampleStore{T}
    values::Vector{T}   # generally Int or Float64
    idx::Int            # index of next value to return

    function SampleStore(values::Vector{T}) where T
        return new{T}(values, 1)
    end
end

Base.eltype(ss::SampleStore) = eltype(ss.values)

distribution(ss::SampleStore) = ss.dist

#
# TBD: maybe have a different SampleStore subtype for values drawn from a dist
# versus those loaded from a file, which would be treated as immutable?
#

function Base.quantile(ss::SampleStore{T}, q::Float64) where T
    return quantile(sort(ss.values), q)
end


# TBD: This interpolates values between those in the vector. Is this reasonable?
# Probably shouldn't use correlation on values loaded from a file rather than 
# from a proper distribution.
function Base.quantile(ss::SampleStore{T}, probs::AbstractArray) where T
    return quantile.(ss, probs)
    # return quantile.(sort(ss.values), probs)
end


struct TransformSpec
    paramname::Symbol
    op::Symbol
    rvname::Symbol
    dims::Vector{Any}

    function TransformSpec(paramname::Symbol, op::Symbol, rvname::Symbol, dims::Vector{T}=[]) where T
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
   
        return new(paramname, op, rvname, dims)
    end 
end

"""
    CorrelationSpec

Defines a target rank correlation to establish between the two named random vars.
"""
struct CorrelationSpec
    name1::Symbol
    name2::Symbol
    value::Float64
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

"""
    MonteCarloSimulation
    
Holds all the data that defines a Monte Carlo simulation.
"""
mutable struct MonteCarloSimulation
    trials::Int
    current_trial::Int
    current_data::Any               # holds data for current_trial when current_trial > 0
    rvdict::OrderedDict{Symbol, RandomVariable}
    translist::Vector{TransformSpec}
    corrlist::Vector{CorrelationSpec}
    savelist::Vector{Tuple{Symbol, Symbol}}
    dist_rvs::Vector{RandomVariable{<: Distribution}}
    nt_type::Any                    # a generated NamedTuple type to hold data for a single trial
    models::Vector{Model}
    results::Vector{Dict{Tuple, DataFrame}}

    function MonteCarloSimulation(rvlist::Vector, 
                                  translist::Vector{TransformSpec}, 
                                  corrlist::Vector{CorrelationSpec},
                                  savelist::Vector{Tuple{Symbol, Symbol}})
        self = new()
        self.trials = 0
        self.current_trial = 0
        self.current_data = nothing
        self.rvdict = OrderedDict([rv.name => rv for rv in rvlist])
        self.translist = translist
        self.corrlist = corrlist
        self.savelist = savelist
        self.dist_rvs = [rv for rv in rvlist if rv.dist isa Distribution]
        self.nt_type = NamedTuples.make_tuple(collect(keys(self.rvdict)))

        # These are parallel arrays; each model has a corresponding results dict
        self.models = Vector{Model}(0)
        self.results = [Dict{Tuple, DataFrame}()]
        return self
    end
end


struct MCSIterator{NT}
    mcs::MonteCarloSimulation

    function MCSIterator{NT}(mcs::MonteCarloSimulation) where NT
        return new{NT}(mcs)
    end
end
