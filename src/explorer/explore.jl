## Mimi UI
using DataFrames
using JSON
using Blink

#function to get variable data
include("buildspecs.jl")
include("getparameters.jl")

function explore(model)
    #get variable data
    speclist = getspeclist(model)

    #start Blink window
    w = Blink.Window()

    #load main html file
    loadfile(w, joinpath(@__DIR__, "assets", "main.html"))
        
    #refresh variable list
    @js w refresh($speclist)
end



