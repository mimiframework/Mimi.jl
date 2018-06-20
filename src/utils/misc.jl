"""
    interpolate(values, ts=10)

Linearly interpolate annual values from a vector of values
for timestep of length `ts`.
"""
function interpolate(values::Vector{T}, ts::Int=10) where T <: Union{Float64, Int}
    count = length(values)
    newvalues = zeros((count-1) * ts + 1)
    fracs = collect(range(0.0, 1/ts, ts))

    for i = 1:count - 1
        first = values[i]
        last  = values[i+1]
        diff  = last - first

        first_idx = (i - 1) * ts + 1
        end_idx   = first_idx + ts - 1
        newvalues[first_idx:end_idx] = first + diff * fracs
    end

    newvalues[end] = values[end]
    return newvalues
end

# MacroTools has a "prettify", so we have to import to "extend"
# even though our function is unrelated. This seems unfortunate.
import MacroTools.prettify

"""
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
"""
function MacroTools.prettify(s::String)
    s = replace(s, r"_", s" ")
    s = replace(s, r"([a-z])([A-Z])",  s"\1 \2")
    s = replace(s, r"([A-Z]+)([A-Z])", s"\1 \2")        # handle case of consecutive caps by splitting last from rest

    # Capitalize the first letter of each word
    s_arr = split(s)

    for (i, word) in enumerate(s_arr)
        s_arr[i] = "$(uppercase(word[1]))$(word[2:length(word)])"
    end

    # Return our string
    return join(s_arr, " ")
end

prettify(s::Symbol) = prettify(string(s))
