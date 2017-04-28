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
