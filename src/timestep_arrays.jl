################
#  TimestepVector  #
################

type TimestepVector{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 1 for the vector case
	data::Array{T, 1}
	function TimestepVector(d::Array{T, 1})
		v = new()
		v.data = d
		return v
	end
	function TimestepVector(i::Int)
		v = new()
		v.data = Array{T,1}(i)
		return v
	end
end

function Base.getindex{T, Offset, Duration, Final}(x::TimestepVector{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final})
	return x.data[ts.t]
end

function Base.getindex{T, d_offset, Duration, t_offset, Final}(x::TimestepVector{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final})
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	return x.data[t]
end

# int indexing version for old style components
function Base.getindex{T, Offset, Duration, OT1<:Union{Int, Colon, OrdinalRange}}(x::TimestepVector{T, Offset, Duration}, i::OT1)
	return x.data[i]
end

function Base.indices{T, Offset, Duration}(x::TimestepVector{T, Offset, Duration})
	return (Offset:Duration:(Offset + (length(x.data)-1)*Duration), )
end

function getoffset{T, Offset, Duration}(v::TimestepVector{T, Offset, Duration})
	return Offset
end

function Base.eltype(v::TimestepVector)
	return eltype(v.data)
end

function Base.fill!(v::TimestepVector, x)
	fill!(v.data, x)
end

function Base.setindex!{T, Offset, Duration, Final}(v::TimestepVector{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final})
	setindex!(v.data, a, ts.t)
end

function Base.setindex!{T, d_offset, Duration, t_offset, Final}(v::TimestepVector{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final})
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	setindex!(v.data, a, t)
end

function Base.setindex!{T, offset, duration, OT<:Union{Int, Colon, OrdinalRange}}(v::TimestepVector{T, offset, duration}, a, i::OT)
	setindex!(v.data, a, i)
end

function Base.size(v::TimestepVector)
	return size(v.data)
end

function Base.size(v::TimestepVector, i::Int)
	return size(v.data, i)
end

# method where the vector and the timestep have the same offset
function hasvalue{T, Offset, Duration, Final}(v::TimestepVector{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final})
	return ts.t >= 1 && ts.t <= size(v, 1)
end

# method where they have different offsets
function hasvalue{T, Offset1, Offset2, Duration, Final}(v::TimestepVector{T, Offset1, Duration}, ts::Timestep{Offset2, Duration, Final})
	t = gettime(ts)
	return t >= Offset1 && t <= (Offset1 + (size(v, 1) - 1) * Duration)
end

function Base.endof(v::TimestepVector)
	return length(v.data)
end

################
#  TimestepMatrix  #
################

type TimestepMatrix{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 2 for the matrix case
	data::Array{T, 2}
	function TimestepMatrix(d::Array{T, 2})
		m = new()
		m.data = d
		return m
	end
	function TimestepMatrix(i::Int, j::Int)
		m = new()
		m.data = Array{T,2}(i, j)
		return m
	end
end

function Base.getindex{T, Offset, Duration, Final, OT1<:Union{Int, Colon, OrdinalRange}}(x::TimestepMatrix{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}, i::OT1)
	return x.data[ts.t, i]
end

function Base.getindex{T, d_offset, Duration, t_offset, Final, OT1<:Union{Int, Colon, OrdinalRange}}(x::TimestepMatrix{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final}, i::OT1)
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	return x.data[t, i]
end

# int indexing version for old style components
function Base.getindex{T, Offset, Duration, OT1<:Union{Int, Colon, OrdinalRange}, OT2<:Union{Int, Colon, OrdinalRange}}(x::TimestepMatrix{T, Offset, Duration}, t::OT1, i::OT2)
	return x.data[t, i]
end

function Base.setindex!{T, Offset, Duration, Final, OT1<:Union{Int, Colon, OrdinalRange}}(m::TimestepMatrix{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final}, j::OT1)
	setindex!(m.data, a, ts.t, j)
end

function Base.setindex!{T, d_offset, Duration, t_offset, Final, OT1<:Union{Int, Colon, OrdinalRange}}(m::TimestepMatrix{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final}, j::OT1)
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	setindex!(m.data, a, t, j)
end

function Base.setindex!{T, offset, duration, OT1<:Union{Int, Colon, OrdinalRange}, OT2<:Union{Int, Colon, OrdinalRange}}(m::TimestepMatrix{T, offset, duration}, a, i::OT1, j::OT2)
	setindex!(m.data, a, i, j)
end

function Base.indices{T, Offset, Duration}(x::TimestepMatrix{T, Offset, Duration})
	return (Offset:Duration:(Offset+(size(x.data)[1]-1)*Duration), 1:size(x.data)[2])
end

function getoffset{T, Offset, Duration}(v::TimestepMatrix{T, Offset, Duration})
	return Offset
end

function Base.eltype(v::TimestepMatrix)
	return eltype(v.data)
end

function Base.fill!(m::TimestepMatrix, x)
	fill!(m.data, x)
end

function Base.size(m::TimestepMatrix)
	return size(m.data)
end

function Base.size(m::TimestepMatrix, i::Int)
	return size(m.data, i)
end

# method where the vector and the timestep have the same offset
function hasvalue{T, Offset, Duration, Final}(m::TimestepMatrix{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}, j::Int)
	return ts.t >= 1 && ts.t <= size(m, 1) && j>=1 && j<= size(m, 2)
end

# method where they have different offsets
function hasvalue{T, Offset1, Offset2, Duration, Final}(m::TimestepMatrix{T, Offset1, Duration}, ts::Timestep{Offset2, Duration, Final}, j::Int)
	t = gettime(ts)
	return t >= Offset1 && t <= (Offset1 + (size(m, 1) - 1) * Duration) && j>=1 && j<= size(m, 2)
end
