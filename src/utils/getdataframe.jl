using DataFrames

"""
    _load_dataframe(m::AbstractModel, comp_name::Symbol, item_name::Symbol), df::Union{Nothing,DataFrame}=nothing)

Load a DataFrame from the variable or parameter `item_name` in component `comp_name`. If `df` is
nothing, a new DataFrame is allocated. Returns the populated DataFrame.
"""
function _load_dataframe(m::AbstractModel, comp_name::Symbol, item_name::Symbol, df::Union{Nothing,DataFrame}=nothing)
    md, mi = m isa MarginalModel ? (m.base.md, m.base.mi) : (m.md, m.mi)

    dims = dim_names(m, comp_name, item_name)

    # Create a new df if one was not passed in
    df = df === nothing ? DataFrame() : df

    if hasproperty(df, item_name)
        error("An item named $item_name already exists in this DataFrame")
    end

    num_dims = length(dims)
    if num_dims == 0
        error("Cannot create a dataframe for a scalar parameter :$item_name")
    end
    paths = m isa MarginalModel ? _get_all_paths(m.base) : _get_all_paths(m)
    comp_path = paths[comp_name];
    data = m[comp_path, item_name] === nothing ? m[comp_name, item_name] : m[comp_path, item_name]
    
    if num_dims == 1
        dim1name = dims[1]
        dim1 = dimension(md, dim1name)
        df[!, dim1name] = collect(keys(dim1))
        # @info "dim: $dim1name size(df): $(size(df))"

        # df[item_name] = data

        if dim1name == :time && size(data)[1] != length(time_labels(md))
            ci = compinstance(mi, comp_name)
            first = dim1[ci.first]  # Dimension converts year key to index in array
            last  = dim1[ci.last]

            # Pad the array with NaNs outside this component's bounds
            shifted_data = vcat(repeat([missing], inner=first - 1), 
                                data[1:(last-first+1)], # ignore padding after these values
                                repeat([missing], inner=length(dim1) - last))
            # @info "len shifted: $(length(shifted_data))"
            df[!, item_name] = shifted_data
        else
            df[!, item_name] = deepcopy(data)
        end
    else
        df = _df_helper(m, comp_name, item_name, dims, data)
    end

    return df
end

function _df_helper(m::AbstractModel, comp_name::Symbol, item_name::Symbol, dims::Vector{Symbol}, data::AbstractArray)
    md, mi = m isa MarginalModel ? (m.base.md, m.base.mi) : (m.md, m.mi)
    num_dims = length(dims)

    dim1name = dims[1]
    dim1 = dimension(md, dim1name)
    keys1 = collect(keys(dim1))
    len_dim1 = length(dim1)

    df = DataFrame()

    if num_dims == 2
        dim2name = dims[2]
        dim2 = dimension(md, dim2name)
        keys2 = collect(keys(dim2))
        len_dim2 = length(dim2)

        df[!, dim1name] = repeat(keys1, inner = [len_dim2])
        df[!, dim2name] = repeat(keys2, outer = [len_dim1])

        if dim1name == :time && size(data)[1] != len_dim1
            ci = compinstance(mi, comp_name)
            t = dimension(m, :time)
            first = t[ci.first]
            last  = t[ci.last]

            top    = fill(missing, first - 1, len_dim2)
            bottom = fill(missing, len_dim1 - last, len_dim2)
            data = vcat(top, data, bottom)
        end

        df[!, item_name] = collect(vec(data'))
    else

        # shift the data to be padded with missings if this data is shorter than the model
        if dim1name == :time && size(data)[1] != len_dim1
            ci = compinstance(mi, comp_name)
            t = dimension(m, :time)
            first = t[ci.first]
            last  = t[ci.last]

            rest_dim_lens = [length(dimension(md, dimname)) for dimname in dims[2:end]]
            top = fill(missing, first - 1, rest_dim_lens...)
            bottom = fill(missing, len_dim1 - last, rest_dim_lens...)

            data = vcat(top, data, bottom)  
        end

        # Indexes is #, :, :, ... for each index of first dimension
        indexes = repeat(Any[Colon()], num_dims)

        for i in 1:size(data)[1]
            indexes[1] = i
            subdf = _df_helper(m, comp_name, item_name, dims[2:end], data[indexes...])
            subdf[!, dims[1]] .= keys1[i]

            if i == 1
                # add required columns in the first iteration
                df_names = names(df)
                for name in names(subdf)
                    if ! (name in df_names)
                        df[!, name] = []
                    end
                end
            end
            df = vcat(df, subdf)
        end        
    end

    return df
end


"""
    getdataframe(m::AbstractModel, comp_name::Symbol, pairs::Pair{Symbol, Symbol}...)

Return a DataFrame with values for the given variables or parameters of model `m`
indicated by `pairs`, where each pair is of the form `comp_name => item_name`.
If more than one pair is provided, all must refer to items with the same
dimensions, which are used to join the respective item values.
"""
function getdataframe(m::AbstractModel, pairs::Pair{Symbol, Symbol}...)  
    (comp_name1, item_name1) = pairs[1]
    dims = dim_names(m, comp_name1, item_name1)
    df = getdataframe(m, comp_name1, item_name1)

    for (comp_name, item_name) in pairs[2:end]
        next_dims = dim_names(m, comp_name, item_name)
        if dims != next_dims
            error("Cannot create DataFrame from items with different dimensions ($comp_name1.$item_name1: $dims vs $comp_name.$item_name: $next_dims)")
        end
        result = getdataframe(m, comp_name, item_name)
        df = hcat(df, result[!, [item_name]])      # [[xx]] retrieves a 1 column DataFrame
    end

    return df
end

"""
    getdataframe(m::AbstractModel, pair::Pair{Symbol, NTuple{N, Symbol}})

Return a DataFrame with values for the given variables or parameters 
indicated by `pairs`, where each pair is of the form `comp_name => item_name`.
If more than one pair is provided, all must refer to items with the same
dimensions, which are used to join the respective item values.
"""
function getdataframe(m::AbstractModel, pair::Pair{Symbol, NTuple{N, Symbol}}) where N
    comp_name = pair.first
    expanded = [comp_name => param_name for param_name in pair.second]
    return getdataframe(m, expanded...)
end

"""
    getdataframe(m::AbstractModel, comp_name::Symbol, item_name::Symbol)

Return the values for variable or parameter `item_name` in `comp_name` of 
model `m` as a DataFrame.
"""
function getdataframe(m::AbstractModel, comp_name::Symbol, item_name::Symbol)
    if ! is_built(m)
        error("Cannot get DataFrame: model has not been built yet.")
    end

    df = _load_dataframe(m, comp_name, item_name)
    return df
end
