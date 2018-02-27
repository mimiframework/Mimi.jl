using DataFrames

"""
    getdataframe(m::Model, comp_name::Symbol, var_name::Symbol)

Return the values for variable `name` in `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, comp_name::Symbol, var_name::Symbol)
    mi = m.mi
    md = m.md

    if mi == nothing
        error("Cannot get dataframe; model has not been built yet")
    end

    dims = nothing

    try
        dims = indexlabels(m, comp_name, var_name)
    catch err
        if err isa KeyError
            error("Cannot get dataframe; variable $var_name not in component $comp_name")
        else
            rethrow(err)
        end
    end

    comp_inst = compinstance(mi, comp_name)

    num_dims = length(dims)
    if num_dims == 0
        return comp_inst[var_name]
    end

    df = DataFrame()
    dim1 = dims[1]

    values = (isempty(md.time_labels) || dim1 != :time ? indexvalues(m, dim1) : md.time_labels)

    if dim1 == :time
        comp_first = comp_inst.first_year
        comp_final = comp_inst.final_year

        first = findfirst(values, comp_first)
        final = findfirst(values, comp_final)
        # num = getspan(m, comp_id)             # unused
    end

    if num_dims == 1
        df[dim1] = values
        if dim1 == :time
            df[var_name] = vcat(repeat([NaN], inner = first - 1), mi[comp_name, var_name], 
                                repeat([NaN], inner = length(values) - final))
        else
            df[var_name] = mi[comp_name, var_name]  # TBD need to fix this
        end
        return df

    elseif num_dims == 2
        dim2 = dims[2]
        len_dim2 = length(indexvalues(m, dim2))
        len_dim1 = length(indexvalues(m, dim1))
        df[dim1] = repeat(values, inner = [len_dim2])
        df[dim2] = repeat(indexvalues(m, dim2), outer = [len_dim1])

        data = m[comp_name, var_name]
        if dim1 == :time
            top = fill(NaN, (first - 1, dim2))
            bottom = fill(NaN, (dim1 - final, dim2))
            data = vcat(top, data, bottom)
        end

        df[var_name] = cat(1, [vec(data[i, :]) for i = 1:dim1]...)

        return df
    else
        error("Dataframes with 0 or > 2 dimensions are not yet implemented")
    end
end

"""
    getdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => name::Symbol)...)
    getdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => (name::Symbol, name::Symbol...)...)

Return the values for each variable `name` in each corresponding `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, comp_name_pairs::Pair...)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    else
        return getdataframe(m, m.mi, comp_name_pairs)
    end
end

#
# TBD: eliminate redundancy in methods below and above. Distill out common functions...
#
function getdataframe(m::Model, mi::ModelInstance, comp_name_pairs::Tuple)
    #Make sure tuple passed in is not empty
    if length(comp_name_pairs) == 0
        error("Cannot get data frame, did not specify any componentname(s) and variable(s)")
    end

    # Get the base value of the number of dimensions from the first componentname and name pair association
    firstpair = comp_name_pairs[1]
    componentname = firstpair[1]
    name = firstpair[2]

    if isa(name, Tuple)
        name = name[1]
    end

    if !(name in variables(m, componentname))
        error("Cannot get dataframe; variable $name not in component $componentname")
    end

    vardiminfo = getvardiminfo(mi, componentname, name)
    num_dims = length(vardiminfo)

    #Initialize dataframe depending on num dimensions
    df = DataFrame()
    values = ((isempty(m.time_labels) || vardiminfo[1] != :time) ? m.indices_values[vardiminfo[1]] : m.time_labels)
    if num_dims == 1
        df[vardiminfo[1]] = values

    elseif num_dims == 2
        dim1 = length(m.indices_values[vardiminfo[1]])
        dim2 = length(m.indices_values[vardiminfo[2]])
        df[vardiminfo[1]] = repeat(values, inner = [dim2])
        df[vardiminfo[2]] = repeat(m.indices_values[vardiminfo[2]], outer = [dim1])
    end

    # Iterate through all the pairs; always check for each variable that the number of dimensions matches that of the first
    for pair in comp_name_pairs
        componentname = pair[1]
        name = pair[2]

        if isa(name, Tuple)
            for comp_var in name
                if !(comp_var in variables(m, componentname))
                    error("Cannot get dataframe; variable $comp_var not in component $componentname")
                end

                vardiminfo = getvardiminfo(mi, componentname, comp_var)
                if vardiminfo[1] == :time
                    comp_first = m.components2[componentname].first_year
                    comp_final = m.components2[componentname].final_year
                    first = findfirst(values, comp_first)
                    final = findfirst(values, comp_final)
                    # num = getspan(m, componentname)   # unused
                end

                if !(length(vardiminfo) == num_dims)
                    error(string("Not all components have the same number of dimensions"))
                end

                if (num_dims == 1)
                    if vardiminfo[1] == :time
                        df[comp_var] = vcat(repeat([NaN], inner = first - 1), mi[componentname, comp_var], repeat([NaN], inner = length(values) - final))
                    else
                        df[comp_var] = mi[componentname, comp_var]
                    end
                elseif (num_dims == 2)
                    data = m[componentname, comp_var]
                    if vardiminfo[1] == :time
                        top = fill(NaN, (first - 1, dim2))
                        bottom = fill(NaN, (dim1 - final, dim2))
                        data = vcat(top, data, bottom)
                    end
                    df[comp_var] = cat(1, [vec(data[i,:]) for i = 1:dim1]...)
                end
            end

        elseif (isa(name, Symbol))
            if !(name in variables(m, componentname))
                error("Cannot get dataframe; variable $name not in component $componentname")
            end

            vardiminfo = getvardiminfo(mi, componentname, name)
            if vardiminfo[1] == :time
                comp_first = m.components2[componentname].first_year
                comp_final = m.components2[componentname].final_year
                first = findfirst(values, comp_first)
                final = findfirst(values, comp_final)
                # num = getspan(m, componentname)       # unused
            end

            if !(length(vardiminfo) == num_dims)
                error("Not all components have the same number of dimensions")
            end

            if (num_dims == 1)
                if vardiminfo[1] == :time
                    df[name] = vcat(repeat([NaN], inner = first - 1), mi[componentname, name], repeat([NaN], inner = length(values) - final))
                else
                    df[name] = mi[componentname, name]
                end
            elseif (num_dims == 2)
                data = m[componentname, name]
                if vardiminfo[1] == :time
                    top    = fill(NaN, (first - 1, dim2))
                    bottom = fill(NaN, (dim1 - final, dim2))
                    data   = vcat(top, data, bottom)
                end
                df[name] = cat(1, [vec(data[i,:]) for i = 1:dim1]...)
            end
        else
            error("Name value for variable(s) in a component, $componentname was neither a tuple nor a Symbol.")
        end
    end

    return df
end
