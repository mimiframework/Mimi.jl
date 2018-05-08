#
#  TIMESTEP
#
function gettime{Start, Step, Stop}(ts::Timestep{Start, Step, Stop})
	return Start + (ts.t - 1) * Step
end

function is_start(ts::Timestep)
	return ts.t == 1
end

# indicates when at final timestep
function is_stop{Start, Step, Stop}(ts::Timestep{Start, Step, Stop})
	return gettime(ts) == Stop
end

# used to determine when a clock is finished
function finished{Start, Step, Stop}(ts::Timestep{Start, Step, Stop})
	return gettime(ts) > Stop
end

function next_timestep{Start, Step, Stop}(ts::Timestep{Start, Step, Stop})
	if finished(ts)
			error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Start, Step, Stop}(ts.t + 1)
end

function new_timestep{Start, Step, Stop}(ts::Timestep{Start, Step, Stop}, new_start::Int)
	return Timestep{new_start, Step, Stop}(Int(ts.t + (Start - new_start) / Step))
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
	return finished(c.ts)
end

#
# TimestepMatrix and TimestepVector
#
function get_timestep_instance(T, start, step, num_dims, value)
	if !(num_dims in (1, 2))
			error("TimeStepVector or TimestepMatrix support only 1 or 2 dimensions, not $num_dims")
	end

	timestep_type = num_dims == 1 ? TimestepVector : TimestepMatrix
	return timestep_type{T, start, step}(value)
end

const AnyIndex = Union{Int, Vector{Int}, Tuple, Colon, OrdinalRange}

# TBD: can it be reduced to this?
# const AnyIndex = Union{Int, Range}

#
# TimestepVector
#
function Base.getindex(x::TimestepVector{T, Start, Step}, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	return x.data[ts.t]
end

function Base.getindex(x::TimestepVector{T, d_start, Step}, ts::Timestep{t_start, Step, Stop}) where {T, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	return x.data[t]
end

# int indexing version supports old style components
function Base.getindex(x::TimestepVector{T, Start, Step}, i::AnyIndex) where {T, Start, Step}
   	return x.data[i]
end

function Base.indices(x::TimestepVector{T, Start, Step}) where {T, Start, Step}
	return (Start:Step:(Start + (length(x.data) - 1) * Step), )
end

function Base.setindex!(v::TimestepVector{T, Start, Step}, val, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	setindex!(v.data, val, ts.t)
end

function Base.setindex!(v::TimestepVector{T, d_start, Step}, val, ts::Timestep{t_start, Step, Stop}) where {T, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	setindex!(v.data, val, t)
end

function Base.setindex!(v::TimestepVector{T, start, duration}, val, i::AnyIndex) where {T, start, duration}
	setindex!(v.data, val, i)
end

function Base.length(v::TimestepVector)
	return length(v.data)
end

Base.endof(v::TimestepVector) = length(v)

#
# TimestepMatrix
#
function Base.getindex(mat::TimestepMatrix{T, Start, Step}, ts::Timestep{Start, Step, Stop}, i::AnyIndex) where {T, Start, Step, Stop}
	return mat.data[ts.t, i]
end

function Base.getindex(mat::TimestepMatrix{T, d_start, Step}, ts::Timestep{t_start, Step, Stop}, i::AnyIndex) where {T, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	return mat.data[t, i]
end

# int indexing version supports old style components
function Base.getindex(mat::TimestepMatrix{T, Start, Step}, idx1::AnyIndex, idx2::AnyIndex) where {T, Start, Step}
	return mat.data[idx1, idx2]
end

function Base.setindex!(mat::TimestepMatrix{T, Start, Step}, val, ts::Timestep{Start, Step, Stop}, idx::AnyIndex) where {T, Start, Step, Stop}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{T, d_start, Step}, val, ts::Timestep{t_start, Step, Stop}, idx::AnyIndex) where {T, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{T, Start, Step}, val, idx1::AnyIndex, idx2::AnyIndex) where {T, Start, Step}
	setindex!(mat.data, val, idx1, idx2)
end

#
# TimestepArray methods
#
Base.fill!(obj::TimestepArray, value) = fill!(obj.data, value)

Base.size(obj::TimestepArray) = size(obj.data)

Base.size(obj::TimestepArray, i::Int) = size(obj.data, i)

Base.ndims(obj::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step} = N

Base.eltype(obj::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step} = T

start_period(obj::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step} = Start

end_period(obj::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step} = (Start + (size(obj, 1) - 1) * Step)

step_size(obj::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step} = Step

# TimestepArray and Timestep have the same Start and Step
function Base.getindex(arr::TimestepArray{T, N, Start, Step}, ts::Timestep{Start, Step, Stop}, idxs::AnyIndex...) where {T, N, Start, Step, Stop}
	return arr.data[ts.t, idxs...]
end

# TimestepArray and Timestep have different Start dates
function Base.getindex(arr::TimestepArray{T, N, d_start, Step}, ts::Timestep{t_start, Step, Stop}, idxs::AnyIndex...) where {T, N, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	return arr.data[t, idxs...]
end

# TimestepArray and Timestep have the same Start and Step
function Base.setindex!(arr::TimestepArray{T, N, Start, Step}, val, ts::Timestep{Start, Step, Stop}, idxs::AnyIndex...) where {T, N, Start, Step, Stop}
	setindex!(arr.data, val, ts.t, idxs...)
end

# TimestepArray and Timestep have different Start dates
function Base.setindex!(arr::TimestepArray{T, N, d_start, Step}, val, ts::Timestep{t_start, Step, Stop}, idxs::AnyIndex...) where {T, N, d_start, Step, t_start, Stop}
	t = Int(ts.t + (t_start - d_start) / Step)
	setindex!(arr.data, val, t, idxs...)
end

# Old-style: first index is Int or Range, rather than a Timestep
function Base.getindex(arr::TimestepArray{T, N, Start, Step}, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, Start, Step}
	return arr.data[idx1, idx2, idxs...]
end

# Old-style: first index is Int or Range, rather than a Timestep
function Base.setindex!(arr::TimestepArray{T, N, Start, Step}, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, Start, Step}
	setindex!(arr.data, val, idx1, idx2, idxs...)
end

function Base.indices(arr::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step}
	idxs = [1:size(arr, i) for i in 2:ndims(arr)]
	stop = end_period(arr)
	return (Start:Step:stop, idxs...)
end

# Legacy integer case
function hasvalue(arr::TimestepArray{T, N, Start, Step}, t::Int) where {T, N, Start, Step}
	return 1 <= t <= size(arr, 1)
end

# Array and timestep have the same start period and step
function hasvalue(arr::TimestepArray{T, N, Start, Step}, ts::Timestep{Start, Step, Stop}) where {T, N, Start, Step, Stop}
	return 1 <= ts.t <= size(arr, 1)
end

# Array and Timestep have different start periods but same step
function hasvalue(arr::TimestepArray{T, N, Start1, Step}, ts::Timestep{Start2, Step, Stop}) where {T, N, Start1, Start2, Step, Stop}
	return Start1 <= gettime(ts) <= end_period(arr)
end

# Array and Timestep different start periods, validating all dimensions
function hasvalue(arr::TimestepArray{T, N, Start1, Step}, 
				  ts::Timestep{Start2, Step, Stop}, 
				  idxs::Int...) where {T, N, Start1, Start2, Step, Stop}
	return Start1 <= gettime(ts) <= end_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end
