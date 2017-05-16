using OffsetArrays

immutable Timestep{Offset, Duration, Final}
	t::Int

	function Timestep(year::Int)
		ts = new{Offset, Duration, Final}(Int64((year - Offset)/Duration + 1))
		return ts
	end

end

type Clock
	ts::Timestep

	function Clock(offset::Int, final::Int, duration::Int)
		clk = new()
		clk.ts = Timestep{offset, duration, final}(offset)
		return clk
	end
end

function gettimestep(c::Clock)
	return c.ts
end

function gettimeindex(c::Clock)
	return c.ts.t
end

function move_forward(c::Clock)
	c.ts = getnexttimestep(c.ts)
	nothing
end

function finished(c::Clock)
	return ispastfinaltimestep(c.ts)
end

function isfirsttimestep(ts::Timestep)
	return ts.t == 1
end

function isfinaltimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) == Final
end

function ispastfinaltimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) > Final
end

function getnexttimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	if ispastfinaltimestep(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Offset, Duration, Final}(Offset + ts.t*Duration)
end

function getnewtimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final}, newoffset::Int)
	return Timestep{newoffset, Duration, Final}(gettime(ts))
end

function gettime{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return Offset + (ts.t - 1) * Duration
end

################
#  OurTVector  #
################

type OurTVector{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 1 for the vector case
	data::Array{T, 1}

	# data::OffsetArray{T, 1, Array{T, 1}}
	#
	# function OurTVector(data::Array{T,1})
	# 	d = OffsetArray(data, Offset:(Offset+length(data)-1))
	# 	x = new{T, Offset}(d)
	# 	return x
	# end
end

function Base.getindex{T, d_offset, d_duration, t_offset, t_duration, Final}(x::OurTVector{T, d_offset, d_duration}, ts::Timestep{t_offset, t_duration, Final})
	if d_offset==t_offset && d_duration==t_duration
		t = ts.t
	else
		time = gettime(ts)
		t = Int64((time - d_offset)/d_duration + 1)
	end
	return x.data[t]
end

function Base.indices{T, Offset, Duration}(x::OurTVector{T, Offset, Duration})
	return (Offset:Duration:(Offset + (length(x.data)-1)*Duration), )
end

function Base.linearindices{T, Offset, Duration}(x::OurTVector{T, Offset, Duration})
	return linearindices(x.data)
end

################
#  OurTMatrix  #
################

type OurTMatrix{T, Offset, Duration} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 2 for the matrix case
	data::Array{T, 2}

	# data::OffsetArray{T, 2, Array{T, 2}}

	# function OurTMatrix(data::Array{T,2})
	# 	d = OffsetArray(data, Offset:(Offset+size(data)[1]-1), 1:size(data)[2])
	# 	x = new{T, Offset, Duration}(d)
	# 	return x
	# end
end

function Base.getindex{T, d_offset, d_duration, t_offset, t_duration, Final}(x::OurTMatrix{T, d_offset, d_duration}, ts::Timestep{t_offset, t_duration, Final}, i::Int)
	if d_offset==t_offset && d_duration==t_duration
		t = ts.t
	else
		time = gettime(ts)
		t = Int64((time - d_offset)/d_duration + 1)
	end
	return x.data[t, i]
end

function Base.indices{T, Offset, Duration}(x::OurTMatrix{T, Offset, Duration})
	return (Offset:Duration:(Offset+(size(x.data)[1]-1)*Duration), 1:size(x.data)[2])
end

function Base.linearindices{T, Offset, Duration}(x::OurTMatrix{T, Offset, Duration})
	return linearindices(x.data)
end
