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

key_type(dim::Dimension) = dim.key_type

#
# Iteration and basic dictionary methods are delegated to the internal dict
#
Base.length(dim::Dimension)      = length(dim.dict)
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

# Get last value from OrderedDict of keys
Base.endof(dim::AbstractDimension) = dim.dict.keys[length(dim)]

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
