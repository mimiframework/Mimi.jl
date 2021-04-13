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

        # propagate the time dimension through all sub-components
        _propagate_time_dim!(ccd, dim)
        set_uniform!(ccd, isuniform(keys))
        
        if redefined
            
            # TODO: pad all parameters with a time dimension

        end
    end
    return set_dimension!(ccd, name, dim)
end

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

function add_dimension!(comp::AbstractComponentDef, name)
    # generally, we add dimension name with nothing instead of a Dimension instance,
    # but in the case of an Int name, we create the "anonymous" dimension on the fly.
    dim = (name isa Int) ? Dimension(name) : nothing
    comp.dim_dict[Symbol(name)] = dim                         # TBD: test this
end

# Note that this operates on the registered comp, not one added to a composite
add_dimension!(comp_id::ComponentId, name) = add_dimension!(compdef(comp_id), name)

function dim_names(ccd::AbstractCompositeComponentDef)
    dims = OrderedSet{Symbol}()             # use a set to eliminate duplicates
    for cd in compdefs(ccd)
        union!(dims, keys(dim_dict(cd)))    # TBD: test this
    end

    return collect(dims)
end

dim_names(comp_def::AbstractComponentDef, datum_name::Symbol) = dim_names(datumdef(comp_def, datum_name))

dim_count(def::AbstractDatumDef) = length(dim_names(def))

