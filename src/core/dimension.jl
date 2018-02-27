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

export Dimension, DimensionKey, DimensionKeyVector

const DimensionKey = Union{Int64, String, Symbol}

const DimensionKeyVector = Union{Vector{Int64}, Vector{String}, Vector{Symbol}}

abstract type AbstractDimension end

struct Dimension <: AbstractDimension
    dict::OrderedDict{DimensionKey, Int64}

    function Dimension(keys::DimensionKeyVector)
        dict = OrderedDict{DimensionKey, Int64}(collect(zip(keys, 1:length(keys))))
        return new(dict)
    end
end

function Dimension(r::Range)
    keys::DimensionKeyVector = collect(r)
    return Dimension(keys)
end

# Support Dimension(:foo, :bar, :baz)
function Dimension(keys...)
    vector::DimensionKeyVector = [key for key in keys]
    return Dimension(vector)
end

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

get(dim::Dimension, key::DimensionKey, default::Any) = get(dim.dict, key, default)

getindex(dim::Dimension, key::DimensionKey) = getindex(dim.dict, key)

# Support dim[[:foo, :bar, :baz]], dim[(:foo, :bar, :baz)], and dim[2010:2020]
getindex(dim::AbstractDimension, keys::Union{DimensionKeyVector, Tuple, Range}) = [get(dim.dict, key, 0) for key in keys]

getindex(dim::AbstractDimension, keys...) = getindex(dim, keys)

#
# Global registry for Dimension instances
# 
global const _dimension_registry = Dict{Symbol, AbstractDimension}()

function register_dimension(name::Symbol, dim::AbstractDimension)
    _dimension_registry[name] = dim
    return nothing
end

function retrieve_dimension(name::Symbol)
    return _dimension_registry[name]
end

registered_dimensions() = collect(keys(_dimension_registry))

#
# Simple optimization for ranges since indices are computable.
# Unclear whether this is really any better than simply using 
# a dict for all cases. Might scrap this in the end.
#
mutable struct RangeDimension <: AbstractDimension
    range::Range
 end

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
