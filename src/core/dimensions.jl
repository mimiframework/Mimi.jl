#
# Dimension: translates sequences of Symbols, Strings, or Ints to 
# ordinal values, so the Dimension keys can be used for lookup in
# Arrays in Mimi. A Dimension can be declared one of several ways:
# dim = Dimension(:foo, :bar, :baz)      # varargs
# dim = Dimension([:foo, :bar, :baz])    # Vector
# dim = Dimension(2010:2100)             # Range
# dim = Dimension(4)                     # Same as 1:4
#
# Similarly, values can be referenced several ways:
# value  = Dimension[:foo]               # single lookup
# values = Dimension[(:foo, :bar)]       # Tuple of values
# values = Dimension[[2010, 2020, 2030]] # Vector of values
# values = Dimension[2010, 2020, 2030]   # Varargs
# values = Dimension[2010:10:2030]       # AbstractRange
#
using DataStructures

key_type(dim::Dimension{T}) where {T <: DimensionKeyTypes} = T

#
# Iteration and basic dictionary methods are delegated to the internal dict
#
Base.length(dim::Dimension) = length(dim.dict)
Base.iterate(dim::Dimension, state...) = iterate(dim.dict, state...)

Base.keys(dim::Dimension)   = keys(dim.dict)
Base.values(dim::Dimension) = values(dim.dict)

Base.get(dim::Dimension, key::Union{Number, Symbol, String}, default::Any) = get(dim.dict, key, default)

Base.getindex(dim::Dimension, key::Colon) = collect(values(dim.dict))

Base.getindex(dim::AbstractDimension, key::Union{Number, Symbol, String}) = getindex(dim.dict, key)

# Support dim[[:foo, :bar, :baz]], dim[(:foo, :bar, :baz)], and dim[2010:2020]
Base.getindex(dim::AbstractDimension, keys::Union{Vector{T} where T, Tuple, AbstractRange}) = [getindex(dim.dict, key) for key in keys]

Base.getindex(dim::AbstractDimension, keys...) = getindex(dim, keys)

Base.length(dim::RangeDimension) = length(dim.range)
Base.iterate(dim::RangeDimension, state...)  = iterate(dim.range, state...)

Base.keys(dim::RangeDimension)   = collect(dim.range)
Base.values(dim::RangeDimension) = collect(1:length(dim.range))

# Get first/last value from OrderedDict of keys
Base.firstindex(dim::AbstractDimension) = dim.dict.keys[1]
Base.lastindex(dim::AbstractDimension)  = dim.dict.keys[length(dim)]

#
# Compute the index of a "key" (e.g., a year) in the range. 
#
function Base.get(dim::RangeDimension, key::Int, default::Any=0) 
    r = dim.range
    i = key - r.start
    return i == 0 ? 1 : (i % r.step != 0 ? default : 1 + div(i, r.step))
end

# Support dim[[2010, 2020, 2030]], dim[(:foo, :bar, :baz)], and dim[2010:2050]
Base.getindex(dim::RangeDimension, keys::Union{Vector{Int}, Tuple, AbstractRange}) = [get(dim, key, 0) for key in keys]

# Symbols are added to the dim_dict in @defcomp (with value of nothing), but are set later using set_dimension!
has_dim(obj::AbstractCompositeComponentDef, name::Symbol) = (haskey(obj.dim_dict, name) && obj.dim_dict[name] !== nothing)

isuniform(obj::AbstractCompositeComponentDef) = obj.is_uniform

set_uniform!(obj::AbstractCompositeComponentDef, value::Bool) = (obj.is_uniform = value)

dimension(obj::AbstractCompositeComponentDef, name::Symbol) = obj.dim_dict[name]

dim_names(obj::AbstractCompositeComponentDef, dims::Vector{Symbol}) = [dimension(obj, dim) for dim in dims]

dim_count_dict(obj::AbstractCompositeComponentDef) = Dict([name => length(value) for (name, value) in dim_dict(obj)])

dim_counts(obj::AbstractCompositeComponentDef, dims::Vector{Symbol}) = [length(dim) for dim in dim_names(obj, dims)]
dim_count(obj::AbstractCompositeComponentDef, name::Symbol) = length(dimension(obj, name))

dim_keys(obj::AbstractCompositeComponentDef, name::Symbol)   = collect(keys(dimension(obj, name)))
dim_values(obj::AbstractCompositeComponentDef, name::Symbol) = collect(values(dimension(obj, name)))

"""
    set_dimension!(ccd::CompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange})

Set the values of `ccd` dimension `name` to integers 1 through `count`, if `keys` is
an integer; or to the values in the vector or range if `keys` is either of those types.
"""
function set_dimension!(ccd::AbstractCompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange})
   
    redefined = has_dim(ccd, name)
    dim = Dimension(keys)

    if name == :time

        # if we are redefining the time dimension of a model, the timestep length 
        # must match the timestep length of the old time dimension
        redefined && _check_time_redefinition(ccd, keys)   

        # propagate the time dimension through all sub-components
        _propagate_time_dim!(ccd, dim)
        set_uniform!(ccd, isuniform(keys))
        
        # if we are redefining the time dimension for a Model Definition
        # pad the time arrays with missings and update their time labels 
        redefined && (ccd isa ModelDef) && _pad_parameters!(ccd)

    # redefining a non-time dimension for a ModelDef
    elseif redefined && (ccd isa ModelDef)

        for (k, v) in ccd.model_params
            # We will reset any parameters with this dimension to nothing,
            # noting that this is only necessary to check if they are array model 
            # parameters, and thus have dimensionality, and are not already nothing
            if (v isa ArrayModelParameter) && (name in v.dim_names) && !is_nothing_param(v)
                ccd.model_params[k] = ArrayModelParameter(nothing, v.dim_names, v.is_shared)
            end
        end
    end

    return set_dimension!(ccd, name, dim)
