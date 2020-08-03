## Mimi UI
using Dates
using CSVFiles

function dataframe_or_scalar(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dim_names(m, comp_name, item_name)
    return length(dims) > 0 ? getdataframe(m, comp_name, item_name) : m[comp_name, item_name]
end

##
## 1. Generate the VegaLite spec for a variable or parameter
##

# Get spec
function _spec_for_item(m::Model, comp_name::Symbol, item_name::Symbol; interactive::Bool=true)
    if item_name == :_subcomponent
        return createspec_subcomponent(m, comp_name)
    end
    dims = dim_names(m, comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end

    # Control flow logic selects the correct plot type based on dimensions
    # and dataframe fields
    if length(dims) == 0
        value = m[comp_name, item_name]
        name = "$comp_name : $item_name = $value"
        spec = createspec_singlevalue(name)
    elseif length(dims) > 2
        @warn("$comp_name.$item_name has > 2 indexed dimensions, not yet implemented in explorer")
        return nothing
    else
        name = "$comp_name : $item_name"          
        df = getdataframe(m, comp_name, item_name)
        dffields = map(string, names(df))         # convert to string once before creating specs

        # a 'time' field necessitates a line plot
        if "time" in dffields

            # need to reorder the df to have 'time' as the first dimension
            ti = findfirst(isequal("time"), dffields)
            if ti != 1    
                fields1, fields2 = dffields[1:ti-1], dffields[ti+1:end]
                dffields = ["time", fields1..., fields2...]
                df = df[:, [Symbol(name) for name in dffields]]
            end

            if length(dffields) > 2
                spec = createspec_multilineplot(name, df, dffields, dims, interactive=interactive)
            else
                spec = createspec_lineplot(name, df, dffields, interactive=interactive)
            end
        
        #otherwise we are dealing with a barplot
        else
            spec = createspec_barplot(name, df, dffields)
        end
    end

    return spec
        
end

function _spec_for_sim_item(sim_inst::SimulationInstance, comp_name::Symbol, item_name::Symbol, results::DataFrame; model_index::Int = 1, interactive::Bool=true)

    # Control flow logic selects the correct plot type based on dimensions
    # and dataframe fields
    m = sim_inst.models[model_index]
    dims = dim_names(m, comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end
                    
    dffields = map(string, names(results))         # convert to string once before creating specs

    name = "$comp_name : $item_name"          

    if length(dims) == 0 # histogram
        spec = createspec_histogram(name, results, dffields; interactive = interactive)
    elseif length(dims) > 2
        @warn("$name has > 2 indexed dimensions, not yet implemented in explorer")
        return nothing
    else

        # check if there are too many dimensions to map and if so, error
        if length(dffields) > 4
            error()
                
        # a 'time' field necessitates a trumpet plot
        elseif dffields[1] == "time"
            if length(dffields) > 3
                spec =createspec_multitrumpet(name, results, dffields; interactive = interactive)
            else
                spec = createspec_trumpet(name, results, dffields; interactive = interactive)
            end
        #otherwise we are dealing with layered histograms
        else
            spec = createspec_multihistogram(name,results, dffields; interactive = interactive)
        end
    end
    
    return spec
        
end

# Create the list of variables and parameters
function menu_item_list(model::Model)
    all_menuitems = []

    for comp_name in map(nameof, compdefs(model)) 
        push!(all_menuitems, _menu_item(model, comp_name))
        items = vcat(variable_names(model, comp_name), parameter_names(model, comp_name))

        for item_name in items
            println(item_name)
            menu_item = _menu_item(model, comp_name, item_name)
            if menu_item !== nothing
                push!(all_menuitems, menu_item) 
            end
        end
    end

    # Return sorted list so that the UI list of items will be in alphabetical order 
    return sort(all_menuitems, by = x -> lowercase(x["name"]))
end

function menu_item_list(sim_inst::SimulationInstance)
    all_menuitems = []
    for datum_key in sim_inst.sim_def.savelist

        menu_item = _menu_item(sim_inst, datum_key)
        if menu_item !== nothing
            push!(all_menuitems, menu_item) 
        end
    end

    # Return sorted list so that the UI list of items will be in alphabetical order 
    return sort(all_menuitems, by = x -> lowercase(x["name"]))
end

function _menu_item(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dim_names(m, comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end

    if length(dims) == 0
        value = m[comp_name, item_name]
        name = "$comp_name : $item_name = $value"
    elseif length(dims) > 2
        @warn("$comp_name.$item_name has > 2 indexed dimensions, not yet implemented in explorer")
        return nothing
    else
        name = "$comp_name : $item_name"          # the name is needed for the list label
    end

    menu_item = Dict("name" => name, "comp_name" => comp_name, "item_name" => item_name)
    return menu_item
end

function _menu_item(m::Model, comp_name::Symbol)
    return Dict("name" => "$comp_name", "comp_name" => "$comp_name", "item_name" => "_subcomponent")
end

function _menu_item(sim_inst::SimulationInstance, datum_key::Tuple{Symbol, Symbol})
    (comp_name, item_name) = datum_key
    dims = dim_names(sim_inst.models[1], comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end

    if length(dims) > 2
        @warn("$comp_name.$item_name has >2 graphing dims, not yet implemented in explorer")
        return nothing
    else
        name = "$comp_name : $item_name"          # the name is needed for the list label
    end

    menu_item = Dict("name" => "$item_name", "comp_name" => comp_name, "item_name" => item_name)
    return menu_item
end

##
## 2. Create individual specs 
##

# Specs for explore(m::Model)
function createspec_lineplot(name, df, dffields; interactive::Bool=true)
    interactive ? createspec_lineplot_interactive(name, df, dffields) : createspec_lineplot_static(name, df, dffields)
end
 
function createspec_lineplot_interactive(name, df, dffields)
    datapart = getdatapart(df, dffields, :line) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "type" => "line",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => "$name (use bottom plot for interactive selection)",
            "data"=> Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    # "transform" => [Dict("filter" => Dict("selection" => "brush"))],
                    "width" => _plot_width,
                    "height" => _plot_height,
                    "mark" => Dict("type" => "line", "point" => true),
                    "encoding" => Dict(
                        "x" => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear", 
                            "axis" => Dict("title"=> ""),
                            "scale" => Dict("domain" => Dict("selection" => "brush"))
                        ),             
                        "y" => Dict(
                            "field" => dffields[2], 
                            "type" => "quantitative"
                        )
                    )
                ), Dict(
                    "width" => _plot_width,
                    "height" => _slider_height,
                    "mark" => Dict("type" => "line", "point" => true),
                    "selection" => Dict("brush" => Dict("type" => "interval", "encodings" => ["x"])),
                    "encoding" => Dict(
                        "x" => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear"
                        ),
                        "y" => Dict(
                            "field" => dffields[2], 
                            "type" => "quantitative",
                            "axis" => Dict("tickCount" => 3, "grid" => false
                            )
                        )
                    )
                )
            ]
        )
    )
    return spec
