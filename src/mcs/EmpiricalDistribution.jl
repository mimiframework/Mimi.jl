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

"""
EmpiricalDistribution(file::Union{AbstractString, IO}, 
                      value_col::Union{Symbol, String, Int64},
                      prob_col::Union{Void, Symbol, String, Int64}=nothing)

Load empirical values from a CSV or XLS(X) file and generate a distribution. 

For CSV files, `value_col` identifies by the column name or integer index for the values 
to use, and the optional `prob_col` identifies the column name or integer index for the
probabilities to use. If not provide, equal probabilities are assumed for each value.

If an XLS or XLSX file is given, the `value_col` and `prob_col` should be fully specified
Excel data ranges, e.g., "Sheet1!A2:A1002", indicating the values to extract from the file.
"""
function EmpiricalDistribution(filename::AbstractString,
                               value_col::Union{Symbol, AbstractString, Int64},
                               prob_col::Union{Void, Symbol, AbstractString, Int64}=nothing;
                               value_type::DataType=Any)
    probs = nothing

    if endswith(lowercase(filename), ".csv")
        df = CSV.read(filename)
        values = isa(value_col, Symbol) ? df[value_col] : df.columns[value_col]
        
        if prob_col != nothing
            probs = isa(prob_col, Symbol) ? df[prob_col] : df.columns[prob_col]
        end
    else
        f = openxl(filename)
        data = readxl(f, value_col)
        values = Vector{value_type}(data[:,1])

        if prob_col != nothing
            data = readxl(f, prob_col)
            probs = Vector{Float64}(data[:,1])
        end
    end
    return EmpiricalDistribution(values, probs)
end

# If a column is not identified, use the first column.
function EmpiricalDistribution(filename::AbstractString)
    return EmpiricalDistribution(filename, 1)
end

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
