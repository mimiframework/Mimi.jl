using Logging

# Enable @debug logging
function set_log_level(level)
    global_logger(ConsoleLogger(stderr, level))
end

log_debug() = set_log_level(Logging.Debug)
log_info()  = set_log_level(Logging.Info)


"""
    interpolate(values, ts=10)

Linearly interpolate annual values from a vector of values
for timestep of length `ts`.
"""
function interpolate(oldvalues::Vector{T}, ts::Int=10) where T <: Union{Float64, Int}
    count = length(oldvalues)
    newvalues::Vector{Float64} = zeros((count-1) * ts + 1)
    fracs = collect(0.0:1/ts:1.0)

    for i = 1:count - 1
        first = oldvalues[i]
        last  = oldvalues[i+1]
        diff  = last - first

        first_idx = (i - 1) * ts + 1
        end_idx   = first_idx + ts - 1
        newvalues[first_idx:end_idx] = first .+ diff * fracs[1:end-1]
    end

    newvalues[end] = oldvalues[end]
    return newvalues
end

"""
    pretty_string(s::String)
    
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
"""
function pretty_string(s::String)
    s = replace(s, r"_" => s" ")
    s = replace(s, r"([a-z])([A-Z])" =>  s"\1 \2")
    s = replace(s, r"([A-Z]+)([A-Z])" => s"\1 \2")        # handle case of consecutive caps by splitting last from rest

    # Capitalize the first letter of each word
    s_arr = split(s)

    for (i, word) in enumerate(s_arr)
        s_arr[i] = "$(uppercase(word[1]))$(word[2:length(word)])"
    end

    # Return our string
    return join(s_arr, " ")
end

pretty_string(s::Symbol) = pretty_string(string(s))