end

function createspec_lineplot_static(name, df, dffields)
    datapart = getdatapart(df, dffields, :line) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "type" => "line",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => Dict("type" => "line"),
            "encoding" => Dict(
                "x" => Dict(
                    "field" => dffields[1], 
                    "type" => "temporal", 
                    "timeUnit" => "utcyear"
                ),             
                "y" => Dict(
                    "field" => dffields[2], 
                    "type" => "quantitative"
                )
            ),
            "width" => _plot_width,
            "height" => _plot_height
        )
    )
    return spec
end

function createspec_multilineplot(name, df, dffields, multidims; interactive::Bool=true)
    strmultidims = [String(dim) for dim in multidims]
    interactive ? createspec_multilineplot_interactive(name, df, dffields, strmultidims) : createspec_multilineplot_static(name, df, dffields, strmultidims)
end

function createspec_multilineplot_interactive(name, df, dffields, strmultidims)
    datapart = getdatapart(df, dffields, :multiline) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => "$name (use bottom plot for interactive selection)",
            "data"  => Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    # "transform" => [Dict("filter" => Dict("selection" => "brush"))],
                    "mark" => Dict("type" => "line", "point" => true),
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear", 
                            "axis" => Dict("title"=> ""),
                            "scale" => Dict("domain" => Dict("selection" => "brush"))
                            ),                
                        "y"     => Dict(
                            "field" => dffields[3], 
                            "type" => "quantitative"
                            ),
                        "color" => Dict("field" => strmultidims[findfirst(strmultidims .!= "time")],
                                        "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20"))
                    ),
                    "width"  => _plot_width,
                    "height" => _plot_height
                ), Dict(
                    "width" => _plot_width,
                    "height" => _slider_height,
                    "mark" => Dict("type" => "line", "point" => true),
                    "selection" => Dict("brush" => Dict("type" => "interval", "encodings" => ["x"])),
                    "encoding" => Dict(
                        "x" => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear"
                        ),
                        "y" => Dict(
                            "field" => dffields[3], 
                            "type" => "quantitative",
                            "axis" => Dict("tickCount" => 3, "grid" => false)
                        ),
                        "color" => Dict("field" => strmultidims[findfirst(strmultidims .!= "time")],
                                        "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20")
                        )
                    )
                )
            ]
        ),
    )
    return spec
