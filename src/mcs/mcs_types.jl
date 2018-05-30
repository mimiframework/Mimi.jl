using IterableTables
using NamedTuples

"""
A RandomVariable can be "assigned" to different model parameters. Its
value can be used directly or applied by adding to, or multiplying by, 
reference values for the indicated parameter. Note that the distribution
must be instantiated, e.g., call as RandomVariable(:foo, Normal()), not
RandomVariable(:foo, Normal).
"""
struct RandomVariable # {T}
    name::Symbol
    dist::Distribution   # T 

    function RandomVariable(name::Symbol, dist::Distribution) # dist::T
        self = new(name, dist)
        return self
    end
end

struct TransformSpec
    paramname::Symbol
    op::Symbol
    rvname::Symbol
    dims::Vector{Any}

    function TransformSpec(paramname::Symbol, op::Symbol, rvname::Symbol, dims::Vector{Any}=[])
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
   
        return new(paramname, op, rvname, dims)
    end 
end

"""
Defines a target rank correlation to establish between the two named random vars.
"""
struct CorrelationSpec
    name1::Symbol
    name2::Symbol
    value::Float64
end


# SampleStore is a faux Distribution that implements base.rand() 
# to yield stored values.
mutable struct SampleStore{T}
    values::Vector{T}   # generally Int or Float64
    idx::Int            # index of next value to return

    function SampleStore(values::Vector{T}) where T
        return new{T}(values, 1)
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
    return s.values[idx:(next_idx - 1)]
end

function Base.reset(s::SampleStore{T}) where T
    s.idx = 1
    return nothing
end

"""
Holds all the data that defines a Monte Carlo simulation.
"""
mutable struct MonteCarloSimulation
    trials::Int
    rvlist::Vector{RandomVariable}      # TBD: needs to be OrderedDict{Symbol, RandomVariable}
    translist::Vector{TransformSpec}
    corrlist::Union{Vector{CorrelationSpec}, Void}
    savelist::Vector{Tuple}
    
    data::DataFrame         # DEPRECATED (replaced by nt_type)
    generated::Bool

    results::Union{Dict{Tuple, DataFrame}, Void}

    nt_type::Any   # a NamedTuple type to hold all for a single trial

    function MonteCarloSimulation(rvlist::Vector{RandomVariable}, 
                                  translist::Vector{TransformSpec}, 
                                  corrlist::Union{Vector{CorrelationSpec}, Void},
                                  savelist::Vector{Tuple})
        # assigned to vars for documentation purposes
        trials = 0
        results = nothing
        df = DataFrame()
        generated = false
        nt_type = NamedTuples.make_tuple([rv.name for rv in rvlist])
        return new(trials, rvlist, translist, corrlist, savelist, df, generated, results, nt_type)
    end
end

# Iterator protocol. `State` is just the trial number
Base.start(mcs::MonteCarloSimulation) = 1
Base.next(mcs, trialnum) = (get_trial_data(trialnum), trialnum + 1)
Base.done(mcs, trialnum) = (trialnum == mcs.trials)
