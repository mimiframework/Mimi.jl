## Mimi UI

global app = nothing

#include functions and modules
include("buildspecs.jl")

"""
    explore(model; title = "Electron")

Produce a UI to explore the parameters and variables of `model` in a Window with title `title`.
"""
function explore(model; title = "Electron")
    
    #get variable data
    speclist = spec_list(model)
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
