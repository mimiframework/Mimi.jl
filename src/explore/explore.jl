## Mimi UI
using Mimi
using DataFrames
using JSON
using Blink

#run tutorial (included for ease of developement since tutorials need to be 
#updated)

include("one-region-model.jl")

##TODO:  add parameters function to mimi_core.jl
##TODO:  link data with refresh properly
##TODO:  add conditional statements for different types of graphs

function explore(model)
    #get variable data
    include("buildspecs.jl")
    data = getspeclist(my_model)

    #start Blink window
    w = Blink.Window()

    #load main html file
    # joinpath(@__DIR__, "main.html")
    loadfile(w, abspath("main.html"))

    #refresh variable list
    @js w refresh()
end
