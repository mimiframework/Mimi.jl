type Timestep{Offset, Final}
	t::Int
	final::Int

	function Timestep(i::Int)
		ts = new{Offset, Final}()
		ts.t = i - Offset + 1
		ts.final = Final - Offset + 1
		return ts
	end

	function Timestep()
		ts = new{Offset, Final}()
		ts.t = 1
		ts.final = Final - Offset + 1
		return ts
	end

end

type Clock
	ts::Timestep

	function Clock(final::int)
		ts = Timestep{1, final}(1)
	end

	function Clock(offset::int, final::int)
		ts = Timestep{offset, final}(offset)
	end
end

function getoffset(ts::Timestep)
	return ??
end

function getoffset(mi::ModelInstance, c::ComponentState)
	return mi.offsets[c.name] #??
end

function getfinaltimestep(mi::ModelInstance, c::ComponentState)
	return ??
end

function gettimestep(c::Clock)
	return c.ts
end

function gettimeindex(c::Clock)
	return c.ts.t
end

function gettimestep(mi::ModelInstance, c::ComponentState, clk::Clock)
	c_offset = getoffset(mi, c)
	c_final = getfinaltimestep(mi, c)
	clk_offset = getoffset(clk.ts)
	i = clk_offset + clk.t
	return Timestep{c_offset, c_final}(i)
end

function move_forward(c::Clock)
	c.ts = c.ts.getnexttimestep()
	nothing
end

function finished(c::Clock)
	return isfinaltimestep(c.ts)
end

function isfirsttimestep(ts::Timestep)
	return ts.t == 1
end

function isfinaltimstep(ts::Timestep)
	return ts.t == ts.final_t
end

function getnexttimestep(ts::Timestep)
	next = typeof(ts)()
	next.t = ts.t + 1
	return next
end
