## Mimi UI
using Mimi
using DataFrames
using JSON
using Blink

##TODO (version 0.1) decide how to plot single value parameters or values
##TODO (version 0.2) add parameters function to mimi_core.jl

#run tutorial (included for ease of developement since tutorials need to be 
#updated)
include(joinpath(@__DIR__, "01-one-region-model/one-region-model.jl"))

#function to get variable data
include("buildspecs.jl")

function explore(model)
    #get variable data
    speclist = getspeclist(model)

    #start Blink window
    w = Blink.Window()

    #load main html file
    # joinpath(@__DIR__, "main.html")
    loadfile(w, abspath("main.html"))
        
    #refresh variable list
    @js w refresh($speclist)
end



