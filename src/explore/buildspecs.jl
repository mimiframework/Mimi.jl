## Mimi UI
using Mimi
using DataFrames

function getspeclist(model)

    #initialize the variable list
    speclist = []

    #get all components of model
    comps = components(model)
    for c in comps

        #get all variables of component
        vars = variables(model, c)
        for v in vars

            ####################################################################
            ##  Build up the spec for this component/variable pair
            ####################################################################

            #pull information 
            name = string(c,":",v) #returns the name of the pair as "component:variable"
            df = getdataframe(model, c, v) #returns the  corresponding dataframe
            datapart = getdatapart(df) #returns a list of dictionaries

           #create spec
            spec = Dict(
                "name"  => name,
                "VLspec" => Dict(
                    "schema" => "https://vega.github.io/schema/vega-lite/v2.0.json",
                    "description" => "graph for a specific component variable pair",
                    "title" => name,
                    "data"=> Dict("values" => datapart),

                ),
                "mark" => "line",
                "encoding" => Dict(
                    "x" => Dict("field" => string(names(df)[1]), "type" => "temporal", "Axis" => Dict("format" => "%Y}}" )),
                    "y" => Dict("field" => string(names(df)[2]), "type" => "quantitative" )
            ),
                "width" => 400,
                "height" => 400 
            )

            ####################################################################
            ##  Add the spec to the growing variable list 
            ####################################################################
    
            push!(speclist, spec) 

        end
    end
    return speclist
end

function getdatapart(df)

    #initialize a list for the datapart
    datapart = [];

    #loop over rows and create a dictionary for each row
    for row in eachrow(df)
        rowdata = Dict(string(names(df)[1])=> row[1], string(names(df)[2]) => row[2])
        push!(datapart, rowdata)
    end
    return datapart
end