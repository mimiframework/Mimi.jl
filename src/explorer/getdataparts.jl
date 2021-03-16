using Dates

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
    elseif plottype == :multihistogram || plottype == :multibar || plottype == :multiscatter #3D with 2 indices, none of which is time
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
