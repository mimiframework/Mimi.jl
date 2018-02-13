using Mimi

"""
parameters(m::Model, componentname::Symbol)

List all the parameters of `componentname` in model `m`.
"""

function parameters(m::Model, componentname::Symbol)
    c = Mimi.getmetainfo(m, componentname)
    collect(keys(c.parameters))
end

#
# In this version of Mimi, getdataframe() is designed to work only on variables.
# The functions below provide parallel implementations for parameters. Obviously 
# this is not ideal, but while the core of Mimi is being reorganized, this is the
# simplest approach for getting something to work with the explorer tool.
#

"""
    getdataframe_for_parameter(m::Model, componentname::Symbol, name::Symbol)

Return the values for parameter `name` in `componentname` of model `m` as a DataFrame.
"""
function getdataframe_for_parameter(m::Model, componentname::Symbol, name::Symbol)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    end

    c = Mimi.getmetainfo(m, componentname)
    params = c.parameters
    if ! haskey(params, name)
        error("Cannot get dataframe; parameter $name not in component $componentname")
    else
        return getdataframe_for_parameter(m, get(m.mi), componentname, name)
    end
end

# analogue to getdiminfoforvar (hmm. could use some underscores here!)
function getdiminfoforpar(s, name)
    meta = Mimi.metainfo.getallcomps()
    meta[s].parameters[name].dimensions
end


function getdataframe_for_parameter(m::Model, mi::Mimi.ModelInstance, componentname::Symbol, name::Symbol)
    comp_type = typeof(mi.components[componentname])

    meta_module_name = Symbol(supertype(comp_type).name.module)
    meta_component_name = Symbol(supertype(comp_type).name.name)

    pardiminfo = getdiminfoforpar((meta_module_name,meta_component_name), name)

    if length(pardiminfo)==0
        return mi[componentname, name]
    end

    df = DataFrame()

    values = ((isempty(m.time_labels) || pardiminfo[1]!=:time) ? m.indices_values[pardiminfo[1]] : m.time_labels)
    if pardiminfo[1]==:time
        comp_start = m.components2[componentname].offset
        comp_final = m.components2[componentname].final
        start = findfirst(values, comp_start)
        final = findfirst(values, comp_final)
        num = Mimi.getspan(m, componentname)
    end

    if length(pardiminfo)==1
        df[pardiminfo[1]] = values
        if pardiminfo[1]==:time
            df[name] = vcat(repeat([NaN], inner=start-1), mi[componentname, name], repeat([NaN], inner=length(values)-final))
        else
            df[name] = mi[componentname, name]
        end
        return df
    elseif length(pardiminfo)==2
        dim2 = length(m.indices_values[pardiminfo[2]])
        dim1 = length(m.indices_values[pardiminfo[1]])
        df[pardiminfo[1]] = repeat(values, inner=[dim2])
        df[pardiminfo[2]] = repeat(m.indices_values[pardiminfo[2]], outer=[dim1])

        data = m[componentname, name]
        if pardiminfo[1]==:time
            top = fill(NaN, (start-1, dim2))
            bottom = fill(NaN, (dim1-final, dim2))
            data = vcat(top, data, bottom)
        end
        df[name] = cat(1,[vec(data[i,:]) for i=1:dim1]...)

        return df
    else
        error("Not yet implemented")
    end
end
