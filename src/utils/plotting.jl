using Plots
using GraphPlot
using Compose

# Remove this if plotting.jl is once again included in Mimi.jl. (It was removed
# because Plots causing pre-compilation to fail, and this file is optional.)
using Mimi:
    datumdef, prettify, TimestepArray

"""
    Plots.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
        dim_name::Union{Void, Symbol} = nothing, legend=nothing, 
        x_label=nothing, y_label=nothing)

Extends the Plots module to be able to take a model information parameters for
convenience. More advanced plotting may require accessing the Plots module directly.
"""
function Plots.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
                    dim_name::Union{Void, Symbol} = nothing, legend=nothing, 
                    x_label=nothing, y_label=nothing)
    if m.mi == nothing
        error("A model must be run before it can be plotted")
    end

    md = m.md

    data = m[comp_name, datum_name]
    datum_def = datumdef(m, comp_name, datum_name)
    dims = dimensions(datum_def)

    if dim_name == nothing
        dim_name = dims[1]
    elseif ! (dim_name in dims)
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
        plt = Plots.bar(indices, data, xlabel=x_label, xticks=xticks, ylabel=y_label, legend=:none)

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

function _open_file(filename)
    if is_apple()
        run(`open $(filename)`)
    elseif is_linux()
        run(`xdg-open $(filename)`)
    elseif is_windows()
        run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    else
        warn("Showing plots is not supported on $(Sys.KERNEL)")
    end
end

function plot_comp_graph(m::Model, filename="/tmp/mimi_components.pdf")
    graph = comp_graph(m.md)
    names = map(i -> get_prop(graph, i, :name), vertices(graph))

    draw(PDF(filename, 16cm, 16cm), gplot(graph, nodelabel=names, nodesize=6, nodelabelsize=6))
    _open_file(filename)
end
