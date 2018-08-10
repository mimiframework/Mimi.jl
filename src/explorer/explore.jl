## Mimi UI
using VegaLite

global app = nothing

#include functions and modules
include("buildspecs.jl")

function explore(m::Model; title = "Electron")
    
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

function explore(m::Model, comp_name::Symbol, datum_name::Symbol; 
    dim_name::Union{Void, Symbol} = nothing)

    #TODO-EXPLORER: add case for handling a given dim_name?

    spec = Mimi._spec_for_item(model, comp_name, datum_name)["VLspec"]
    specJSON = JSON.json(spec)
end
