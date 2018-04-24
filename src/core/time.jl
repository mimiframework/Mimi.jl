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

#
# AbstractTimestepMatrix -- methods that apply to both matrix and vector variants
#
function Base.fill!(obj::AbstractTimestepMatrix, value)
	fill!(obj.data, value)
end

function Base.size(obj::AbstractTimestepMatrix)
	return size(obj.data)
end

function Base.size(obj::AbstractTimestepMatrix, i::Int)
	return size(obj.data, i)
end

function Base.eltype(obj::AbstractTimestepMatrix)
	return eltype(obj.data)
end

function start_period(v::AbstractTimestepMatrix{T, Start, Step}) where {T, Start, Step}
	return Start
end

const AnyIndex = Union{Int, Vector{Int}, Tuple, Colon, OrdinalRange}

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

# method where the vector and the timestep have the same start period
function hasvalue(v::TimestepVector{T, Start, Step}, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	return 1 <= ts.t <= size(v, 1)
end

# method where they have different start periods
function hasvalue(v::TimestepVector{T, Start1, Step}, ts::Timestep{Start2, Step, Stop}) where {T, Start1, Start2, Step, Stop}
	t = gettime(ts)
	return Start1 <= t <= (Start1 + (size(v, 1) - 1) * Step)
end

function Base.endof(v::TimestepVector)
	return length(v.data)
end

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

function Base.indices(mat::TimestepMatrix{T, Start, Step}) where {T, Start, Step}
	return (Start:Step:(Start + (size(mat.data, 1) - 1) * Step), 1:size(mat.data, 2))
end

# method where the vector and the timestep have the same start period
function hasvalue(mat::TimestepMatrix{T, Start, Step}, ts::Timestep{Start, Step, Stop}, j::Int) where {T, Start, Step, Stop}
	return 1 <= ts.t <= size(mat, 1) && 1 <= j <= size(mat, 2)
end

# method where they have different start periods
function hasvalue(mat::TimestepMatrix{T, Start1, Step}, ts::Timestep{Start2, Step, Stop}, j::Int) where {T, Start1, Start2, Step, Stop}
	t = gettime(ts)
	return Start1 <= t <= (Start1 + (size(mat, 1) - 1) * Step) && 1 <= j <= size(mat, 2)
end
