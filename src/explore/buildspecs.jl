## Mimi UI
using Mimi
using DataFrames

function getspeclist(model::Mimi.Model)

    #initialize the speclist
    allspecs = []

    #get all components of model
    comps = Mimi.components(model)
    for c in comps

        #get all variables of component
        vars = variables(model, c)
        for v in vars

            #pull information 
            name = string("$c : $v") #returns the name of the pair as "component:variable"

            if c == :climateco2cycle && v == :cbox
                println("this is the FUND error variable, SKIPPING ...")
                continue
            end 

            df = getdataframe(model, c, v) #returns the  corresponding dataframe

            #choose type of plot
            #single value
            if length(df[1]) == 1
                value = df[1][1]
                name = string("$c : $v = $value")
                spec = createspec_singlevalue(name)
            else
                dffields = names(df)
                #line
                if dffields[1] == :time
                    #multiline
                    if length(dffields) > 2
                        spec = createspec_multilineplot(name, df, dffields)
                    #single line
                    else
                        spec = createspec_lineplot(name, df, dffields)
                    end
                #bar 
                else
                    spec = createspec_barplot(name, df, dffields)
                end
            end

            #add to spec list
            push!(allspecs, spec) 
        end

        #= #get all parameters of component
        params = parameters(model, c)
        for p in params

            #pull information 
            name = string("$c : $p") #returns the name of the pair as "component:parameter"
            df = getdataframe_for_parameter(model, c, p) #returns the  corresponding dataframe
            
            #there are no parameters in this component
            if typeof(df) == Float64
                continue
            end

            dffields = names(df)

            #choose type of plot
            if dffields[1] == :time
                if length(dffields) > 2
                    spec = createspec_multilineplot(name, df, dffields)
                else
                    spec = createspec_lineplot(name, df, dffields)
                end
            else
                spec = createspec_barplot(name, df, dffields)
            end

            #add to spec list
            push!(allspecs, spec) 
        end =#
    end
    return allspecs
end

function createspec_lineplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :line) #returns a list of dictionaries    
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "line",
            "encoding" => Dict(
                "x" => Dict("field" => string(dffields[1]), "type" => "temporal", "timeUnit" => "year"),                
                "y" => Dict("field" => string(dffields[2]), "type" => "quantitative" )
            ),
            "width" => 400,
            "height" => 400 
        ),
    )
    return spec
end

function createspec_barplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :bar) #returns a list of dictionaries    
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "line",
            "encoding" => Dict(
                "x" => Dict("field" => string(dffields[1]), "type" => "ordinal"),
                "y" => Dict("field" => string(dffields[2]), "type" => "quantitative" )
            ),
            "width" => 400,
            "height" => 400 
        ),
    )
    return spec
end

function createspec_multilineplot(name, df, dffields)
    datapart = getdatapart(df, dffields, :multiline) #returns a list of dictionaries    
    spec = Dict(
        "name"  => name,
        "VLspec" => Dict(
            "\$schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description" => "plot for a specific component variable pair",
            "title" => name,
            "data"=> Dict("values" => datapart),
            "mark" => "line",
            "encoding" => Dict(
                "x" => Dict("field" => string(dffields[1]), "type" => "temporal", "timeUnit" => "year"),                
                "y" => Dict("field" => string(dffields[3]), "type" => "quantitative" ),
                "color" => Dict("field" => string(dffields[2]), "type" => "nominal")
            ),
            "width" => 400,
            "height" => 400 
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

function getdatapart(df, dffields, plottype::Symbol = :line)
    datapart = [];

    #loop over rows and create a dictionary for each row
    if plottype == :multiline
        for row in eachrow(df)
            rowdata = Dict(string(dffields[1]) => Date(row[1]), string(dffields[3]) => row[3], 
                string(dffields[2]) => row[2])
            push!(datapart, rowdata)
        end 
    elseif plottype == :line
        for row in eachrow(df)
            rowdata = Dict(string(dffields[1])=> Date(row[1]), string(dffields[2]) => row[2])
            push!(datapart, rowdata)
        end 
    else
        for row in eachrow(df)
            rowdata = Dict(string(dffields[1])=> row[1], string(dffields[2]) => row[2])
            push!(datapart, rowdata)
        end 
    end
    return datapart
end