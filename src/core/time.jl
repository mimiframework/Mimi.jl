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
	return Timestep{new_start, Step, Stop}(Int64(ts.t + (Start - new_start) / Step))
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
# TBD: combine these to avoid some duplication?
#
import Base: getindex, setindex!, eltype, fill!, size, indices, endof

function get_timestep_instance(T, start, step, num_dims, value)
	if !(num_dims in (1, 2))
			error("TimeStepVector or TimestepMatrix support only 1 or 2 dimensions, not $num_dims")
	end

	timestep_type = num_dims == 1 ? TimestepVector : TimestepMatrix
	return timestep_type{T, start, step}(value)
end

#
# AbstractTimestepMatrix -- methods that apply to both matrix and vectors
#
function fill!(obj::AbstractTimestepMatrix, value)
	fill!(obj.data, value)
end

function size(obj::AbstractTimestepMatrix)
	return size(obj.data)
end

function size(obj::AbstractTimestepMatrix, i::Int)
	return size(obj.data, i)
end

function eltype(obj::AbstractTimestepMatrix)
	return eltype(obj.data)
end

const IntColonRange = Union{Int, Colon, OrdinalRange}

const ColonRange    = Union{Colon, OrdinalRange}

#
# TimestepVector
#
function getindex(x::TimestepVector{T, Start, Step}, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	return x.data[ts.t]
end

function getindex(x::TimestepVector{T, d_start, Step}, ts::Timestep{t_start, Step, Stop}) where {T, d_start, Step, t_start, Stop}
	t = Int64(ts.t + (t_start - d_start) / Step)
	return x.data[t]
end

# int indexing version for old style components
function getindex(x::TimestepVector{T, Start, Step}, i::Int) where {T, Start, Step}
   	return x.data[i]
end

# Handle expressions 1:end as 1:0 since the expression :(1:end) is difficult to manipulate
function getindex(x::TimestepVector{T, Start, Step}, rng::ColonRange) where {T, Start, Step}
	return rng.stop == 0 ? x.data[rng.start:end] : x.data[rng]
end

function indices(x::TimestepVector{T, Start, Step}) where {T, Start, Step}
	return (Start:Step:(Start + (length(x.data) - 1) * Step), )
end

function start_period(v::TimestepVector{T, Start, Step}) where {T, Start, Step}
	return Start
end

function setindex!(v::TimestepVector{T, Start, Step}, val, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	setindex!(v.data, val, ts.t)
end

function setindex!(v::TimestepVector{T, d_start, Step}, val, ts::Timestep{t_start, Step, Stop}) where {T, d_start, Step, t_start, Stop}
	t = Int64(ts.t + (t_start - d_start) / Step)
	setindex!(v.data, val, t)
end

function setindex!(v::TimestepVector{T, start, duration}, val, i::Int) where {T, start, duration}
	setindex!(v.data, val, i)
end

function setindex!(v::TimestepVector{T, start, duration}, val, rng::ColonRange) where {T, start, duration}
	if rng.stop == 0
		rng = rng.start:length(v.data)
	end

	setindex!(v.data, val, rng)
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

function endof(v::TimestepVector)
	return length(v.data)
end

#
# TimestepMatrix
#
function getindex(mat::TimestepMatrix{T, Start, Step}, ts::Timestep{Start, Step, Stop}, i::Int) where {T, Start, Step, Stop}
	return mat.data[ts.t, i]
end

function getindex(mat::TimestepMatrix{T, Start, Step}, ts::Timestep{Start, Step, Stop}, rng::ColonRange) where {T, Start, Step, Stop}
	return rng.stop == 0 ? mat.data[ts.t, rng.start:end] : mat.data[ts.t, rng]
end


function getindex(mat::TimestepMatrix{T, d_start, Step}, ts::Timestep{t_start, Step, Stop}, i::Int) where {T, d_start, Step, t_start, Stop}
	t = Int64(ts.t + (t_start - d_start) / Step)
	return mat.data[t, i]
end

function getindex(mat::TimestepMatrix{T, d_start, Step}, ts::Timestep{t_start, Step, Stop}, rng::ColonRange) where {T, d_start, Step, t_start, Stop}
	t = Int64(ts.t + (t_start - d_start) / Step)
	return rng.stop == 0 ? mat.data[t, rng.start:end] : mat.data[ts.t, rng]
end

# int indexing version supports old style components
function getindex(mat::TimestepMatrix{T, Start, Step}, dim1::IntColonRange, dim2::IntColonRange) where {T, Start, Step}
	data = mat.data
	if isa(dim1, Range) && dim1.stop == 0
		dim1 = dim1.start:size(data, 1)
	end

	if isa(dim2, Range) && dim2.stop == 0
		dim2 = dim2.start:size(data, 2)
	end

	return data[dim1, dim2]
end

function setindex!(mat::TimestepMatrix{T, Start, Step}, val, ts::Timestep{Start, Step, Stop}, dim::IntColonRange) where {T, Start, Step, Stop}
	if isa(dim, Range) && dim1.stop == 0
		dim = dim.start:size(mat.data, 2)
	end
	setindex!(mat.data, val, ts.t, dim)
end

function setindex!(mat::TimestepMatrix{T, d_start, Step}, val, ts::Timestep{t_start, Step, Stop}, dim::IntColonRange) where {T, d_start, Step, t_start, Stop}
	if isa(dim, Range) && dim1.stop == 0
		dim = dim.start:size(mat.data, 2)
	end
	
	t = Int64(ts.t + (t_start - d_start) / Step)
	setindex!(mat.data, val, t, dim)
end

function setindex!(mat::TimestepMatrix{T, Start, Step}, val, dim1::IntColonRange, dim2::IntColonRange) where {T, Start, Step}
	data = mat.data
	if isa(dim1, Range) && dim1.stop == 0
		dim1 = dim1.start:size(data, 1)
	end

	if isa(dim2, Range) && dim2.stop == 0
		dim2 = dim2.start:size(data, 2)
	end	

	setindex!(data, val, dim1, dim2)
end

function indices(mat::TimestepMatrix{T, Start, Step}) where {T, Start, Step}
	return (Start:Step:(Start + (size(mat.data, 1) - 1) * Step), 1:size(mat.data, 2))
end

function start_period(mat::TimestepMatrix{T, Start, Step}) where {T, Start, Step}
	return Start
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
