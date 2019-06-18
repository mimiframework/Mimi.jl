## Mimi UI
using VegaLite
using FilePaths
import FileIO:save
export save

global app = nothing

#include functions and modules
include("buildspecs.jl")

"""
    explore(m::Model; title = "Electron")

Produce a UI to explore the parameters and variables of Model `m` in a Window with title `title`.
"""
function explore(m::Model; title = "Electron")
    
    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end

    #start Electron app
    if app === nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\" => "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1000, "height" => 700)
    w = Window(app, URI(joinpath(@__PATH__, "assets", "main.html")), options = windowopts)
    
    #set async block to process messages
    @async for msg in msgchannel(w)

        spec = _spec_for_item(m, Symbol(msg["comp_name"]), Symbol(msg["item_name"]))
        specJSON = JSON.json(spec)

        run(w, "display($specJSON)")
    end

    #refresh variable list
    menulist = menu_item_list(m)
    menulistJSON = JSON.json(menulist)

    result = run(w, "refresh($menulistJSON)")
    
    return w

end

"""
    explore(sim_inst::SimulationInstance; title="Electron", model_index = 1, scen_name::Union{Nothing, String} = nothing)

Produce a UI to explore the output distributions of the saved variables in `SimulationInstance`
`sim` for results of model `model_index` and scenario with the name `scen_name` in
a Window with title `title`. The optional arguments default to a `model_index` of `1`, a `scen_name` of `nothing` 
assuming there is no secenario dimension, and a window with title `Electron`. 

"""
function explore(sim_inst::SimulationInstance; title="Electron", model_index = 1, scen_name::Union{Nothing, String} = nothing)

    #start Electron app
    if app === nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\" => "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1000, "height" => 700)
    w = Window(app, URI(joinpath(@__PATH__, "assets", "main.html")), options = windowopts)

     #set async block to process messages
     @async for msg in msgchannel(w)

        spec = _spec_for_sim_item(sim_inst, Symbol(msg["comp_name"]), Symbol(msg["item_name"]), model_index = model_index, scen_name = scen_name)
        specJSON = JSON.json(spec)

        run(w, "display($specJSON)")

    end

     #refresh variable list
     menulist = menu_item_list(sim_inst)
     menulistJSON = JSON.json(menulist)
 
     result = run(w, "refresh($menulistJSON)")
     
     return w
 
end

"""
    plot(m::Model, comp_name::Symbol, datum_name::Symbol)

Plot a specific `datum_name` (a `variable` or `parameter`) of Model `m`.
"""
function plot(m::Model, comp_name::Symbol, datum_name::Symbol)

    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end
    
    spec = Mimi._spec_for_item(m, comp_name, datum_name, interactive=r)["VLspec"]
    if spec === nothing
        error("Spec cannot be built.")  
    end      

    return VegaLite.VLSpec{:plot}(spec)
end

"""
    plot(sim::SimulationInstance, comp_name::Symbol, datum_name::Symbol; output_dir::Union{Nothing, String} = nothing, model_index::Int = 1, scen_name::Union{Nothing, String} = nothing)

Plot a specific `datum_name` that was one of the saved variables of `SimulationInstance` `sim_inst`
for results of model `model_index`, which defaults to 1, in scenario `scen_name`, which
defaults to `nothing` implying there is no scenario dimension. If an `output_dir` is provided, 
results are stored there, otherwise it is assumed that results are held in results.sim and not 
in an output folder.
"""
function plot(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; model_index::Int = 1, scen_name::Union{Nothing, String} = nothing)
    
    spec = Mimi._spec_for_sim_item(sim_inst, comp_name, datum_name; interactive = false, model_index = model_index, scen_name = scen_name)["VLspec"]
    if spec === nothing 
        error("Spec cannot be built.")
    end

    return VegaLite.VLSpec{:plot}(spec)
end
