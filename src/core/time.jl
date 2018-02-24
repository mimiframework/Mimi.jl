#
#  TIMESTEP
#
function gettime{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return Offset + (ts.t - 1) * Duration
end

function is_first_timestep(ts::Timestep)
	return ts.t == 1
end

# for users to tell when they are on the final timestep
function is_final_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) == Final
end

# used to determine when a clock is finished
function past_final_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) > Final
end

function next_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	if past_final_timestep(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Offset, Duration, Final}(ts.t + 1)
end

function new_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final}, newoffset::Int)
	return Timestep{newoffset, Duration, Final}(Int64(ts.t + (Offset-newoffset)/Duration))
end


#
#  CLOCK
#
function timestep(c::Clock)
	return c.ts
end

function timeindex(c::Clock)
	return c.ts.t
end

function gettime(c::Clock)
	return gettime(c.ts)
end

function advance(c::Clock)
	c.ts = next_timestep(c.ts)
	nothing
end

function finished(c::Clock)
	return past_final_timestep(c.ts)
end

function within(c::Clock, start::Int, stop::Int)
	return start <= gettime(c) <= stop
end

#
# TimestepMatrix and TimestepVector
# TBD: combine these to avoid some duplication?
#
import Base: getindex, setindex!, eltype, fill!, size, indices, endof

function get_timestep_instance(T, offset, duration, num_dims, value)
	if ! (num_dims in (1, 2))
		error("TimeStepVector or TimestepMatrix support only 1 or 2 dimensions, not $num_dims")
	end

	timestep_type = num_dims == 1 ? TimestepVector : TimestepMatrix
	return timestep_type{T, offset, duration}(value)
end

# TBD: eliminate this after global renaming
start_year(obj::AbstractTimestepMatrix) = offset(obj)

#
# TimestepVector
#
function getindex(x::TimestepVector{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}) where {T,Offset,Duration,Final}
	return x.data[ts.t]
end

function getindex(x::TimestepVector{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final}) where {T,d_offset,Duration,t_offset,Final}
	t = Int64(ts.t + (t_offset - d_offset) / Duration)
	return x.data[t]
end

# int indexing version for old style components
function getindex(x::TimestepVector{T, Offset, Duration}, i::OT1) where {T,Offset,Duration,OT1 <: Union{Int, Colon, OrdinalRange}}
	return x.data[i]
end

function indices(x::TimestepVector{T, Offset, Duration}) where {T,Offset,Duration}
	return (Offset:Duration:(Offset + (length(x.data) - 1) * Duration), )
end

function offset(v::TimestepVector{T, Offset, Duration}) where {T,Offset,Duration}
	return Offset
end

function eltype(v::TimestepVector)
	return eltype(v.data)
end

function fill!(v::TimestepVector, x)
	fill!(v.data, x)
end

function setindex!(v::TimestepVector{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final}) where {T,Offset,Duration,Final}
	setindex!(v.data, a, ts.t)
end

function setindex!(v::TimestepVector{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final}) where {T,d_offset,Duration,t_offset,Final}
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	setindex!(v.data, a, t)
end

function setindex!(v::TimestepVector{T, offset, duration}, a, i::OT) where {T,offset,duration,OT <: Union{Int, Colon, OrdinalRange}}
	setindex!(v.data, a, i)
end

function size(v::TimestepVector)
	return size(v.data)
end

function size(v::TimestepVector, i::Int)
	return size(v.data, i)
end

# method where the vector and the timestep have the same offset
function hasvalue(v::TimestepVector{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}) where {T,Offset,Duration,Final}
	return 1 <= ts.t <= size(v, 1)
end

# method where they have different offsets
function hasvalue(v::TimestepVector{T, Offset1, Duration}, ts::Timestep{Offset2, Duration, Final}) where {T,Offset1,Offset2,Duration,Final}
	t = gettime(ts)
	return Offset1 <= t <= (Offset1 + (size(v, 1) - 1) * Duration)
end

function endof(v::TimestepVector)
	return length(v.data)
end

#
# TimestepMatrix
#
function getindex(x::TimestepMatrix{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}, i::OT1) where {T,Offset,Duration,Final,OT1 <: Union{Int, Colon, OrdinalRange}}
	return x.data[ts.t, i]
end

function getindex(x::TimestepMatrix{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final}, i::OT1) where {T,d_offset,Duration,t_offset,Final,OT1 <: Union{Int, Colon, OrdinalRange}}
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	return x.data[t, i]
end

# int indexing version for old style components
function getindex(x::TimestepMatrix{T, Offset, Duration}, t::OT1, i::OT2) where {T,Offset,Duration,OT1 <: Union{Int, Colon, OrdinalRange},OT2 <: Union{Int, Colon, OrdinalRange}}
	return x.data[t, i]
end

function setindex!(m::TimestepMatrix{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final}, j::OT1) where {T,Offset,Duration,Final,OT1 <: Union{Int, Colon, OrdinalRange}}
	setindex!(m.data, a, ts.t, j)
end

function setindex!(m::TimestepMatrix{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final}, j::OT1) where {T,d_offset,Duration,t_offset,Final,OT1 <: Union{Int, Colon, OrdinalRange}}
	t = Int64(ts.t + (t_offset - d_offset) / Duration)
	setindex!(m.data, a, t, j)
end

function setindex!(m::TimestepMatrix{T, offset, duration}, a, i::OT1, j::OT2) where {T,offset,duration,OT1 <: Union{Int, Colon, OrdinalRange},OT2 <: Union{Int, Colon, OrdinalRange}}
	setindex!(m.data, a, i, j)
end

function indices(x::TimestepMatrix{T, Offset, Duration}) where {T,Offset,Duration}
	return (Offset:Duration:(Offset + (size(x.data)[1] - 1) * Duration), 1:size(x.data)[2])
end

function offset(v::TimestepMatrix{T, Offset, Duration}) where {T,Offset,Duration}
	return Offset
end

function eltype(v::TimestepMatrix)
	return eltype(v.data)
end

function fill!(m::TimestepMatrix, x)
	fill!(m.data, x)
end

function size(m::TimestepMatrix)
	return size(m.data)
end

function size(m::TimestepMatrix, i::Int)
	return size(m.data, i)
end

# method where the vector and the timestep have the same offset
function hasvalue(m::TimestepMatrix{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}, j::Int) where {T,Offset,Duration,Final}
	return 1 <= ts.t <= size(m, 1) && 1 <= j <= size(m, 2)
end

# method where they have different offsets
function hasvalue(m::TimestepMatrix{T, Offset1, Duration}, ts::Timestep{Offset2, Duration, Final}, j::Int) where {T,Offset1,Offset2,Duration,Final}
	t = gettime(ts)
	return Offset1 <= t <= (Offset1 + (size(m, 1) - 1) * Duration) && 1 <= j <= size(m, 2)
end
