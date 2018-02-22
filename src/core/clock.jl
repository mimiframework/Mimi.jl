#
#  TIMESTEP
#
function gettime{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return Offset + (ts.t - 1) * Duration
end

function is_first_timestep(ts::Timestep)
	return ts.t == 1
end

# for users to tell when they are on the final timestep
function is_final_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) == Final
end

# used to determine when a clock is finished
function past_final_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	return gettime(ts) > Final
end

function next_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final})
	if past_final_timestep(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Offset, Duration, Final}(ts.t + 1)
end

function new_timestep{Offset, Duration, Final}(ts::Timestep{Offset, Duration, Final}, newoffset::Int)
	return Timestep{newoffset, Duration, Final}(Int64(ts.t + (Offset-newoffset)/Duration))
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
	return past_final_timestep(c.ts)
end
