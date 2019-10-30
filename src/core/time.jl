#
#  TIMESTEP
#

"""
	gettime(ts::FixedTimestep)

Return the time (year) represented by Timestep `ts` 
"""
function gettime(ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	return FIRST + (ts.t - 1) * STEP
end

"""
	gettime(ts::VariableTimestep)

Return the time (year) represented by Timestep `ts` 
"""
function gettime(ts::VariableTimestep)
	return ts.current
end

"""
	is_time(ts::AbstractTimestep, t::Int)

Return true or false, true if the current time (year) for `ts` is `t`
"""
function is_time(ts::AbstractTimestep, t::Int) 
	return gettime(ts) == t
end

"""
	is_first(ts::AbstractTimestep)

Return true or false, true if `ts` is the first timestep to be run.
"""
function is_first(ts::AbstractTimestep)
	return ts.t == 1
end

"""
	is_timestep(ts::AbstractTimestep, t::Int)

Return true or false, true if `ts` timestep is step `t`.
"""
function is_timestep(ts::AbstractTimestep, t::Int)
	return ts.t == t
end

"""
	is_last(ts::FixedTimestep)

Return true or false, true if `ts` is the last timestep to be run.
"""
function is_last(ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	return gettime(ts) == LAST
end

"""
	is_last(ts::VariableTimestep)

Return true or false, true if `ts` is the last timestep to be run.  Note that you may
run `next_timestep` on `ts`, as ths final timestep has not been run through yet.
"""
function is_last(ts::VariableTimestep{TIMES}) where {TIMES}
	return gettime(ts) == TIMES[end]
end

function finished(ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	return gettime(ts) > LAST
end

function finished(ts::VariableTimestep{TIMES}) where {TIMES}
	return gettime(ts) > TIMES[end]
end

function next_timestep(ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	end
	return FixedTimestep{FIRST, STEP, LAST}(ts.t + 1)
end

function next_timestep(ts::VariableTimestep{TIMES}) where {TIMES}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	end
	return VariableTimestep{TIMES}(ts.t + 1)		
end

function Base.:-(ts::FixedTimestep{FIRST, STEP, LAST}, val::Int) where {FIRST, STEP, LAST}
	if val != 0 && is_first(ts)
		error("Cannot get previous timestep, this is first timestep.")
	elseif ts.t - val <= 0
		error("Cannot get requested timestep, precedes first timestep.")		
	end
	return FixedTimestep{FIRST, STEP, LAST}(ts.t - val)
end

function Base.:-(ts::VariableTimestep{TIMES}, val::Int) where {TIMES}
	if val != 0 && is_first(ts)
		error("Cannot get previous timestep, this is first timestep.")
	elseif ts.t - val <= 0
		error("Cannot get requested timestep, precedes first timestep.")		
	end
	return VariableTimestep{TIMES}(ts.t - val)
end

function Base.:-(ts::TimestepValue, val::Int) 
	return TimestepValue(ts.value; offset = ts.offset - val)
end

function Base.:-(ts::TimestepIndex, val::Int) 
	return TimestepIndex(ts.index - val)
end

function Base.:+(ts::FixedTimestep{FIRST, STEP, LAST}, val::Int) where {FIRST, STEP, LAST}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	elseif gettime(ts) + val > LAST + 1
		error("Cannot get requested timestep, exceeds last timestep.")		
	end
	return FixedTimestep{FIRST, STEP, LAST}(ts.t + val)
end

function Base.:+(ts::VariableTimestep{TIMES}, val::Int) where {TIMES}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	elseif gettime(ts) + val > TIMES[end] + 1
		error("Cannot get requested timestep, exceeds last timestep.")		
	end
	new_ts = VariableTimestep{TIMES}(ts.t + val)
end

function Base.:+(ts::TimestepValue, val::Int) 
	return TimestepValue(ts.value; offset = ts.offset + val)
end

function Base.:+(ts::TimestepIndex, val::Int) 
	return TimestepIndex(ts.index + val)
end

# Colon support
function Base.:(:)(start::T, step::T, stop::T) where {T<:TimestepIndex}
	indices = [start.index:step.index:stop.index...]
	return TimestepIndex.(indices)
end

function Base.:(:)(start::T, step::Int, stop::T) where {T<:TimestepIndex}
	indices = [start.index:step:stop.index...]
	return TimestepIndex.(indices)
end

function Base.:(:)(start::T, stop::T) where {T<:TimestepIndex} 
	return Base.:(:)(start, 1, stop)
end

#
#  CLOCK
#

function Clock(time_keys::Vector{Int})
    last = time_keys[end]

    if isuniform(time_keys)
        first, stepsize = first_and_step(time_keys)
        return Clock{FixedTimestep}(first, stepsize, last)
    else
        last_index = findfirst(isequal(last), time_keys)
        times = (time_keys[1:last_index]...,)
        return Clock{VariableTimestep}(times)
    end
end

function timestep(c::Clock)
	return c.ts
end

function time_index(c::Clock)
	return c.ts.t
end

"""
	gettime(c::Clock)

Return the current time of the timestep held by the `c` clock.
"""
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

function Base.reset(c::Clock)
	c.ts = c.ts - (c.ts.t - 1)
	nothing
end
