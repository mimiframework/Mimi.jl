################
#  OurTVector  #
################

type OurTVector{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 1 for the vector case
	data::Array{T, 1}
	function OurTVector(d::Array{T, 1})
		v = new()
		v.data = d
		return v
	end
	function OurTVector(i::Int)
		v = new()
		v.data = Array{T,1}(i)
		return v
	end
end

function Base.getindex{T, Offset, Duration, Final}(x::OurTVector{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final})
	return x.data[ts.t]
end

function Base.getindex{T, d_offset, Duration, t_offset, Final}(x::OurTVector{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final})
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	return x.data[t]
end

# int indexing version for old style components
function Base.getindex{T, Offset, Duration, OT1<:Union{Int, Colon, OrdinalRange}}(x::OurTVector{T, Offset, Duration}, i::OT1)
	return x.data[i]
end

function Base.indices{T, Offset, Duration}(x::OurTVector{T, Offset, Duration})
	return (Offset:Duration:(Offset + (length(x.data)-1)*Duration), )
end

function getoffset{T, Offset, Duration}(v::OurTVector{T, Offset, Duration})
	return Offset
end

function Base.eltype(v::OurTVector)
	return eltype(v.data)
end

function Base.fill!(v::OurTVector, x)
	fill!(v.data, x)
end

function Base.setindex!{T, Offset, Duration, Final}(v::OurTVector{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final})
	setindex!(v.data, a, ts.t)
end

function Base.setindex!{T, d_offset, Duration, t_offset, Final}(v::OurTVector{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final})
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	setindex!(v.data, a, t)
end

function Base.setindex!{T, offset, duration}(v::OurTVector{T, offset, duration}, a, i::Int)
	setindex!(v.data, a, i)
end

function Base.size(v::OurTVector)
	return size(v.data)
end

function Base.size(v::OurTVector, i::Int)
	return size(v.data, i)
end

################
#  OurTMatrix  #
################

type OurTMatrix{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 2 for the matrix case
	data::Array{T, 2}
	function OurTMatrix(d::Array{T, 2})
		m = new()
		m.data = d
		return m
	end
	function OurTMatrix(i::Int, j::Int)
		m = new()
		m.data = Array{T,2}(i, j)
		return m
	end
end

function Base.getindex{T, Offset, Duration, Final, OT1<:Union{Int, Colon, OrdinalRange}}(x::OurTMatrix{T, Offset, Duration}, ts::Timestep{Offset, Duration, Final}, i::OT1)
	return x.data[ts.t, i]
end

function Base.getindex{T, d_offset, Duration, t_offset, Final, OT1<:Union{Int, Colon, OrdinalRange}}(x::OurTMatrix{T, d_offset, Duration}, ts::Timestep{t_offset, Duration, Final}, i::OT1)
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	return x.data[t, i]
end

# int indexing version for old style components
function Base.getindex{T, Offset, Duration, OT1<:Union{Int, Colon, OrdinalRange}, OT2<:Union{Int, Colon, OrdinalRange}}(x::OurTMatrix{T, Offset, Duration}, t::OT1, i::OT2)
	return x.data[t, i]
end

function Base.setindex!{T, Offset, Duration, Final}(m::OurTMatrix{T, Offset, Duration}, a, ts::Timestep{Offset, Duration, Final}, j::Int)
	setindex!(m.data, a, ts.t, j)
end

function Base.setindex!{T, d_offset, Duration, t_offset, Final}(m::OurTMatrix{T, d_offset, Duration}, a, ts::Timestep{t_offset, Duration, Final}, j::Int)
	t = Int64(ts.t + (t_offset - d_offset)/Duration)
	setindex!(m.data, a, t, j)
end

function Base.setindex!{T, offset, duration}(m::OurTMatrix{T, offset, duration}, a, i::Int, j::Int)
	setindex!(m.data, a, i, j)
end

function Base.indices{T, Offset, Duration}(x::OurTMatrix{T, Offset, Duration})
	return (Offset:Duration:(Offset+(size(x.data)[1]-1)*Duration), 1:size(x.data)[2])
end

function getoffset{T, Offset, Duration}(v::OurTMatrix{T, Offset, Duration})
	return Offset
end

function Base.eltype(v::OurTMatrix)
	return eltype(v.data)
end

function Base.fill!(m::OurTMatrix, x)
	fill!(m.data, x)
end

function Base.size(m::OurTMatrix)
	return size(m.data)
end

function Base.size(m::OurTMatrix, i::Int)
	return size(m.data, i)
end
