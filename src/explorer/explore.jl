## Mimi UI
using VegaLite

global app = nothing

#include functions and modules
include("buildspecs.jl")

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

function explore(m::Model, comp_name::Symbol, datum_name::Symbol; 
    dim_name::Union{Void, Symbol} = nothing, legend=nothing, 
    x_label=nothing, y_label=nothing)

    if m.mi == nothing
        error("A model must be run before it can be plotted")
    end
    
    #TODO: add keyword argument cases

    spec = Mimi._spec_for_item(m, comp_name, datum_name)["VLspec"]
    VegaLite.VLSpec{:plot}(spec)
end
