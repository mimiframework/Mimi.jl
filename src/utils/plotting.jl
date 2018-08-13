# using Plots
using Mimi
using GraphPlot
using Compose

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

"""
    plot_comp_graph(m::Model, filename="/tmp/mimi_components.pdf")

Plot the DAG of component connectoins within model `m` and save to `filename`.
"""
function plot_comp_graph(m::Model, filename="/tmp/mimi_components.pdf")
    graph = comp_graph(m.md)
    names = map(i -> get_prop(graph, i, :name), vertices(graph))

    draw(PDF(filename, 16cm, 16cm), gplot(graph, nodelabel=names, nodesize=6, nodelabelsize=6))
    _open_file(filename)
end
