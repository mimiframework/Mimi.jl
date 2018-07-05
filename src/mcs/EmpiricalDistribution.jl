using Distributions

struct EmpiricalDistribution{T}
    values::Vector{T}
    weights::ProbabilityWeights
    dist::Distribution

    # Create an empirical distribution from a vector of values and an optional
    # vector of probabilities for each value. If not provided, the values are
    # assumed to be equally likely.
    # N.B. This doesn't copy the values vector, so caller must, if required
    function EmpiricalDistribution(values::Vector{T}, probs::Union{Void, Vector{Float64}}=nothing) where T
        n = length(values)
        if probs == nothing
            probs = Vector{Float64}(n)
            probs[:] = 1/n
        elseif length(probs) != n
            error("Vectors of values and probabilities must be equal lengths")
        end

        # If the probs don't exactly sum to 1, but are close, tweak
        # the final value so the sum is 1.
        total = sum(probs)
        if 0 < (1 - total) < 1E-5
            probs[end] += 1 - total
        end

        weights = ProbabilityWeights(probs)

        return new{T}(values, weights, Categorical(probs))
    end
end

# """
# EmpiricalDistribution(obj::Any,
#                       value_col::Union{Symbol, String, Int},
#                       prob_col::Union{Void, Symbol, String, Int}=nothing;
#                       value_type::DataType=Any)

# Load empirical values from an object returned by load() and generate a distribution. 
# Typical usage might be:

# `d = EmpiricalDistribution(load("foo.xlsx", otherpars=...), :valcolname, :probcolname)`

# The `value_col` identifies by the column name or integer index for the values 
# to use, and the optional `prob_col` identifies the column name or integer index for the
# probabilities to use. If `prob_col` is not provide, equal probabilities are assumed 
# for each value.
# """
# function EmpiricalDistribution(obj::Any,
#                                value_col::Union{Symbol, AbstractString, Int},
#                                prob_col::Union{Void, Symbol, AbstractString, Int}=nothing;
#                                value_type::DataType=Any)
#     probs = nothing

#     values = isa(value_col, Symbol) ? df[value_col] : df.columns[value_col]
        
#     if prob_col != nothing
#         probs = Vector{Float64}(isa(prob_col, Symbol) ? df[prob_col] : df.columns[prob_col])
#     end

#     return EmpiricalDistribution(values, probs)
# end

#
# Delegate a few functions that we require in our application. 
# No need to be exhaustive here.
#
function Base.mean(d::EmpiricalDistribution)
    return mean(d.values, d.weights)
end

function Base.std(d::EmpiricalDistribution)
    return std(d.values, d.weights, corrected=true)
end

function Base.var(d::EmpiricalDistribution)
    return var(d.values, d.weights, corrected=true)
end

function Base.quantile(d::EmpiricalDistribution, args...)
    indices = quantile(d.dist, args...)
    return d.values[indices]
end

function Base.rand(d::EmpiricalDistribution, args...)
    indices = rand(d.dist, args...)
    return d.values[indices]
end

function Base.rand!(d::EmpiricalDistribution, args...)
    indices = rand!(d.dist, args...)
    return d.values[indices]
end
