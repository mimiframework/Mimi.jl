# Begin plotting section
using Plots

"""
Extends the Plots module to be able to take a model information parameters for
convenience. More advanced plotting may require accessing the Plots module directly.
"""
function Plots.plot(m::Model, comp_name::Symbol, parameter::Symbol ; index::Symbol = :time, legend = nothing, x_label::String = string(index), y_label::String = string(parameter))
    if isnull(m.mi)
        error("A model must be run before it can be plotted")
    end

    values = m[comp_name, parameter]

    if legend == nothing && isa(values, Array) && ndims(values)==2
        a = indexlabels(m, comp_name, parameter)
        a = Iterators.filter(i->i!=index, a)
        legend = a[1]
    end

    # Create axis labels
    units = ""
    try
        comp_def = getcompdef(m, comp_name)
        units = comp_def.parameters[parameter].unit

        # was:
        # units = getmetainfo(m, comp_name).parameters[parameter].unit
        units = " [$(units)]"
    end

    # Convert labels from camel case/snake case
    if x_label == string(index)
        x_label = prettifystring(x_label)
    end

    if y_label == string(parameter)
        y_label = prettifystring(y_label)
    end

    x_label = "$(x_label)$(units)"
    y_label = "$(y_label)$(units)"

    plt = plot() # Clear out any previous plots

    if legend == nothing
        # Assume that we are only plotting one line (i.e. it's not split up by regions)
        plt = plot(m.indices_values[index], values, xlabel=x_label, ylabel=y_label)
    else
        # For multiple lines, we need to read the legend labels from legend
        if size(1:size(values)[2]) == size(m.indices_values[legend])
            for line_index in 1:size(values)[2] 
                plot!(plt, m.indices_values[index], values[:,line_index], label = m.indices_values[legend][line_index], xlabel=x_label, ylabel=y_label)
            end
        else
            error("Label dimensions did not match")
        end
    end

    return plt
end

"""
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
Warning: due to limitations in Julia's implementation of regex (or limits in my
understanding of Julia's implementation of regex), cannot handle camelcase strings
with more than 2 consecutive capitals, e.g. fileInTXTFormat -> File In T X T Format
"""
function prettifystring_OLD(s::String)
    if contains(s, "_")
        # Snake Case
        s = replace(s, r"_", s" ")
    else
        # Camel Case
        s = replace(s, r"([a-z])([A-Z])", s"\1 \2")
        s = replace(s, r"([A-Z])([A-Z])", s"\1 \2")
    end

    # Capitalize the first letter of each word
    s_arr = split(s)
    to_ret = ""
    for word in s_arr
        word_caps = "$(uppercase(word[1]))$(word[2:length(word)])"
        to_ret = "$(to_ret)$(word_caps) "
    end

    # Return our string, minus the trailing space that was added
    return to_ret[1:length(to_ret) - 1]
end

"""
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
"""
function prettifystring(s::String)
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


# End plotting section
