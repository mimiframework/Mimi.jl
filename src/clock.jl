type Clock
	t::Int
	final_t::Int
end

function gettimestep(c::Clock)
	return c.t
end

function move_forward(c::Clock)
	c.t = c.t + 1
	nothing
end

function finished(c::Clock)
	if c.t>c.final_t
		return true
	else
		return false
	end
end
