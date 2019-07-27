## Mimi UI

global app = nothing

#include functions and modules
include("buildspecs.jl")

"""
    explore(m::Model; title = "Electron")

Produce a UI to explore the parameters and variables of Model `m` in a Window with title `title`.
"""
function explore(m::Model; title = "Electron")
    
    if m.mi == nothing
        error("A model must be run before it can be plotted")
    end

    #get variable data
    speclist = spec_list(m)
    speclistJSON = JSON.json(speclist)

    #start Electron app
    if app == nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\", "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1000, "height" => 700)
    slashes = is_windows() ? "///" : "//"
    w = Window(app, URI("file:$(slashes)$(mainpath)"), options = windowopts)

    #refresh variable list
    result = run(w, "refresh($speclistJSON)")
    
    return w

end

"""
    explore(m::Model, comp_name::Symbol, datum_name::Symbol)

Plot a specific `datum_name` (a `variable` or `parameter`) of Model `m`.
"""

function explore(m::Model, comp_name::Symbol, datum_name::Symbol)
    error("This function is disabled in the macfix branch.")
end
