using DataFrames

"""
    _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol), df::Union{Void,DataFrame}=nothing)

Load a DataFrame from the variable or parameter `item_name` in component `comp_name`. If `df` is
nothing, a new DataFrame is allocated. Returns the populated DataFrame.
"""
function _load_dataframe(m::Model, comp_name::Symbol, item_name::Symbol, df::Union{Void,DataFrame}=nothing)
    mi = m.mi
    md = mi.md

    dims = dimensions(m, comp_name, item_name)

    # Create a new df if one was not passed in
    df = df == nothing ? DataFrame() : df

    if haskey(df.colindex, item_name)
        error("An item named $item_name already exists in this DataFrame")
    end

    num_dims = length(dims)
    if num_dims == 0
        error("Can't create a dataframe from scalar value :$item_name")
    end

    data = mi[comp_name, item_name]

    if num_dims == 1
        dim1 = dims[1]
        df[dim1] = keys = dim_keys(md, dim1)

        if dim1 == :time
            ci = compinstance(mi, comp_name)
            first = findfirst(keys, ci.first)
            last  = findfirst(keys, ci.last)

            df[item_name] = vcat(repeat([NaN], inner=first - 1), data, 
                                 repeat([NaN], inner=length(keys) - last))
        else
            df[item_name] = data
        end
    else
        df = _df_helper(m, comp_name, item_name, dims, data)
    end

    return df
end

function _df_helper(m::Model, comp_name::Symbol, item_name::Symbol, dims::Vector{Symbol}, data::AbstractArray)
    md = m.md
    num_dims = length(dims)
    dim1 = dims[1]
    keys1 = dim_keys(md, dim1)

    df = DataFrame()

    if num_dims == 2
        dim2 = dims[2]
        len_dim1 = dim_count(md, dim1)
        len_dim2 = dim_count(md, dim2)
        df[dim1] = repeat(keys1, inner = [len_dim2])
        df[dim2] = repeat(dim_keys(md, dim2), outer = [len_dim1])

        if dim1 == :time
            ci = compinstance(m.mi, comp_name)
            first = findfirst(keys1, ci.first)
            last  = findfirst(keys1, ci.last)

            top    = fill(NaN, first - 1, len_dim2)
            bottom = fill(NaN, len_dim1 - last, len_dim2)
            data = vcat(top, data, bottom)
        end

        df[item_name] = cat(1, [vec(data[i, :]) for i = 1:len_dim1]...)
    else
        # Indexes is #, :, :, ... for each index of first dimension
        indexes = repmat(Any[Colon()], num_dims)

        for i in 1:size(data)[1]
            indexes[1] = i
            subdf = _df_helper(m, comp_name, item_name, dims[2:end], data[indexes...])
            subdf[dims[1]] = keys1[i]

            if i == 1
                # add required columns in the first iteration
                df_names = names(df)
                for name in names(subdf)
                    if ! (name in df_names)
                        df[name] = []
                    end
                end
            end
            df = vcat(df, subdf)
        end        
    end

    return df
end


"""
    getdataframe(m::Model, comp_name::Symbol, pairs::Pair{Symbol, Symbol}...)

Return a DataFrame with values for the given variables or parameters of model `m`
indicated by `pairs`, where each pair is of the form `comp_name => item_name`.
If more than one pair is provided, all must refer to items with the same
dimensions, which are used to join the respective item values.
"""
function getdataframe(m::Model, pairs::Pair{Symbol, Symbol}...)  
    (comp_name1, item_name1) = pairs[1]
    dims = dimensions(m, comp_name1, item_name1)
    df = getdataframe(m, comp_name1, item_name1)

    for (comp_name, item_name) in pairs[2:end]
        next_dims = dimensions(m, comp_name, item_name)
        if dims != next_dims
            error("Can't create DataFrame from items with different dimensions ($comp_name1.$item_name1: $dims vs $comp_name.$item_name: $next_dims)")
        end
        result = getdataframe(m, comp_name, item_name)
        df = hcat(df, result[[item_name]])      # [[xx]] retrieves a 1 column DataFrame
    end

    return df
end

"""
    getdataframe(m::Model, pair::Pair{Symbol, NTuple{N, Symbol}})

Return a DataFrame with values for the given variables or parameters 
indicated by `pairs`, where each pair is of the form `comp_name => item_name`.
If more than one pair is provided, all must refer to items with the same
dimensions, which are used to join the respective item values.

"""
function getdataframe(m::Model, pair::Pair{Symbol, NTuple{N, Symbol}}) where N
    comp_name = pair.first
    expanded = [comp_name => param_name for param_name in pair.second]
    return getdataframe(m, expanded...)
end

"""
    getdataframe(m::Model, comp_name::Symbol, item_name::Symbol)

Return the values for variable or parameter `item_name` in `comp_name` of 
model `m` as a DataFrame.
"""
function getdataframe(m::Model, comp_name::Symbol, item_name::Symbol)
    if m.mi == nothing
        error("Cannot get DataFrame: model has not been built yet")
    end

    df = _load_dataframe(m, comp_name, item_name)
    return df
end
