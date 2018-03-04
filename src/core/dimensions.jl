#
# Dimension: translates sequences of Symbols, Strings, or Ints to 
# ordinal values, so the Dimension keys can be used for lookup in
# Arrays in Mimi. A Dimension can be declared one of several ways:
# dim = Dimension(:foo, :bar, :baz)      # varargs
# dim = Dimension([:foo, :bar, :baz])    # Vector
# dim = Dimension(2010:2100)             # Range or S
#
# Similarly, values can be referenced several ways:
# value  = Dimension[:foo]               # single lookup
# values = Dimension[(:foo, :bar)]       # Tuple of values
# values = Dimension[[2010, 2020, 2030]] # Vector of values
# values = Dimension[2010, 2020, 2030]   # Varargs
# values = Dimension[2010:10:2030]       # Range
#
using DataStructures

key_type(dim::Dimension) = dim.key_type

#
# Iteration and basic dictionary methods are delegated to the internal dict
#
import Base: length, start, next, done, keys, values, get, getindex

length(dim::Dimension)      = length(dim.dict)
start(dim::Dimension)       = start(dim.dict)
next(dim::Dimension, state) = next(dim.dict, state)
done(dim::Dimension, state) = done(dim.dict, state)

keys(dim::Dimension)   = keys(dim.dict)
values(dim::Dimension) = values(dim.dict)

get(dim::Dimension, key::Union{Number, Symbol, String}, default::Any) = get(dim.dict, key, default)

# getindex(dim::Dimension, key::Union{Array{T,1} where T, Range, Tuple}) = getindex(dim.dict, key)

getindex(dim::Dimension, key::Colon) = collect(values(dim.dict))

# Support dim[[:foo, :bar, :baz]], dim[(:foo, :bar, :baz)], and dim[2010:2020]
getindex(dim::AbstractDimension, keys::Union{Vector{T} where T, Tuple, Range}) = [getindex(dim.dict, key) for key in keys]

getindex(dim::AbstractDimension, keys...) = getindex(dim, keys)

#
# Global registry for Dimension instances. 
# Might not need this once stored in ModelDef.
# 
# global const _dimension_registry = Dict{Symbol, AbstractDimension}()

# function register_dimension(name::Symbol, dim::AbstractDimension)
#     if haskey(_dimension_registry, name)
#         warn("Redefining index $name")
#     end
#     _dimension_registry[name] = dim
#     return nothing
# end

# function retrieve_dimension(name::Symbol)
#     return _dimension_registry[name]
# end

# retrieve_dimensions(names::Vector{Symbol}) = map(retrieve_dimension, names)

# registered_dimensions() = collect(keys(_dimension_registry))


length(dim::RangeDimension) = length(dim.range)
start(dim::RangeDimension)  = start(dim.range)
next(dim::RangeDimension, state) = next(dim.range, state)
done(dim::RangeDimension, state) = done(dim.range, state)

keys(dim::RangeDimension)   = collect(dim.range)
values(dim::RangeDimension) = collect(1:length(dim.range))

#
# Compute the index of a "key" (e.g., a year) in the range. 
#
function get(dim::RangeDimension, key::Int64, default::Any=0) 
    r = dim.range
    i = key - r.start
    return i == 0 ? 1 : (i % r.step != 0 ? default : 1 + div(i, r.step))
end

# Support dim[[2010, 2020, 2030]], dim[(:foo, :bar, :baz)], and dim[2010:2050]
getindex(dim::RangeDimension, keys::Union{Vector{Int64}, Tuple, Range}) = [get(dim, key, 0) for key in keys]
