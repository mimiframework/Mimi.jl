## Mimi UI
using VegaLite
using FilePaths
import FileIO:save
export save

global app = nothing

function close_explore_app()
    if !isnothing(app)
        close(app)
        global app = nothing
    end
end

#include functions and modules
include("getdataparts.jl")
include("buildspecs.jl")
include("buildmenu.jl")
include("results.jl")

"""
    explore(m::Model)

Produce a UI to explore the parameters and variables of Model `m` in an independent window.
"""
function explore(m::Model)
    
    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end

    #start Electron app
    if app === nothing
        global app = Application()
    end

    #window options
    windowopts = Dict("width" => 1000, "height" => 1000)
    w = Window(app, joinpath(@__PATH__, p"mimiexplorer-app/build/index.html"), options = windowopts)
 
    #set async block to process messages
    @async for msg in msgchannel(w)
        if (msg["cmd"] == "display_spec")
            spec = _spec_for_item(m, Symbol(msg["comp_name"]), Symbol(msg["item_name"]))
            specJSON = JSON.json(spec)
            run(w, "display($specJSON)")
        end
        if (msg["cmd"] == "update_data")
            comp_name = msg["comp_name"];
            paths = _get_all_paths(m)
            comp_path = paths[Symbol(comp_name)];
            comp_def = find_comp(m, comp_path);
            menulist = menu_item_list(m, Symbol(comp_name), comp_def)
            menulistJSON = JSON.json(menulist);
            result = run(w, "setData($menulistJSON)");
        end
    end

    # Electron.toggle_devtools(w)

    #refresh tree view
    subcomplist = tree_view_values(m)
    subcomplistJSON = JSON.json(subcomplist)

    result = run(w, "setTreeChildren($subcomplistJSON)")

    #refresh data view
    datalist = menu_item_list(m)
    datalistJSON = JSON.json(datalist)
    result = run(w, "setData($datalistJSON)")

    return w

end

"""
    explore(mi::ModelInstance)

Produce a UI to explore the parameters and variables of `ModelInstance` `mi` in an independent window.
"""
function explore(mi::ModelInstance)
    m = Model(mi)
    m.md.dirty = false # we need this to get explorer working, but it's a hack and should be temporary!
    explore(m)
end

"""
    explore(sim_inst::SimulationInstance; title="Electron", model_index::Int = 1, scen_name::Union{Nothing, String} = nothing, results_output_dir::Union{Nothing, String} = nothing)

Produce a UI to explore the output distributions of the saved variables in `SimulationInstance`
`sim` for results of model `model_index` and scenario with the name `scen_name` in
a Window with title `title`. The optional arguments default to a `model_index` of `1`, a `scen_name` of `nothing` 
assuming there is no secenario dimension, and a window with title `Electron`.  
The `results_output_dir` keyword argument refers to the main output directory as provided to `run`, 
where all subdirectories are held. If provided, results are assumed to be stored there, otherwise it is 
assumed that results are held in results.sim and not 
in an output folder.

"""
function explore(sim_inst::SimulationInstance; title="Electron", model_index::Int = 1, scen_name::Union{Nothing, String} = nothing, results_output_dir::Union{Nothing, String} = nothing)

    # quick check 
    if results_output_dir === nothing && isempty(sim_inst.results[model_index]) 
        error("Simulation instance results dictionaries are empty, if results were only saved to disk use the `results_output_dir` keyword argument.")
    end

    #start Electron app
    if app === nothing
        global app = Application()
    end

    #load main html file
    mainpath = replace(joinpath(@__DIR__, "assets", "main.html"), "\\" => "/")

    #window options
    windowopts = Dict("title" => title, "width" => 1100, "height" => 700)
    w = Window(app, URI(joinpath(@__PATH__, "assets", "main.html")), options = windowopts)

     #set async block to process messages
     @async for msg in msgchannel(w)
        comp_name = Symbol(msg["comp_name"]);
        item_name = Symbol(msg["item_name"]);

        if results_output_dir === nothing
            results = Mimi.get_sim_results(sim_inst, comp_name, item_name; model_index = model_index, scen_name = scen_name)
        else
            results = Mimi.get_sim_results(sim_inst, comp_name, item_name, results_output_dir; model_index = model_index, scen_name = scen_name)
        end

        spec = Mimi._spec_for_sim_item(sim_inst, comp_name, item_name, results; model_index = model_index)
        specJSON = JSON.json(spec)

        run(w, "display($specJSON)") 

    end

     #refresh variable list
     menulist = menu_item_list(sim_inst)
     menulistJSON = JSON.json(menulist)
 
     result = run(w, "refresh($menulistJSON)")
     
     return w
 
end

# Helper function returns true if VegaLite is verison 3 or above, and false otherwise
function _is_VegaLite_v3()
    return isdefined(VegaLite, :vlplot) ? true : false
end

"""
    plot(m::Model, comp_name::Symbol, datum_name::Symbol; interactive::Bool = false)

Plot a specific `datum_name` (a `variable` or `parameter`) of Model `m`. If the 
Bool `interactive` option is set to `true`, the plot will be interactive which will 
limit saving options.
"""
function plot(m::Model, comp_name::Symbol, datum_name::Symbol; interactive::Bool = false)

    if m.mi === nothing
        error("A model must be run before it can be plotted")
    end
    
    spec = Mimi._spec_for_item(m, comp_name, datum_name, interactive=interactive)
    spec === nothing ? error("Spec cannot be built.") : VLspec = spec["VLspec"]

    return _is_VegaLite_v3() ? VegaLite.VLSpec(VLspec) : VegaLite.VLSpec{:plot}(VLspec)
end
"""
    plot(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; interactive::Bool = false, model_index::Int = 1, scen_name::Union{Nothing, String} = nothing, results_output_dir::Union{Nothing, String} = nothing)

Plot a specific `datum_name` that was one of the saved variables of `SimulationInstance` `sim_inst`
for results of model `model_index`, which defaults to 1, in scenario `scen_name`, which
defaults to `nothing` implying there is no scenario dimension. The `results_output_dir` keyword argument refers
to the main output directory as provided to `run`, where all subdirectories are held. If provided, results are 
assumed to be stored there, otherwise it is assumed that results are held in results.sim and not 
in an output folder.
"""
function plot(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; interactive::Bool = false, model_index::Int = 1, scen_name::Union{Nothing, String} = nothing, results_output_dir::Union{Nothing, String} = nothing)
    
    # quick check 
    if results_output_dir === nothing && isempty(sim_inst.results[model_index]) 
        error("Simulation instance results dictionaries are empty, if results were only saved to disk use the `results_output_dir` keyword argument.")
    end
        
    if results_output_dir === nothing
        results = Mimi.get_sim_results(sim_inst, comp_name, datum_name; model_index = model_index, scen_name = scen_name)
    else
        results = Mimi.get_sim_results(sim_inst, comp_name, datum_name, results_output_dir; model_index = model_index, scen_name = scen_name)
    end

    spec = Mimi._spec_for_sim_item(sim_inst, comp_name, datum_name, results; interactive = interactive, model_index = model_index)
    spec === nothing ? error("Spec cannot be built.") : VLspec = spec["VLspec"]

    return _is_VegaLite_v3() ? VegaLite.VLSpec(VLspec) : VegaLite.VLSpec{:plot}(VLspec)

end