end

function createspec_multilineplot_static(name, df, dffields, strmultidims)
    datapart = getdatapart(df, dffields, :multiline) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"  => Dict("values" => datapart),
    
            "mark" => Dict("type" => "line"),
            "encoding" => Dict(
                "x"     => Dict(
                    "field" => dffields[1], 
                    "type" => "temporal", 
                    "timeUnit" => "utcyear"
                    ),                
                "y"     => Dict(
                    "field" => dffields[3], 
                    "type" => "quantitative"
                    ),
                "color" => Dict("field" => strmultidims[findfirst(strmultidims .!= "time")], "type" => "nominal", 
                    "scale" => Dict("scheme" => "category20"))
            ),
            "width"  => _plot_width,
            "height" => _plot_height
        ),
    )
    return spec
end

function createspec_barplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :bar) #returns JSONtext type     
    spec = Dict(
        "name"  => name,
        "type" => "bar",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "bar",
            "encoding" => Dict(
                "x" => Dict("field" => dffields[1], "type" => "ordinal"),
                "y" => Dict("field" => dffields[2], "type" => "quantitative" )
                ),
            "width"  => _plot_width,
            "height" => _plot_height 
        )
    )
    return spec
end

function createspec_singlevalue(name)

    datapart = [];
    spec = Dict(
        "name" => name, 
        "type" => "singlevalue",
        "VLspec" => Dict()
    )
    return spec
end

# Specs for explore(sim_inst::SimulationInstance)

function createspec_trumpet(name, df, dffields; interactive::Bool=true)
    df_reduced = trumpet_df_reduce(df, :trumpet) #reduce the dataframe down to only the data needed for max, min, and mean lines
    interactive ? createspec_trumpet_interactive(name, df_reduced, dffields) : createspec_trumpet_static(name, df_reduced, dffields)
end

# https://vega.github.io/vega-lite/examples/layer_line_errorband_ci.html
function createspec_trumpet_static(name, df, dffields)

    datapart = getdatapart(df, dffields, :trumpet) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "encoding" => Dict(
                "x"     => Dict(
                    "field" => dffields[1], 
                    "type" => "temporal", 
                    "timeUnit" => "utcyear", 
                )
            ),
            "layer" => [
                Dict(
                    "mark" => "line",
                    "encoding" => Dict(
                        "y" => Dict(
                            "aggregate" => "mean", 
                            "field" => dffields[2],
                            "type" => "quantitative"
                        )
                    )
                ),
                Dict(
                    "mark" => "area",
                    "encoding" => Dict(
                        "y" => Dict(
                            "aggregate" => "max", 
                            "field" => dffields[2],
                            "type" => "quantitative",
                            "title" => "$(dffields[2])"
                        ),
                        "y2" => Dict(
                            "aggregate" => "min", 
                            "field" => dffields[2]
                        ),
                        "opacity" => Dict(
                            "value" => 0.5
                        )
                    )
                )

            ]
        ),
        "width"  => _plot_width,
        "height" => _plot_height
    )
    return spec
end

