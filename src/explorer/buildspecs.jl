# Create individual specs 

# Plot constants
global const _plot_width  = 450
global const _plot_height = 410
global const _slider_height = 90

##
## Primary spec functions
##

function _spec_for_item(m::Model, comp_name::Symbol, item_name::Symbol; interactive::Bool=true)
    dims = dim_names(m, comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end
    
    # Control flow logic selects the correct plot type based on dimensions
    # and dataframe fields

    ##
    ## No Plot Clases
    ##

    # if there are no dimensions we show the values in the label in the menu
    if length(dims) == 0
        paths = _get_all_paths(m)
        comp_path = paths[comp_name];
        value = m[comp_path, item_name] === nothing ? m[comp_name, item_name] : m[comp_path, item_name]
        value_typeof = typeof(value)
        if value_typeof <: Symbol || value_typeof <: String || value_typeof <: Number || value_typeof <: Array
            name = "$comp_name : $item_name = $value"
        else
            @warn("$comp_name.$item_name has 0 indexed dimensions and type $(value_typeof), displaying this type directly in the menu is not yet implemented in explorer")
            name = "$comp_name : $item_name (value has type $(value_typeof), cannot display in menu)"
        end
        spec = Mimi.createspec_singlevalue(name)

    # we do not support over two indexed dimensions right now
    elseif length(dims) > 2
        @warn("$comp_name.$item_name has > 2 indexed dimensions, not yet implemented in explorer")
        name = "$comp_name : $item_name (value has > 2 indexed dims, cannot display a plot)"
        spec = createspec_singlevalue(name)
    
    ##
    ## Plot Cases
    ##

    else
        name = "$comp_name : $item_name"          
        df = getdataframe(m, comp_name, item_name)
        dffields = map(string, names(df))         # convert to string once before creating specs
        
        # Time is a Dimension - line plots
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

        # No Time Dimension and First Dim is a Number Type - scatter plots
        elseif eltype(df[!, 1]) <: Number 
            if length(dffields) > 2
                spec = createspec_multiscatterplot(name, df, dffields)
            else
                spec = createspec_scatterplot(name, df, dffields)
            end

        # No Time Dimension and First Dim is Not a Number Type - bar plots
        else
            if length(dffields) > 2
                spec = createspec_multibarplot(name, df, dffields)
            else
                spec = createspec_barplot(name, df, dffields) 
            end
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
        name = "$comp_name : $item_name (value has > 2 indexed dims, cannot display a plot)"
        spec = createspec_singlevalue(name)
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

##
## Methods for explore(m::model)
##

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
            "data"=> Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    "title" => "$name",
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
                    "title" => "INTERACTIVE PLOT",
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
            "data"  => Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    "title" => "$name",
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
                    "title" => "INTERACTIVE PLOT",
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

function createspec_multibarplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :multibar)
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
                "y" => Dict("field" => dffields[3], "type" => "quantitative" ),
                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20"))
                ),
            "width"  => _plot_width,
            "height" => _plot_height 
        )
    )
    return spec
end

function createspec_scatterplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :scatter) #returns JSONtext type     
    spec = Dict(
        "name"  => name,
        "type" => "point",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "point",
            "encoding" => Dict(
                "x" => Dict("field" => dffields[1], "type" => "quantitative"),
                "y" => Dict("field" => dffields[2], "type" => "quantitative" )
                ),
            "width"  => _plot_width,
            "height" => _plot_height 
        )
    )
    return spec
end

function createspec_multiscatterplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :multiscatter)
    spec = Dict(
        "name"  => name,
        "type" => "point",
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v3.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "point",
            "encoding" => Dict(
                "x" => Dict("field" => dffields[1], "type" => "quantitative"),
                "y" => Dict("field" => dffields[3], "type" => "quantitative" ),
                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                            "scale" => Dict("scheme" => "category20"))
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

##
## Methods for explore(sim_inst::SimulationInstance)
##

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
            "data"=> Dict("values" => datapart),
            "vconcat" => [
                Dict(
                    "title" => "$name",
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
                    "title" => "INTERACTIVE PLOT",
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

##
## Helpers
##

function dataframe_or_scalar(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dim_names(m, comp_name, item_name)
    return length(dims) > 0 ? getdataframe(m, comp_name, item_name) : m[comp_name, item_name]
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

    gd = DataFrames.groupby(df, groupby_keys)

    df_new = rename!(combine(gd, col => maximum), Symbol(col, :_maximum) => col)
    append!(df_new, rename!(combine(gd, col => minimum), Symbol(col, :_minimum) => col))
    append!(df_new, rename!(combine(gd, col => mean), Symbol(col, :_mean) => col))

    if plottype == :trumpet
        reorder_cols = [groupby_keys[1], col, groupby_keys[2:end]...]
    else
        reorder_cols = [groupby_keys[1:2]..., col, groupby_keys[3:end]...]
    end

    return df_new[:, reorder_cols]
end