## Mimi UI
using DataFrames
using JSON
using Electron

#function to get variable data
include("buildspecs.jl")
include("getparameters.jl")

function explore(model)

    #get variable data
    speclist = getspeclist(model)
    speclistJSON = JSON.json(speclist)

    #start Electron app
    if !isdefined(:app)
        global app = Application()
    end

    #load main html file
    mainpath = joinpath(@__DIR__, "assets", "main.html")
    w = Window(app, URI('${mainpath}'))

    #refresh variable list
    result = run(app, refresh(speclistJSON))
    
end