function createspec_trumpet_interactive(name, df, dffields)

    datapart = getdatapart(df, dffields, :trumpet) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => "$name (use bottom plot for interactive selection)",
            "data"=> Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    "width" => _plot_width,
                    "height" => _plot_height,
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear", 
                            "scale" => Dict("domain" => Dict("selection" => "brush"))
                        )
                    ),
                    "layer" => [
                        Dict(
                            "mark" => "line",
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "mean", 
                                    "field" => dffields[2],
                                    "type" => "quantitative"
                                )
                            )
                        ),
                        Dict(
                            "mark" => "area",
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "max", 
                                    "field" => dffields[2],
                                    "type" => "quantitative",
                                    "title" => "$(dffields[2])"
                                ),
                                "y2" => Dict(
                                    "aggregate" => "min", 
                                    "field" => dffields[2]
                                ),
                                "opacity" => Dict(
                                    "value" => 0.5
                                )
                            )
                        )
        
                    ]
                ),
                Dict(
                    "width" => _plot_width,
                    "height" => _slider_height,
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear"
                        )
                    ),

                    "layer" => [
                        Dict(
                            "mark" => "line",
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "mean", 
                                    "field" => dffields[2],
                                    "type" => "quantitative"
                                )
                            )
                        ),
                        Dict(
                            "mark" => "area",
                            "selection" => Dict("brush" => Dict("type" => "interval", "encodings" => ["x"])),
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "max", 
                                    "field" => dffields[2],
                                    "type" => "quantitative",
                                    "title" => "$(dffields[2])"
                                ),
                                "y2" => Dict(
                                    "aggregate" => "min", 
                                    "field" => dffields[2]
                                ),
                                "opacity" => Dict(
                                    "value" => 0.5
                                )
                            )
                        )
        
                    ]
                )
            ]
        )
    )
    return spec
end

function createspec_multitrumpet(name, df, dffields; interactive::Bool = true)
    df_reduced = trumpet_df_reduce(df, :multitrumpet) #reduce the dataframe down to only the data needed for max, min, and mean lines
    interactive ? createspec_multitrumpet_interactive(name, df, dffields) : createspec_multitrumpet_static(name, df, dffields)
end

function createspec_multitrumpet_interactive(name, df, dffields)
    datapart = getdatapart(df, dffields, :multitrumpet) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => "$name (use top plot for interactive selection)",
            "data"=> Dict("values" => datapart),
            "vconcat" => [
            
            # summary graphic of all mean lines
            Dict(
                "mark" => "line",
                "width"  => _plot_width,
                "height" => _slider_height,
                "selection" => Dict("brush" => Dict("type" => "interval", "encodings" => ["x"])),
                "encoding" => Dict(
                    "x" => Dict(
                        "field" => dffields[1], 
                        "type" => "temporal",
                        "timeUnit" => "utcyear"
                    ),
                    "y" => Dict(
                        "aggregate" => "mean",
                        "field" => dffields[3],
                        "type" => "quantitative",
                        "title" => "Mean $(dffields[3])"
                    ),
                    "color" => Dict("field" => dffields[2], "type" => "nominal", 
                    "scale" => Dict("scheme" => "category20"))
                )
            ),

            # faceted rows
            Dict(
                "facet" => Dict("row" => Dict("field" => dffields[2], "type" => "nominal")),
                "spec" => Dict(
                        Dict(
                            "width" => _plot_width,
                            "height" => _plot_height / 2,
                            "encoding" => Dict(
                                "x"     => Dict(
                                    "field" => dffields[1], 
                                    "type" => "temporal", 
                                    "timeUnit" => "utcyear", 
                                    "scale" => Dict("domain" => Dict("selection" => "brush"))
                                ),
                                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                                "scale" => Dict("scheme" => "category20"))
                            ),
                            "layer" => [
                                Dict(
                                    "mark" => "line",
                                    "encoding" => Dict(
                                        "y" => Dict(
                                            "aggregate" => "mean", 
                                            "field" => dffields[3],
                                            "type" => "quantitative"
                                        ),
                                        "color" => Dict("field" => dffields[2], "type" => "nominal", 
                                        "scale" => Dict("scheme" => "category20"))
                                    )
                                ),
                                Dict(
                                    "mark" => "area",
                                    "encoding" => Dict(
                                        "y" => Dict(
                                            "aggregate" => "max", 
                                            "field" => dffields[3],
                                            "type" => "quantitative",
                                            "title" => "Mean $(dffields[3]) with Max/Min"
                                        ),
                                        "y2" => Dict(
                                            "aggregate" => "min", 
                                            "field" => dffields[3]
                                        ),
                                        "opacity" => Dict(
                                            "value" => 0.5
                                        ),
                                        "color" => Dict("field" => dffields[2], "type" => "nominal", 
                                        "scale" => Dict("scheme" => "category20"))
                                    )
                                )   
                            ]
                        )
                )
            )
            ]  
        )
    )
    return spec
