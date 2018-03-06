## Mimi UI

global app = nothing

#function to get variable data
include("buildspecs.jl")
include("getparameters.jl")

function explore(model; title = "Electron")
    
    #get variable data
    speclist = getspeclist(model)
    speclistJSON = JSON.json(speclist)

    #start Electron app
    if app == nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\", "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1000, "height" => 700)

    if is_windows()
        w = Window(app, URI("file:///$(mainpath)"), options = windowopts)
    else
        w = Window(app, URI("file://$(mainpath)"), options = windowopts)
    end

    #refresh variable list
    result = run(w, "refresh($speclistJSON)")
    
end
