using DataFrames

"""
    _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol, df::Union{Void,DataFrame}=nothing)

Load a DataFrame from the variable or parameter `item_name` in component `comp_name`. If `df` is
nothing, a new DataFrame is allocated. Returns the populated DataFrame.
"""
function _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol, df::Union{Void,DataFrame}=nothing)
    mi = m.mi
    md = mi.md
    comp_inst = compinstance(mi, comp_name)

    dims = indexlabels(m, comp_name, item_name)

    # Create a new df if one was not passed in
    df = df == nothing ? DataFrame() : df

    if haskey(df.colindex, item_name)
        error("An item named $item_name already exists in this DataFrame")
    end

    num_dims = length(dims)
    if ! (num_dims in (1,2))
        error("Can't create a dataframe from scalar value :$item_name")
    end

    dim1 = dims[1]

    time_labels = timelabels(md)
    # values = (isempty(time_labels) || dim1 != :time ? indexvalues(m, dim1) : time_labels)
    values = (isempty(time_labels) || dim1 != :time ? dim_keys(md, dim1) : time_labels)

    if dim1 == :time
        start = findfirst(values, comp_inst.start)
        stop  = findfirst(values, comp_inst.stop)
    end

    if num_dims == 1
        df[dim1] = values
        if dim1 == :time
            df[item_name] = vcat(repeat([NaN], inner=start - 1), mi[comp_name, item_name], 
                                 repeat([NaN], inner=length(values) - stop))
        else
            df[item_name] = mi[comp_name, item_name]  # TBD need to fix this?
        end
        return df

    elseif num_dims == 2
        dim2 = dims[2]
        len_dim1 = dim_count(md, dim1)
        len_dim2 = dim_count(md, dim2)
        df[dim1] = repeat(values, inner = [len_dim2])
        df[dim2] = repeat(dim_keys(md, dim2), outer = [len_dim1])

        data = m[comp_name, item_name]
        if dim1 == :time
            top    = fill(NaN, start - 1, len_dim2)
            bottom = fill(NaN, len_dim1 - stop, len_dim2)
            data = vcat(top, data, bottom)
        end

        df[item_name] = cat(1, [vec(data[i, :]) for i = 1:len_dim1]...)

        return df
    else
        error("DataFrames with 0 or > 2 dimensions are not yet implemented")
    end
end

"""
    getdataframe(m::Model, comp_name::Symbol, item_name::Symbol)

Return the values for variable or parameter `item_name` in `comp_name` of 
model `m` as a DataFrame.
"""
function getdataframe(m::Model, comp_name::Symbol, item_name::Symbol)
    mi = m.mi
    if mi == nothing
        error("Cannot get DataFrame: model has not been built yet")
    end

    df = _load_dataframe(m, comp_name, item_name)
    return df
end

"""
    getdataframe(m::Model, comp_name_pairs::Pair(comp_name::Symbol => name::Symbol)...)
    getdataframe(m::Model, comp_name_pairs::Pair(comp_name::Symbol => (name::Symbol, name::Symbol...)...)

Return the values for each variable `name` in each corresponding `comp_name` of model `m` as a DataFrame.
"""
getdataframe(m::Model, comp_name_pairs::Pair...) = getdataframe(m, comp_name_pairs)

function getdataframe(m::Model, comp_name_pairs::Tuple)
    mi = m.mi
    if mi == nothing
        error("Cannot get DataFrame: model has not been built yet")
    end

    # Make sure tuple passed in is not empty
    if length(comp_name_pairs) == 0
        error("Cannot get DataFrame: did not specify any component name(s) and variable(s)")
    end

    # Get the base value of the number of dimensions from the first comp_name and name pair association
    first_pair = comp_name_pairs[1]
    comp_name = first_pair[1]
    item_name  = first_pair[2]

    if isa(item_name, Tuple)
        item_name = item_name[1]
    elseif ! isa(item_name, Symbol)
        error("Name of variable or parameter $item_name in component $comp_name was neither a Tuple nor a Symbol.")
    end
   
    dims = indexlabels(m, comp_name, item_name)
    num_dims = length(dims)
    
    df = nothing

    # Iterate over pairs; checking dimensions and appending to the df
    for (comp_name, item_names) in comp_name_pairs
        if ! isa(item_names, Tuple)
            item_names = tuple(item_names)
        end

        for item_name in item_names
            next_dims = indexlabels(m, comp_name, item_name)
            if length(next_dims) != num_dims
                error("Cannot get DataFrame: Variable or parameter $item_name in component $comp_name has different number of dimensions")
            end

            df = _load_dataframe(m, comp_name, item_name, df)
        end
    end

    return df
end
