using Plots

"""
Extends the Plots module to be able to take a model information parameters for
convenience. More advanced plotting may require accessing the Plots module directly.
"""
function Plots.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
                    dim_name::Union{Void, Symbol} = nothing, legend=nothing, 
                    x_label=nothing, y_label=nothing)
    if isnull(m.mi)
        error("A model must be run before it can be plotted")
    end

    md = m.md

    data = m[comp_name, datum_name]
    datum_def = datumdef(m, comp_name, datum_name)
    dims = dimensions(datum_def)

    if dim_name == nothing
        dim_name = dims[1]
    elseif ! dim_name in dims
        error("$comp_name.$datum_name has no dimension named $dim_name")
    end

    if legend == nothing && isa(data, Array) && ndims(data) == 2
        a = filter(i -> i != dim_name, dims)
        legend = a[1]
    end

    # Create axis labels
    units = ""
    try
        units = unit(datum_def)
        units = units == "" ? "" : " [$(units)]"
    end

    # Convert labels from camel case/snake case
    x_label = x_label == nothing ? prettify(dim_name)   : x_label
    y_label = y_label == nothing ? prettify(datum_name) : y_label

    # x_label = "$(x_label)$(units)"
    y_label = "$(y_label)$(units)"

    plt = plot() # Clear out any previous plots

    dim = dimension(md, dim_name)
    dim_keys = collect(keys(dim))

    if length(dims) == 1
        indices = collect(values(dim))
        xticks = (indices, dim_keys)
        plt = bar(indices, data, xlabel=x_label, xticks=xticks, ylabel=y_label, legend=:none)

    elseif legend == nothing
        # Assume that we are only plotting one line (i.e. it's not split up by regions)
        plt = plot(dim_keys, data, xlabel=x_label, ylabel=y_label)

    else
        # For multiple lines, we need to read the legend labels from legend
        cols = size(data)[2]
        legend_dim = dimension(md, legend)
        if cols == length(legend_dim)
            for label in keys(legend_dim)
                col_num = legend_dim[label]
                plot!(plt, dim_keys, data[:, col_num], label=label, xlabel=x_label, ylabel=y_label)
            end
        else
            error("Label dimensions did not match")
        end
    end

    return plt
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
