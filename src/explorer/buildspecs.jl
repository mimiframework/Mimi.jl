## Mimi UI

function dataframe_or_scalar(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dimensions(m, comp_name, item_name)
    return length(dims) > 0 ? getdataframe(m, comp_name, item_name) : m[comp_name, item_name]
end

# Generate the VegaLite spec for a variable or parameter
function _spec_for_item(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dimensions(m, comp_name, item_name)

    try
        # Control flow logic selects the correct plot type based on dimensions
        # and dataframe fields
        if length(dims) == 0
            value = m[comp_name, item_name]
            name = "$comp_name : $item_name = $value"
            spec = createspec_singlevalue(name)
        else
            name = "$comp_name : $item_name"          # the name is needed for the list label
            df = getdataframe(m, comp_name, item_name)

            dffields = map(string, names(df))         # convert to string once before creating specs

            if dffields[1] == "time" # a 'time' field necessitates a line plot
                if length(dffields) > 2
                    spec = createspec_multilineplot(name, df, dffields)
                else
                    spec = createspec_lineplot(name, df, dffields)
                end
            else
                spec = createspec_barplot(name, df, dffields)
            end
        end

        return spec
        
    catch err
        println("could not convert $comp_name.$item_name to DataFrame for explorer")
        rethrow(err)
    end
end

# Create VegaLite specs for each variable and parameter in the model
function spec_list(model::Model)
    allspecs = []

    for comp_name in map(name, compdefs(model)) 
        items = vcat(variable_names(model, comp_name), parameter_names(model, comp_name))

        for item_name in items
            try
                spec = _spec_for_item(model, comp_name, item_name)
                push!(allspecs, spec) 
            catch
            end
        end
    end

    # Return sorted list so that the UI list of items will be in alphabetical order 
    return sort(allspecs, by = x -> lowercase(x["name"]))
end

# So we can control these in one place...
global const _plot_width  = 450
global const _plot_height = 450

function createspec_lineplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :line) # returns a list of dictionaries    
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "line",
            "encoding" => Dict(
                "x" => Dict("field" => dffields[1], "type" => "temporal", "timeUnit" => "year"),                
                "y" => Dict("field" => dffields[2], "type" => "quantitative" )
            ),
            "width"  => _plot_width,
            "height" => _plot_height 
        ),
    )
    return spec
end

function createspec_barplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :bar) # returns a list of dictionaries    
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
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
        ),
    )
    return spec
end

function createspec_multilineplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :multiline) # return JSONtext type 
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"  => Dict("values" => datapart),
            "mark"  => "line",
            "encoding" => Dict(
                "x"     => Dict("field" => dffields[1], "type" => "temporal", "timeUnit" => "year"),                
                "y"     => Dict("field" => dffields[3], "type" => "quantitative" ),
                "color" => Dict("field" => dffields[2], "type" => "nominal", 
                "scale" => Dict("scheme" => "category20"))
            ),
            "width"  => _plot_width,
            "height" => _plot_height
        ),
    )
    return spec
end

function createspec_singlevalue(name)

    datapart = [];
    spec = Dict(
        "name" => name, 
        "VLspec" => Dict()
    )
    return spec
end

function getdatapart(df, dffields, plottype::Symbol)

    sb = StringBuilder()
    append!(sb, "[");

    # loop over rows and create a dictionary for each row
    if plottype == :multiline
        cols = (df.columns[1], df.columns[2])
        datastring = getmultiline(cols, dffields)
    elseif plottype == :line
        cols = (df.columns[1], df.columns[2], df.columns[3])
        datastring = getline(cols, dffields)
    else
        cols = (df.columns[1], df.columns[2])
        datastring = getbar(cols, dffields)
    end

    append!(sb, datastring);
    append!(sb, "]")

    datapart = String(sb)

    return JSONText(datapart)
end

function getmultiline(cols, dffields)
    datasb = StringBuilder()
    numrows = length(cols[1])
    for i = 1:numrows
        append!(datasb, "{") #start of dictionary

        append!(datasb, "\"") #start of date field
        append!(datasb, dffields[1]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][1]))
        append!(datasb, "\"")     
        
        append!(datasb, "\"") #start of value field
        append!(datasb, dffields[2]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][2]))
        append!(datasb, "\"")  

        append!(datasb, "\"") #start of categorical field
        append!(datasb, dffields[3]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][3]))
        append!(datasb, "\"")    
    end
    return String(datasb)
end

function getline(cols, dffields)
    datasb = StringBuilder()
    numrows = length(cols[1])
    for i = 1:numrows
        append!(datasb, "{") #start of dictionary

        append!(datasb, "\"") #start of date field
        append!(datasb, dffields[1]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][1]))
        append!(datasb, "\"")     
        
        append!(datasb, "\"") #start of value field
        append!(datasb, dffields[2]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][2]))
        append!(datasb, "\"")  
   
    end
    return String(datasb)
end

function getbar(cols, dffields)
    datasb = StringBuilder()
    numrows = length(cols[1])
    for i = 1:numrows
        append!(datasb, "{") #start of dictionary

        append!(datasb, "\"") #start of first field
        append!(datasb, dffields[1]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][1]))
        append!(datasb, "\"")     
        
        append!(datasb, "\"") #start of value field
        append!(datasb, dffields[2]) 
        append!(datasb, "\"")        
        append!(datasb, ":")
        append!(datasb, "\"")   
        append!(datasb, string(cols[i][2]))
        append!(datasb, "\"")  
  
    end
    return String(datasb)
end

#=     if plottype == :multiline || plottype == :line
        for row in eachrow(df)
            rowdata = Dict(dffields[1] => Date(row[1]), 
                           dffields[2] => row[2])

            if plottype == :multiline
                rowdata[dffields[3]] = row[3] 
            end
            push!(datapart, rowdata)
        end 
    else
        for row in eachrow(df)
            rowdata = Dict(dffields[1] => row[1], 
                           dffields[2] => row[2])
            push!(datapart, rowdata)
        end  
    end =#
