## Mimi UI
using VegaLite
using FilePaths
import FileIO:save
export save

global app = nothing

#include functions and modules
include("buildspecs.jl")

"""
    explore(m::Model; title = "Electron")

Produce a UI to explore the parameters and variables of Model `m` in a Window with title `title`.
"""
function explore(m::Model; title = "Electron")
    
    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end

    #start Electron app
    if app === nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\" => "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1000, "height" => 700)
    w = Window(app, URI(joinpath(@__PATH__, "assets", "main.html")), options = windowopts)
    
    #set async block to process messages
    @async for msg in msgchannel(w)

        spec = _spec_for_item(m, Symbol(msg["comp_name"]), Symbol(msg["item_name"]))
        specJSON = JSON.json(spec)

        run(w, "display($specJSON)")
    end

    #refresh variable list
    menulist = menu_item_list(m)
    menulistJSON = JSON.json(menulist)

    result = run(w, "refresh($menulistJSON)")
    
    return w

end

"""
    explore(m::Model, comp_name::Symbol, datum_name::Symbol)

Plot a specific `datum_name` (a `variable` or `parameter`) of Model `m`.
"""
function explore(m::Model, comp_name::Symbol, datum_name::Symbol)

    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end
    
    spec = Mimi._spec_for_item(m, comp_name, datum_name)["VLspec"]
    spec === nothing && error("Spec cannot be built.")        

    return VegaLite.VLSpec{:plot}(spec)
end

"""
    function vega_plot(filepath::String, p::VegaLite.VLSpec{:plot})

Save a the plot `p` as `filepath`.  Simple wrapper function for VegaLite's `save` function.
"""
function save_vega_plot(filepath::String, p::VegaLite.VLSpec{:plot})
    VegaLite.save(filepath, p);
end
