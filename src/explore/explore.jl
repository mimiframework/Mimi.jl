## Mimi UI
using Mimi
using DataFrames
using JSON
using Blink

##TODO:  getparameters
##TODO:  link data with refresh properly
##TODO:  add conditional statements for different types of graphs

#run tutorial
include("one-region-model.jl")

function explore(model)
    #get variable data
    include("buildspecs.jl")
    data = JSON.json(getspeclist(my_model))

    #start Blink window
    w = Blink.Window()

    #load main html file
    # joinpath(@__DIR__, "main.html")
    loadfile(w, abspath("main.html"))

    #refresh variable list
    @js w refresh()
end