end

"""
    set_dimension!(obj::AbstractComponentDef, name::Symbol, dim::Dimension)

Set the dimension `name` in `obj` to `dim`.
"""
function set_dimension!(obj::AbstractComponentDef, name::Symbol, dim::Dimension)
    dirty!(obj)
    obj.dim_dict[name] = dim

    if name == :time
        for subcomp in compdefs(obj)
            set_dimension!(subcomp, :time, dim)
        end
    end
    return dim
end

"""
    function add_dimension!(comp::AbstractComponentDef, name)

Add a dimension of name `name` to `comp`, where the dimension will be `nothing` 
unless `name` is an Int in which case we create an "anonymous" dimension on 
the fly with keys `1` through `count` where `count` = `name`.
"""
function add_dimension!(comp::AbstractComponentDef, name)
    # generally, we add dimension name with nothing instead of a Dimension instance,
    # but in the case of an Int name, we create the "anonymous" dimension on the fly.
    dim = (name isa Int) ? Dimension(name) : nothing
    comp.dim_dict[Symbol(name)] = dim                         # TBD: test this
end

# Note that this operates on the registered comp, not one added to a composite
add_dimension!(comp_id::ComponentId, name) = add_dimension!(compdef(comp_id), name)

"""
    dim_names(ccd::AbstractCompositeComponentDef)

Return a list of the dimension names of `ccd`.
"""
function dim_names(ccd::AbstractCompositeComponentDef)
    dims = OrderedSet{Symbol}()             # use a set to eliminate duplicates
    for cd in compdefs(ccd)
        union!(dims, keys(dim_dict(cd)))    # TBD: test this
    end

    return collect(dims)
end

"""
    dim_names(comp_def::AbstractComponentDef, datum_name::Symbol)

Return a list of the dimension names of datum `datum_name` in `comp_def`.
"""
dim_names(comp_def::AbstractComponentDef, datum_name::Symbol) = dim_names(datumdef(comp_def, datum_name))

"""
    dim_count(def::AbstractDatumDef)

Return number of dimensions in `def`.
"""
dim_count(def::AbstractDatumDef) = length(dim_names(def))

"""
    _check_time_redefinition(obj::AbstractCompositeComponentDef, keys::Union{Int, Vector, Tuple, AbstractRange})

Run through all necesssary safety checks for redefining `obj`'s time dimenson to 
a new dimension with keys `keys`.
"""
function _check_time_redefinition(obj::AbstractCompositeComponentDef, keys::Union{Int, Vector, Tuple, AbstractRange})

    # get useful variables 
    curr_keys = time_labels(obj)
    curr_first = obj.first
    curr_last = obj.last
    
    new_keys = [keys...]
    new_first = first(new_keys)
    new_last = last(new_keys)

    # (1) check that the shift is legal
    isa(obj, ModelDef) ? obj_name = "model" : obj_name = "component $(nameof(obj))"
    new_first > curr_first && error("Cannot redefine the time dimension to start at $new_first because it is after the $obj_name's current start $curr_first.") 
    curr_first > new_last && error("Cannot redefine the time dimension to end at $new_last because it is before the $obj_name's current start $curr_first")

    # (2) check first and last
    !(curr_first in new_keys) && error("The current first index ($curr_first) must exist within the model's new time dimension $new_keys.") # can be assumed since we cannot move the time forward
    curr_last >= new_last && !(new_last in curr_keys) && error("The new last index ($new_last) must exist within the model's current time dimension $curr_keys, since the time redefinition contracts to an earlier year.")
    curr_last < new_last && !(curr_last in new_keys) && error("The current last index ($curr_last) must exist within the model's redefined time dimension $new_keys, since the time redefinition expands to a later year.")

    # (3) check that the overlap region between the current keys and new keys holds same keys
    if length(curr_keys) > 1 && length(new_keys) > 1
        if isuniform(curr_keys) # fixed timesteps
            step_size(curr_keys) != step_size(new_keys) && error("Cannot redefine the time dimension to have a timestep size of $(step_size(new_keys)), must match the timestep size of current time dimension, $(step_size(curr_keys))")
        
        else # variable timesteps      
            start_idx = 1 # can be assumed since we cannot move the time forward
            new_last < curr_last ? end_idx = findfirst(isequal(new_last), curr_keys) : end_idx = length(curr_keys)
            expected_overlap = curr_keys[start_idx:end_idx]

            start_idx = findfirst(isequal(curr_first), new_keys)
            end_idx = start_idx + length(expected_overlap) - 1
            observed_overlap = new_keys[start_idx:end_idx]

            expected_overlap != observed_overlap && error("Cannot redefine the time dimension, the overlapping portion of the current and new times must be identical.")
        end
    end

end
