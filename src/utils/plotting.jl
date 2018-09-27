using Mimi
using GraphPlot
using Compose

function _open_file(filename)
    if Sys.isapple()
        run(`open $(filename)`)
    elseif Sys.islinux()
        run(`xdg-open $(filename)`)
    elseif Sys.iswindows()
        run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    else
        @warn "Showing plots is not supported on $(Sys.KERNEL)"
    end
end

"""
    plot_comp_graph(m::Model, filename::Union{Nothing, Symbol} = nothing)

Plot the DAG of component connections within model `m` and save to `filename`. If
no `filename` is given, plot will simply display.
"""
function plot_comp_graph(m::Model, filename::Union{Nothing, String} = nothing)
    
    graph = comp_graph(m.md)
    names = map(i -> get_prop(graph, i, :name), vertices(graph))

    plot = gplot(graph, nodelabel=names, nodesize=6, nodelabelsize=6)
    if filename !== nothing
        draw(PDF(filename, 16cm, 16cm), plot)
        return _open_file(filename)
    else
        return plot
    end
end
