using OffsetArrays

immutable Timestep{Offset, Final}
	t::Int

	function Timestep(i::Int)
		ts = new{Offset, Final}(i - Offset + 1)
		return ts
	end

end

type Clock
	ts::Timestep

	function Clock(offset::Int, final::Int)
		clk = new()
		clk.ts = Timestep{offset, final}(offset)
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

function isfinaltimestep{Offset, Final}(ts::Timestep{Offset, Final})
	return ts.t == Final - Offset + 1
end

function ispastfinaltimestep{Offset, Final}(ts::Timestep{Offset, Final})
	return ts.t > Final - Offset + 1
end

function getnexttimestep{Offset, Final}(ts::Timestep{Offset, Final})
	if ispastfinaltimestep(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Offset, Final}(ts.t + Offset)
end

function getnewtimestep{Offset, Final}(ts::Timestep{Offset, Final}, newoffset::Int)
	return Timestep{newoffset, Final}(ts.t + Offset - 1 )
end

function getobjectivetime{Offset, Final}(ts::Timestep{Offset, Final})
	return ts.t + Offset - 1
end

type OurTVector{T, Offset} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 1 for the vector case
	data::OffsetArray{T, 1, Array{T, 1}}

	function OurTVector(data::Array{T,1})
		d = OffsetArray(data, Offset:(Offset+length(data)-1))
		x = new{T, Offset}(d)
		return x
	end
end

type OurTMatrix{T, Offset} #don't need to encode N (number of dimensions) as a type parameter because we are hardcoding it as 2 for the matrix case
	data::OffsetArray{T, 2, Array{T, 2}}

	function OurTMatrix(data::Array{T,2})
		d = OffsetArray(data, Offset:(Offset+size(data)[1]-1), 1:size(data)[2])
		x = new{T, Offset}(d)
		return x
	end
end

function Base.getindex{T, d_offset, t_offset, Final}(x::OurTVector{T, d_offset}, ts::Timestep{t_offset, Final})
	t = getobjectivetime(ts)
	return x.data[t]
end

function Base.getindex{T, d_offset, t_offset, Final}(x::OurTMatrix{T, d_offset}, ts::Timestep{t_offset, Final}, i::Int)
	t = getobjectivetime(ts)
	return x.data[t, i]
end
