## DEFS

function isuniform(values::Vector)
    num_values = length(values)

    if num_values == 0
        return -1
    end

    if num_values == 1
        return 1
    end

    stepsize = values[2] - values[1]
    
    if num_values == 2
        return stepsize
    end

    for i in 3:length(values)
        if (values[i] - values[i - 1]) != stepsize
            return -1
        end
    end

    return stepsize
end


## TYPES

abstract type AbstractTimestep end

struct Timestep{Start, Step, Stop} <: AbstractTimestep
    t::Int
end

struct VariableTimestep{Years} <: AbstractTimestep
    t::Int
    current::Int 

    function VariableTimestep{Years}(t::Int = 1) where {Years}
        # The special case below handles when functions like next_step step beyond
        # the end of the Years array.  The assumption is that the length of this
        # last timestep, starting at Years[end], is 1.
        current::Int = t > length(Years) ? Years[end] + 1 : Years[t]
        
        return new(t, current)
    end
end

mutable struct Clock{T <: AbstractTimestep}
	ts::T

	function Clock{T}(start::Int, step::Int, stop::Int) where T
		return new(Timestep{start, step, stop}(1))
    end
    
    function Clock{T}(years::NTuple{N, Int} where N) where T
        return new(VariableTimestep{years}(1, years[1]))
    end
end

mutable struct TimestepArray{T_ts <: AbstractTimestep, T, N}
	data::Array{T, N}

    function TimestepArray{T_ts, T, N}(d::Array{T, N}) where {T_ts, T, N}
		return new(d)
	end

    function TimestepArray{T_ts, T, N}(lengths::Int...) where {T_ts, T, N}
		return new(Array{T, N}(lengths...))
	end
end

# Since these are the most common cases, we define methods (in time.jl)
# specific to these type aliases, avoiding some of the inefficiencies
# associated with an arbitrary number of dimensions.
const TimestepMatrix{T_ts, T} = TimestepArray{T_ts, T, 2}
const TimestepVector{T_ts, T} = TimestepArray{T_ts, T, 1}

## TIME

#
#  1. TIMESTEP
#

function gettime(ts::Timestep{Start, Step, Stop}) where {Start, Step, Stop}
	return Start + (ts.t - 1) * Step
end

function gettime(ts::VariableTimestep)
	return ts.current
end

function is_start(ts::AbstractTimestep)
	return ts.t == 1
end

# NOTE:  is_stop function is not used internally, so we may want to deprecate it ... 
# look into where it might be used within models?
function is_stop(ts::Timestep{Start, Step, Stop}) where {Start, Step, Stop}
	return gettime(ts) == Stop
end

function is_stop(ts::VariableTimestep{Years}) where {Years}
	return gettime(ts) == Years[end]
end

function finished(ts::Timestep{Start, Step, Stop}) where {Start, Step, Stop}
	return gettime(ts) > Stop
end

function finished(ts::VariableTimestep{Years}) where {Years}
	return gettime(ts) > Years[end]
end

function next_timestep(ts::Timestep{Start, Step, Stop}) where {Start, Step, Stop}
	if finished(ts)
			error("Cannot get next timestep, this is final timestep.")
	end
	return Timestep{Start, Step, Stop}(ts.t + 1)
end

function next_timestep(ts::VariableTimestep{Years}) where {Years}
	if finished(ts)
		error("Cannot get next timestep, this is final timestep.")
	end
	return VariableTimestep{Years}(ts.t + 1)		
end

# NOTE:  This funcion is not used internally, and the arithmetic is possible wrong.  
# function new_timestep(ts::Timestep{Start, Step, Stop}, new_start::Int) where {Start, Step, Stop}
# 	return Timestep{new_start, Step, Stop}(Int(ts.t + (Start - new_start) / Step))
# end

#
#  2. CLOCK
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
	return finished(c.ts)
end

#
# 3.  TimestepVector and TimestepMatrix
#

#
# 3a.  General
#

function get_timestep_instance(T, years, num_dims, value)
	if !(num_dims in (1, 2))
		error("TimeStepVector or TimestepMatrix support only 1 or 2 dimensions, not $num_dims")
	end

	timestep_array_type = num_dims == 1 ? TimestepVector : TimestepMatrix
	timestep_type = isuniform(collect(years)) == -1 ? VariableTimestep : Timestep

	return timestep_array_type{timestep_type, T}(value)
end

const AnyIndex = Union{Int, Vector{Int}, Tuple, Colon, OrdinalRange}

# TBD: can it be reduced to this?
# const AnyIndex = Union{Int, Range}

#
# 3b. TimestepVector
#

function Base.getindex(v::TimestepVector{Timestep{Start1, Step1, Stop1} where {Start1, Step1, Stop1}, T}, ts::Timestep{Start, Step, Stop}) where {T, Start, Step, Stop}
	return v.data[ts.t]
end


## TEST 
using Base.Test

a = collect(reshape(1:16,4,4))
years = (collect(2000:1:2003)...)
x = TimestepVector{Timestep, Int}(a[:,3])
i = get_timestep_instance(Int, years, 1, a[:,3])

t = Timestep{2001, 1, 3000}(1)
@test x[t] == 10
t2= Timestep{2000, 1, 2003}(1)
@test x[t2] == 9

