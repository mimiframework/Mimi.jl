using Distributions
using CSV
import Base: quantile, rand, rand!, mean, std, var

struct EmpiricalDistribution{T}
    values::Vector{T}
    dist::Distribution

    # N.B. This doesn't copy the vector, so caller must, if required
    function EmpiricalDistribution(values::Vector{T}) where T
        return new{T}(values, DiscreteUniform(1, length(values)))
    end
end

# Load empirical values from a CSV file and generate a distribution. The column
# identified by the symbol or integer index is used to create the distribution.
function EmpiricalDistribution(file::Union{AbstractString, IO}, col::Union{Symbol, Int64})
    df = CSV.read(file)
    values = isa(col, Symbol) ? df[col] : df.columns[col]
    return EmpiricalDistribution(values)
end

# If a column is not identified, use the first column.
function EmpiricalDistribution(file::Union{AbstractString, IO})
    return EmpiricalDistribution(file, 1)
end

#
# Delegate a few functions that we require in our application. 
# No need to be exhaustive here.
#
function mean(d::EmpiricalDistribution)
    return mean(d.values)
end

function std(d::EmpiricalDistribution)
    return std(d.values)
end

function var(d::EmpiricalDistribution)
    return var(d.values)
end

function quantile(d::EmpiricalDistribution, args...)
    indices = quantile(d.dist, args...)
    return d.values[indices]
end

function rand(d::EmpiricalDistribution, args...)
    indices = rand(d.dist, args...)
    return d.values[indices]
end

function rand!(d::EmpiricalDistribution, args...)
    indices = rand!(d.dist, args...)
    return d.values[indices]
end
