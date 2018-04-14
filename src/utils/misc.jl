"""
    interpolate(values, ts=10)

Linearly interpolate annual values from a vector of values
for timestep of length `ts`.
"""
function interpolate(values, ts=10)
    count = length(values)
    newvalues = zeros((count-1) * ts + 1)
    fracs = collect(range(0.0, 0.1, ts))

    for i = 1:count - 1
        start = values[i]
        stop  = values[i+1]
        diff  = stop - start

        start_idx = (i - 1) * ts + 1
        end_idx   = start_idx + ts - 1
        newvalues[start_idx:end_idx] = start + diff * fracs
    end

    newvalues[end] = values[end]
    return newvalues
end

# """
# Accepts a camelcase or snakecase string, and makes it human-readable
# e.g. camelCase -> Camel Case; snake_case -> Snake Case
# Warning: due to limitations in Julia's implementation of regex (or limits in my
# understanding of Julia's implementation of regex), cannot handle camelcase strings
# with more than 2 consecutive capitals, e.g. fileInTXTFormat -> File In T X T Format
# """
# function prettifystring_OLD(s::String)
#     if contains(s, "_")
#         # Snake Case
#         s = replace(s, r"_", s" ")
#     else
#         # Camel Case
#         s = replace(s, r"([a-z])([A-Z])", s"\1 \2")
#         s = replace(s, r"([A-Z])([A-Z])", s"\1 \2")
#     end

#     # Capitalize the first letter of each word
#     s_arr = split(s)
#     to_ret = ""
#     for word in s_arr
#         word_caps = "$(uppercase(word[1]))$(word[2:length(word)])"
#         to_ret = "$(to_ret)$(word_caps) "
#     end

#     # Return our string, minus the trailing space that was added
#     return to_ret[1:length(to_ret) - 1]
# end

"""
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
"""
function prettify(s::String)
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
