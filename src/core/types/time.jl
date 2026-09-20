#
# Types supporting parameterized Timestep and Clock objects
#

abstract type AbstractTimestep end

struct FixedTimestep{FIRST, STEP, LAST} <: AbstractTimestep
    t::Int
end

struct VariableTimestep{TIMES} <: AbstractTimestep
    t::Int
    current::Int

    function VariableTimestep{TIMES}(t::Int = 1) where {TIMES}
        # The special case below handles when functions like next_step step beyond
        # the end of the TIMES array.  The assumption is that the length of this
        # last timestep, starting at TIMES[end], is 1.
        current::Int = t > length(TIMES) ? TIMES[end] + 1 : TIMES[t]

        return new(t, current)
    end
end

"""
    TimestepValue

A user-facing type used to index into a `TimestepArray` in `run_timestep` functions,
containing a `value` of the same Type as the times in the `TimstepArray` which is used to
index into the array at that position, with an optional Int `offset` in terms of timesteps.
"""
struct TimestepValue{T}
    value::T
    offset::Int

    function TimestepValue(v::T; offset::Int = 0) where T
        return new{T}(v, offset)
    end
end

"""
     TimestepIndex

 A user-facing type used to index into a `TimestepArray` in `run_timestep` functions,
 containing an Int `index` that indicates the position in the array in terms of timesteps.
 """
struct TimestepIndex
    index::Int
end

mutable struct Clock{T <: AbstractTimestep}
	ts::T

	function Clock{T}(FIRST::Int, STEP::Int, LAST::Int) where T
		return new(FixedTimestep{FIRST, STEP, LAST}(1))
    end

    function Clock{T}(TIMES::NTuple{N, Int} where N) where T
        return new(VariableTimestep{TIMES}())
    end
end

mutable struct TimestepArray{T_TS <: AbstractTimestep, T, N, ti, S<:AbstractArray{T,N}}
   
    data::S

    function TimestepArray{T_TS, T, N, ti}(d::S) where {T_TS, T, N, ti, S}
		return new{T_TS, T, N, ti, S}(d)
	end

end

function TimestepArray{T_TS, T, N, ti}(lengths::Int...) where {T_TS, T, N, ti}
    return TimestepArray{T_TS, T, N, ti}(Array{T, N}(undef, lengths...))
end

# Since these are the most common cases, we define methods (in time.jl)
# specific to these type aliases, avoiding some of the inefficiencies
# associated with an arbitrary number of dimensions.
const TimestepMatrix{T_TS, T, ti} = TimestepArray{T_TS, T, 2, ti}
const TimestepVector{T_TS, T} = TimestepArray{T_TS, T, 1, 1}

"""
    OffsetTimeArray{T, N, ti, A <: AbstractArray{T, N}} <: AbstractArray{T, N}

A lazy stand-in for data that covers only part of a model's time dimension. It
reports `len` elements along dimension `ti` -- the full length of the model's time
dimension -- while storing only `parent`, whose first element sits at position
`offset + 1`. Reading a position `parent` does not cover returns `missing`, so its
element type is `Union{Missing, eltype(parent)}` even though `parent` itself keeps
whatever element type it was given.

This replaces materializing `missing` padding around a parameter whose time labels
are narrower than the model's. Reads behave exactly as they did before -- component
code still sees a `MissingException` raised by `_missing_data_check`, and
introspection such as `getdataframe` still sees `missing` -- but the data is no
longer copied, does not gain a selector byte per element, and can be externally
owned (for instance memory-mapped).
"""
struct OffsetTimeArray{T, N, ti, A <: AbstractArray} <: AbstractArray{T, N}
    parent::A
    offset::Int
    len::Int
end

function OffsetTimeArray{ti}(parent::A, offset::Int, len::Int) where {ti, A <: AbstractArray}
    offset >= 0 ||
        error("Cannot construct an OffsetTimeArray with a negative offset ($offset).")
    offset + size(parent, ti) <= len ||
        error("Cannot construct an OffsetTimeArray of length $len holding ",
              "$(size(parent, ti)) elements at offset $offset; the data would ",
              "extend past the end of the time dimension.")
    return OffsetTimeArray{Union{Missing, eltype(A)}, ndims(A), ti, A}(parent, offset, len)
end
