## Mimi UI
using CSVFiles
using DataFrames

function get_sim_results(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol; model_index::Int = 1, scen_name::Union{Nothing, String} = nothing)
    
    key = (comp_name, datum_name)
    df = (sim_inst.results[model_index])[key]
    if scen_name !== nothing
        if in(:scen, names(df)) 
            error("The results for this simulation contain a scenario dimension, you must specify the scen_name keyword argument, which is currently set to $(scen_name)")
        end
        filter!(row -> row.scen_name === scen_name, df)
    end
    return df
end

function get_sim_results(sim_inst::SimulationInstance, comp_name::Symbol, datum_name::Symbol, results_output_dir::String; model_index::Int = 1, scen_name::Union{Nothing, String} = nothing)
    
    # scenario sub-folder
    scen_name !== nothing ? scen_dir = joinpath(results_output_dir,scen_name) : scen_dir = results_output_dir

    # model sub-foder
    if (length(sim_inst.results) > 1)
        model_dir = joinpath(scen_dir, "model_$(model_index)")
    else
        model_dir = scen_dir 
    end      

    # load results
    filepath = joinpath(model_dir, string(comp_name, "_", datum_name, ".csv"));
    if isfile(filepath)
        results = CSVFiles.load(filepath) |> DataFrame 
    else
        error("$filepath does not exist, check arguments which currently set comp_name to $(comp_name), datum_name to $(datum_name), results_output_dir to $outputdir, model_index to $(model_index), and scen_name to $(scen_name)")
    end

    return results
end
