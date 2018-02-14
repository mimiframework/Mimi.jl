## Mimi UI
#using Mimi
using DataFrames
using JSON
using Blink

##TODO (version 0.1) add parameters to buildspecs.jl
##TODO (version 0.2) hierarchical list

#function to get variable data
include("buildspecs.jl")
include("getparameters.jl")

function explore(model)
    #get variable data
    speclist = getspeclist(model)

    #start Blink window
    w = Blink.Window()

    #load main html file
    loadfile(w, joinpath(@__DIR__, "main.html"))
        
    #refresh variable list
    @js w refresh($speclist)
end



