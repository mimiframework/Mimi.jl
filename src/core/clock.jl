#
#  TIMESTEP
#
function isfirsttimestep(ts::Timestep)
	return ts.t == 1
end

# for users to tell when they are on the final timestep
function isfinaltimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) == Final
end

# used to determine when a clock is finished
function ispastfinaltimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) > Final
end

function getnexttimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	if ispastfinaltimestep(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Offset, Duration, Final}(ts.t + 1)
end

function getnewtimestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final}, newoffset::Int)
	return Timestep{newoffset, Duration, Final}(Int64(ts.t + (Offset-newoffset)/Duration))
end

function gettime{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return Offset + (ts.t - 1) * Duration
end

#
#  CLOCK
#
function gettimestep(c::Clock)
	return c.ts
end

function gettimeindex(c::Clock)
	return c.ts.t
end

function gettime(c::Clock)
	return gettime(c.ts)
end

function move_forward(c::Clock)
	c.ts = getnexttimestep(c.ts)
	nothing
end

function finished(c::Clock)
	return ispastfinaltimestep(c.ts)
end