end

function createspec_multitrumpet_static(name, df, dffields)
    datapart = getdatapart(df, dffields, :multitrumpet) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data" => Dict("values" => datapart),
            "vconcat" => [

            # summary graphic of all mean lines
            Dict(
                "width"  => _plot_width,
                "height" => _slider_height,
                "mark" => "line",
                "encoding" => Dict(
                    "x" => Dict(
                        "field" => dffields[1], 
                        "type" => "temporal",
                        "timeUnit" => "utcyear"
                    ),
                    "y" => Dict(
                        "aggregate" => "mean",
                        "field" => dffields[3],
                        "type" => "quantitative",
                        "title" => "Mean $(dffields[3])"
                    ),
                    "color" => Dict("field" => dffields[2], "type" => "nominal", 
                    "scale" => Dict("scheme" => "category20"))
                )
            ),
            # faceted rows
            Dict(
                "facet" => Dict("row" => Dict("field" => dffields[2], "type" => "nominal")),
                "spec" => Dict(
                    "width"  => _plot_width,
                    "height" => _plot_height / 2,
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[1], 
                            "type" => "temporal", 
                            "timeUnit" => "utcyear" 
                        ),
                        "color" => Dict("field" => dffields[2], "type" => "nominal", 
                        "scale" => Dict("scheme" => "category20"))
                    ),
                    "layer" => [
                        Dict(
                            "mark" => "line",
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "mean", 
                                    "field" => dffields[3],
                                    "type" => "quantitative"
                                ),
                                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                                "scale" => Dict("scheme" => "category20"))
                            )
                        ),
                        Dict(
                            "mark" => "area",
                            "encoding" => Dict(
                                "y" => Dict(
                                    "aggregate" => "max", 
                                    "field" => dffields[3],
                                    "type" => "quantitative",
                                    "title" => "Mean $(dffields[3]) with Min/Max"
                                ),
                                "y2" => Dict(
                                    "aggregate" => "min", 
                                    "field" => dffields[3]
                                ),
                                "opacity" => Dict(
                                    "value" => 0.5
                                ),
                                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                                "scale" => Dict("scheme" => "category20"))
                            )
                        )
                    ]
                )
            )
            ]
        )
    )
    return spec
end

function createspec_histogram(name, df, dffields; interactive::Bool = true)
    interactive ? createspec_histogram_interactive(name, df, dffields) : createspec_histogram_static(name, df, dffields)
end

function createspec_histogram_static(name, df, dffields)
    datapart = getdatapart(df, dffields, :histogram) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "type" => "histogram",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => Dict("type" => "bar"),
            "encoding" => Dict(
                "x" => Dict(
                    "field" => dffields[1], 
                    "type" => "quantitative", 
                    "bin" => Dict("maxbins" => 15)
                ),             
                "y" => Dict(
                    "aggregate" => "count",
                    "type" => "quantitative",
                    "title" => "count"
                )
            ),
            "width" => _plot_width,
            "height" => _plot_height
        )
    )
    return spec
end

function createspec_histogram_interactive(name, df, dffields) # for now the same as static version
    createspec_histogram_static(name, df, dffields)    
end

function createspec_multihistogram(name, df, dffields; interactive::Bool = true)
    interactive ? createspec_multihistogram_interactive(name, df, dffields) : createspec_multihistogram_static(name, df, dffields)
end

