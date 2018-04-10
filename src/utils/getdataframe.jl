using DataFrames

"""
    _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol), df::Union{Void,DataFrame}=nothing)

Load a DataFrame from the variable or parameter `item_name` in component `comp_name`. If `df` is
nothing, a new DataFrame is allocated. Returns the populated DataFrame.
"""
function _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol, df::Union{Void,DataFrame}=nothing)
    mi = m.mi
    md = mi.md
    comp_inst = compinstance(mi, comp_name)

    dims = dimensions(m, comp_name, item_name)

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

    # We don't need "time_labels" with new Dimension object.
    # time_labels = timelabels(md)
    # values = (isempty(time_labels) || dim1 != :time ? dim_keys(md, dim1) : time_labels)

    keys = dim_keys(md, dim1)

    if dim1 == :time
        start = findfirst(keys, comp_inst.start)
        stop  = findfirst(keys, comp_inst.stop)
    end

    if num_dims == 1
        df[dim1] = keys
        if dim1 == :time
            df[item_name] = vcat(repeat([NaN], inner=start - 1), mi[comp_name, item_name], 
                                 repeat([NaN], inner=length(keys) - stop))
        else
            df[item_name] = mi[comp_name, item_name]  # TBD need to fix this?
        end
        return df

    elseif num_dims == 2
        dim2 = dims[2]
        len_dim1 = dim_count(md, dim1)
        len_dim2 = dim_count(md, dim2)
        df[dim1] = repeat(keys, inner = [len_dim2])
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

# TBD: this version relies on DataFrame to convert the data to long form, but it doesn't work yet.
"""
    _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol) # , df::Union{Void,DataFrame}=nothing)

Load a DataFrame from the variable or parameter `item_name` in component `comp_name`. If `df` is
nothing, a new DataFrame is allocated. Returns the populated DataFrame.
"""
function _load_dataframe_NEW(m::Model, comp_name::Symbol, item_name::Symbol) #, df::Union{Void,DataFrame}=nothing)
    mi = m.mi
    md = mi.md

    dims = dimensions(m, comp_name, item_name)
    num_dims = length(dims)
    if num_dims == 0
        error("Can't create a dataframe from scalar value :$item_name")
    end

    # if df != nothing && haskey(df.colindex, item_name)
    #     error("An item named $item_name already exists in this DataFrame")
    # end

    if ! (num_dims in (1, 2))
        error("DataFrames with > 2 dimensions are not yet supported")
    end

    # Create a new df if one was not passed in
    # df = df == nothing ? DataFrame() : df

    data = m[comp_name, item_name]
    dim1 = dims[1]
    keys1 = dim_keys(md, dim1)

    if num_dims == 1
        if length(keys1) != length(data)
            println("Data: $data")
            error("$comp_name.$item_name: length of keys $(length(keys1)) != length data $(length(data))")
        end
        df = DataFrame()
        df[dim1] = keys1
        df[item_name] = data
    else
        keys2 = dim_keys(md, dims[2])
        df = DataFrame(data)
        names!(df, keys2)
        df[dim1] = dim_keys(md, dim1)
        df = stack(df, keys2)           # convert to long form
    end

    return df
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