function createspec_multihistogram_static(name, df, dffields)
    datapart = getdatapart(df, dffields, :multihistogram) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"  => Dict("values" => datapart),
            "vconcat" => [
                # layered histogram of all
                Dict(
                    "mark" => Dict("type" => "bar"),
                    "width"  => _plot_width,
                    "height" => _slider_height,
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[2], 
                            "type" => "quantitative", 
                            "bin" => Dict("maxbins" => 15)
                            ),                
                        "y"     => Dict(
                            "field" => dffields[3], 
                            "aggregate" => "count",
                            "type" => "quantitative",
                            "stack" => nothing
                            ),
                        "color" => Dict("field" => dffields[1], "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20")),
                        "opacity" => Dict("value" => 0.7)
                    )
                ),

                # faceted rows
                Dict(
                    "facet" => Dict("row" => Dict("field" => dffields[1], "type" => "nominal")),
                    "spec" => Dict(
                        Dict(
                            "mark" => Dict("type" => "bar"),
                            "width"  => _plot_width,
                            "height" => _plot_height / 2,
                            "encoding" => Dict(
                                "x"     => Dict(
                                    "field" => dffields[2], 
                                    "type" => "quantitative", 
                                    "bin" => Dict("maxbins" => 15)
                                    ),                
                                "y"     => Dict(
                                    "field" => dffields[3], 
                                    "aggregate" => "count",
                                    "type" => "quantitative",
                                    "stack" => true
                                    ),
                                "color" => Dict("field" => dffields[1], "type" => "nominal", 
                                "scale" => Dict("scheme" => "category20"))
                            )
                        )
                    )
                )
            ]
        )
    )
    return spec
end

function createspec_multihistogram_interactive(name, df, dffields)
    datapart = getdatapart(df, dffields, :multihistogram) #returns JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => "$name (use top plot for interactive selection)",
            "data"  => Dict("values" => datapart),
            "vconcat" => [

                # layered histogram of all
                Dict(
                    "mark" => Dict("type" => "bar"),
                    "width"  => _plot_width,
                    "height" => _slider_height,
                    "selection" => Dict("brush" => Dict("type" => "interval", "encodings" => ["x"])),
                    "encoding" => Dict(
                        "x"     => Dict(
                            "field" => dffields[2], 
                            "type" => "quantitative", 
                            "bin" => Dict("maxbins" => 15)
                        ),                
                        "y"     => Dict(
                            "field" => dffields[3], 
                            "aggregate" => "count",
                            "type" => "quantitative",
                            "stack" => nothing      
                        ), 
                        "color" => Dict("field" => dffields[1], "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20")),
                        "opacity" => Dict("value" => 0.7)
                    )
                ),

                # faceted rows
                Dict(
                    "facet" => Dict("row" => Dict("field" => dffields[1], "type" => "nominal")),
                    "spec" => Dict(
                        Dict(
                            "mark" => Dict("type" => "bar"),
                            "width"  => _plot_width,
                            "height" => _plot_height / 2,
                            "encoding" => Dict(
                                "x"     => Dict(
                                    "field" => dffields[2], 
                                    "type" => "quantitative", 
                                    "bin" => Dict("maxbins" => 15),
                                    "scale" => Dict("domain" => Dict("selection" => "brush"))
                                    ),                
                                "y"     => Dict(
                                    "field" => dffields[3], 
                                    "aggregate" => "count",
                                    "type" => "quantitative"
                                    ),
                                "color" => Dict("field" => dffields[1], "type" => "nominal", 
                                "scale" => Dict("scheme" => "category20"))
                            )
                        )
                    )
                )
            ]
        )
    )
    return spec
end

# Spec for subcomponents

function createspec_subcomponent(m::Model, comp_name::Symbol)
    datapart = [];
    comp_list = components(m, comp_name)
    spec = Dict(
        "name" => comp_name, 
        "type" => "_subcomponent",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "contents of  a specific subcomponent",
            "title" => "$comp_name",
            "data"  => Dict("values" => comp_list)
        )
    )
    println(spec)
    return spec
end

# Plot constants
global const _plot_width  = 450
global const _plot_height = 410
global const _slider_height = 90

##
## Helper functions
##

# Various functions to get the JSONtext of the data
function getdatapart(df, dffields, plottype::Symbol)

    # start the main string
    sb = StringBuilder()
    append!(sb, "[");

    # get the specific string for this type of data
    datasb = StringBuilder()
    numrows = length(df[!, 1]);

    # loop over rows and create a dictionary for each row
    if plottype == :multitrumpet #4D with 3 indices
        cols = (df[!, 1], df[!, 2], df[!, 3], df[!, 4])
        datastring = getdatapart_4d(cols, dffields, numrows, datasb)
    elseif plottype == :multiline || plottype == :trumpet #3D with 2 indices, one of which is time
        cols = (df[!, 1], df[!, 2], df[!, 3])
        datastring = getdatapart_3d_time(cols, dffields, numrows, datasb)
    elseif plottype == :multihistogram #3D with 2 indices, none of which is time
        cols = (df[!, 1], df[!, 2], df[!, 3])
        datastring = getdatapart_3d(cols, dffields, numrows, datasb)
    elseif plottype == :line  #2D with 1 index, one of which is time
        cols = (df[!, 1], df[!, 2])
        datastring = getdatapart_2d_time(cols, dffields, numrows, datasb)
    else # :bar and :histogram
        cols = (df[!, 1], df[!, 2])
        datastring = getdatapart_2d(cols, dffields, numrows, datasb)
    end

    append!(sb, datastring * "]");
    datapart = String(sb)

    return JSON.JSONText(datapart)
end

function getdatapart_4d(cols, dffields, numrows, datasb)
    for i = 1:numrows

        append!(datasb, "{
            \"" * dffields[1]  * "\":\"" * string(Date(cols[1][i])) * "\",
            \"" * dffields[2] * "\":\"" * string(cols[2][i]) * "\",
            \"" * dffields[3] * "\":\"" * string(cols[3][i]) * "\",
            \"" * dffields[4] * "\":\"" * string(cols[4][i]) * "\"}")
        
        if i != numrows
            append!(datasb, ",")
        end  
    end
    return String(datasb)
end

function getdatapart_3d_time(cols, dffields, numrows, datasb)
    for i = 1:numrows

        append!(datasb, "{\"" * dffields[1]  * "\":\"" * string(Date(cols[1][i]))
            * "\",\"" * dffields[2] * "\":\"" * string(cols[2][i]) * "\",\"" 
            * dffields[3] * "\":\"" * string(cols[3][i]) * "\"}")
        
        if i != numrows
            append!(datasb, ",")
        end  
    end
    return String(datasb)
end

function getdatapart_3d(cols, dffields, numrows, datasb)
    for i = 1:numrows

        append!(datasb, "{\"" * dffields[1]  * "\":\"" * string(cols[1][i])
            * "\",\"" * dffields[2] * "\":\"" * string(cols[2][i]) * "\",\"" 
            * dffields[3] * "\":\"" * string(cols[3][i]) * "\"}")
        
        if i != numrows
            append!(datasb, ",")
        end  
    end
    return String(datasb)
end

function getdatapart_2d_time(cols, dffields, numrows, datasb)
    for i = 1:numrows
        append!(datasb, "{\"" * dffields[1]  * "\":\"" * string(Date(cols[1][i])) 
            * "\",\"" * dffields[2] * "\":\"" * string(cols[2][i]) * "\"}") 

        if i != numrows
            append!(datasb, ",")
        end
    end
    
    return String(datasb)
end

function getdatapart_2d(cols, dffields, numrows, datasb)
    for i = 1:numrows

        append!(datasb, "{\"" * dffields[1] * "\":\"" * string(cols[1][i]) *
            "\",\"" * dffields[2] * "\":\"" * string(cols[2][i]) * "\"}") #end of dictionary

        if i != numrows
            append!(datasb, ",")
        end
    end
    return String(datasb)
end

function trumpet_df_reduce(df, plottype::Symbol)
    
    if plottype == :trumpet
        col_index = 2
    else
        col_index = 3
    end

    col = names(df)[col_index]
    groupby_keys = []
    for i = 1:length(names(df))
        i != col_index && push!(groupby_keys,  names(df)[i])
    end

    df_new = by(df, groupby_keys, value = col => minimum)
    append!(df_new, by(df, groupby_keys, value = col => maximum))
    append!(df_new, by(df, groupby_keys, value = col => mean))
    rename!(df_new, :value => col)

    if plottype == :trumpet
        reorder_cols = [groupby_keys[1], col, groupby_keys[2:end]...]
    else
        reorder_cols = [groupby_keys[1:2]..., col, groupby_keys[3:end]...]
    end

    return df_new[:, reorder_cols]
end
