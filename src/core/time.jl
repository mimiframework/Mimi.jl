#
#  1. TIMESTEP
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
	is_first(ts::AbstractTimestep)

Return true or false, true if `ts` is the first timestep to be run.
"""
function is_first(ts::AbstractTimestep)
	return ts.t == 1
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
	if is_first(ts)
		error("Cannot get previous timestep, this is first timestep.")
	elseif ts.t - val < 0
		error("Cannot get requested timestep, preceeds first timestep.")		
	end
	return FixedTimestep{FIRST, STEP, LAST}(ts.t - 1)
end

function Base.:-(ts::VariableTimestep{TIMES}, val::Int) where {TIMES}
	if is_first(ts)
		error("Cannot get previous timestep, this is first timestep.")
	elseif ts.t - val < 0
		error("Cannot get requested timestep, preceeds first timestep.")		
	end
	return VariableTimestep{TIMES}(ts.t - 1)
end

function Base.:+(ts::FixedTimestep{FIRST, STEP, LAST}, val::Int) where {FIRST, STEP, LAST}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	elseif gettime(ts) + val > LAST + 1
		error("Cannot get requested timestep, exceeds last timestep.")		
	end
	new_ts = FixedTimestep{FIRST, STEP, LAST}(ts.t + val)

end

function Base.:+(ts::VariableTimestep{TIMES}, val::Int) where {TIMES}
	if finished(ts)
		error("Cannot get next timestep, this is last timestep.")
	elseif gettime(ts) + val > TIMES[end] + 1
		error("Cannot get requested timestep, exceeds last timestep.")		
	end
	new_ts = VariableTimestep{TIMES}(ts.t + val)
end

# TBD:  This funcion is not used internally, and the arithmetic is possible wrong.  
# function new_timestep(ts::Timestep{Start, Step, Stop}, new_start::Int) where {Start, Step, Stop}
# 	return Timestep{new_start, Step, Stop}(Int(ts.t + (Start - new_start) / Step))
# end

#
#  2. CLOCK
#

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

#
# 3.  TimestepVector and TimestepMatrix
#

#
# 3a.  General
#

function get_timestep_instance(md::ModelDef, T, num_dims, value)
	if !(num_dims in (1, 2))
		error("TimeStepVector or TimestepMatrix support only 1 or 2 dimensions, not $num_dims")
	end

	timestep_array_type = num_dims == 1 ? TimestepVector : TimestepMatrix

	if isuniform(md)
		first, stepsize = first_and_step(md)
		return timestep_array_type{FixedTimestep{first, stepsize}, T}(value)
	else

		times = time_labels(md)		
		return timestep_array_type{VariableTimestep{(times...)}, T}(value)	

	end
end

const AnyIndex = Union{Int, Vector{Int}, Tuple, Colon, OrdinalRange}

# TBD: can it be reduced to this?
# const AnyIndex = Union{Int, Range}

#
# 3b. TimestepVector
#

#   Note:  commented out the general case for setindex!, getindex,and hasvalue 
#   which could replace the two specific cases for Variable and Fixed timesteps 
#   in the matching years subcase.  Need to think through the potential cases and
#   consequences before doing this replacement. 

# function Base.getindex(v::TimestepVector, ts::T) where {T <: AbstractTimestep}
# 	return v.data[ts.t]
# end

function Base.getindex(v::TimestepVector{FixedTimestep{FIRST, STEP}, T}, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, FIRST, STEP, LAST} 
	return v.data[ts.t]
end

function Base.getindex(v::TimestepVector{VariableTimestep{TIMES}, T}, ts::VariableTimestep{TIMES}) where {T, TIMES}
	return v.data[ts.t]
end

function Base.getindex(v::TimestepVector{FixedTimestep{D_FIRST, STEP}, T}, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, D_FIRST, T_FIRST, STEP, LAST} 
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	return v.data[t]
end

function Base.getindex(v::TimestepVector{VariableTimestep{D_FIRST}, T}, ts::VariableTimestep{T_FIRST}) where {T, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1
	return v.data[t]
end

# int indexing version supports old style components 
# function Base.getindex(v::TimestepVector, i::AnyIndex)
# 	return v.data[i]
# end

function Base.getindex(v::TimestepVector{FixedTimestep{FIRST, STEP}, T}, i::AnyIndex) where {T, FIRST, STEP}
	return v.data[i]
end

function Base.getindex(v::TimestepVector{VariableTimestep{TIMES}, T}, i::AnyIndex) where {T, TIMES}
	return v.data[i]
end

# function Base.setindex!(v::TimestepVector, val, ts::T) where {T <: AbstractTimestep}
# 	setindex!(v.data, val, ts.t)
# end

function Base.setindex!(v::TimestepVector{FixedTimestep{FIRST, STEP}, T}, val, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, FIRST, STEP, LAST} 
	setindex!(v.data, val, ts.t)
end

function Base.setindex!(v::TimestepVector{VariableTimestep{TIMES}, T}, val, ts::VariableTimestep{TIMES}) where {T, TIMES}
	setindex!(v.data, val, ts.t)	
end

function Base.setindex!(v::TimestepVector{FixedTimestep{D_FIRST, STEP}, T}, val, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, D_FIRST, T_FIRST, STEP, LAST} 
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	setindex!(v.data, val, t)
end

function Base.setindex!(v::TimestepVector{VariableTimestep{D_FIRST}, T}, val, ts::VariableTimestep{T_FIRST}) where {T, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1
	setindex!(v.data, val, t)
end

# int indexing version supports old style components 
# function Base.setindex!(v::TimestepVector, val, i::AnyIndex)
# 	setindex!(v.data, val, i)
# end

function Base.setindex!(v::TimestepVector{FixedTimestep{Start, STEP}, T}, val, i::AnyIndex) where {T, Start, STEP}
	setindex!(v.data, val, i)
end

function Base.setindex!(v::TimestepVector{VariableTimestep{TIMES}, T}, val, i::AnyIndex) where {T, TIMES}
	setindex!(v.data, val, i)
end

# TBD:  this function assumes fixed step size, need to parameterize properly 
# and then create a version for variable timestep.  It is also not used within
# the code and possibly incorrectly interprets the meaning of the Base.indices function.
# function Base.indices(x::TimestepVector{T, Start, Step}) where {T, Start, Step}
# 	return (Start:Step:(Start + (length(x.data) - 1) * Step), )
# end

function Base.length(v::TimestepVector)
	return length(v.data)
end

Base.endof(v::TimestepVector) = length(v)

#
# 3c. TimestepMatrix
#


# function Base.getindex(mat::TimestepMatrix, ts::T, i::AnyIndex) where {T <: AbstractTimestep}
# 	return mat.data[ts.t, i]
# end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T}, ts::FixedTimestep{FIRST, STEP, LAST}, i::AnyIndex) where {T, FIRST, STEP, LAST} 
	return mat.data[ts.t, i]
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T}, ts::VariableTimestep{TIMES}, i::AnyIndex) where {T, TIMES}
	return mat.data[ts.t, i]
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T}, ts::FixedTimestep{T_FIRST, STEP, LAST}, i::AnyIndex) where {T, D_FIRST, T_FIRST, STEP, LAST} 
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	return return mat.data[t, i]
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{D_FIRST}, T}, ts::VariableTimestep{T_FIRST}, i::AnyIndex) where {T, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1
	return return mat.data[t, i]
end

# int indexing version supports old style components
# function Base.getindex(mat::TimestepMatrix, idx1::AnyIndex, idx2::AnyIndex)
# 	return mat.data[idx1, idx2]
# end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T}, idx1::AnyIndex, idx2::AnyIndex) where {T, FIRST, STEP}
	return mat.data[idx1, idx2]
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T}, idx1::AnyIndex, idx2::AnyIndex) where {T, TIMES}
	return mat.data[idx1, idx2]
end

# function Base.setindex(mat::TimestepMatrix, val, ts::T, idx::AnyIndex) where {T <: AbstractTimestep}
# 	setindex!(mat.data, val, ts.t, idx)
# end

function Base.setindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T}, val, ts::FixedTimestep{FIRST, STEP, LAST}, idx::AnyIndex) where {T, FIRST, STEP, LAST} 
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T}, val, ts::VariableTimestep{TIMES}, idx::AnyIndex) where {T, TIMES}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T}, val, ts::FixedTimestep{T_FIRST, STEP, LAST}, idx::AnyIndex) where {T, D_FIRST, T_FIRST, STEP, LAST} 
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{D_FIRST}, T}, val, ts::VariableTimestep{T_FIRST}, idx::AnyIndex) where {T, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1
	setindex!(mat.data, val, t, idx)
end

# int indexing version supports old style components
# function Base.setindex!(mat::TimestepMatrix, val, idx1::AnyIndex, idx2::AnyIndex)
# 	setindex!(mat.data, val, idx1, idx2)
# end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T}, val, idx1::AnyIndex, idx2::AnyIndex) where {T, FIRST, STEP}
	setindex!(mat.data, val, idx1, idx2)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T}, val, idx1::AnyIndex, idx2::AnyIndex) where {T, TIMES}
	setindex!(mat.data, val, idx1, idx2)
end

#
# 4. TimestepArray methods
#

Base.fill!(obj::TimestepArray, value) = fill!(obj.data, value)

Base.size(obj::TimestepArray) = size(obj.data)

Base.size(obj::TimestepArray, i::Int) = size(obj.data, i)

Base.ndims(obj::TimestepArray{T_ts, T, N}) where {T_ts,T, N} = N

Base.eltype(obj::TimestepArray{T_ts, T, N}) where {T_ts,T, N} = T

first_period(obj::TimestepArray{FixedTimestep{FIRST,STEP}, T, N}) where {FIRST, STEP, T, N} = FIRST
first_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N}) where {TIMES, T, N} = TIMES[1]

last_period(obj::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}) where {FIRST, STEP,T, N} = (FIRST + (size(obj, 1) - 1) * STEP)
last_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N}) where {TIMES,T, N} = TIMES[end]

time_labels(obj::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}) where {FIRST, STEP, T, N} = collect(FIRST:STEP:(FIRST + (size(obj, 1) - 1) * STEP))
time_labels(obj::TimestepArray{VariableTimestep{TIMES}, T, N}) where {TIMES, T, N} = collect(TIMES)

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}, ts::FixedTimestep{FIRST, STEP, LAST}, idxs::AnyIndex...) where {T, N, FIRST, STEP, LAST}
	return arr.data[ts.t, idxs...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N}, ts::VariableTimestep{TIMES}, idxs::AnyIndex...) where {T, N, TIMES}
	return arr.data[ts.t, idxs...]
end

function Base.getindex(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N}, ts::FixedTimestep{T_FIRST, STEP, LAST}, idxs::AnyIndex...) where {T, N, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (FIRST - TIMES[1]) / STEP)					
	return arr.data[t, idxs...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N}, ts::VariableTimestep{T_FIRST}, idxs::AnyIndex...) where {T, N, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1	
	return arr.data[t, idxs...]
end

# Old-style: first index is Int or Range, rather than a Timestep
# function Base.getindex(arr::TimestepArray, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...)
# 	return arr.data[idx1, idx2, idxs...]
# end

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, FIRST, STEP}
	return arr.data[idx1, idx2, idxs...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N}, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, TIMES}
	return arr.data[idx1, idx2, idxs...]
end

# function Base.setindex!(arr::TimestepArray, val, ts::T, idxs::AnyIndex...) where {T <: AbstractTimestep}
# 	setindex!(arr.data, val, ts.t, idxs...)
# end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}, val, ts::FixedTimestep{FIRST, STEP, LAST}, idxs::AnyIndex...) where {T, N, FIRST, STEP, LAST}
	setindex!(arr.data, val, ts.t, idxs...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N}, val, ts::VariableTimestep{TIMES}, idxs::AnyIndex...) where {T, N, TIMES}
	setindex!(arr.data, val, ts.t, idxs...)
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N}, val, ts::FixedTimestep{T_FIRST, STEP, LAST}, idxs::AnyIndex...) where {T, N, D_FIRST, T_FIRST, STEP, LAST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1	
	setindex!(arr.data, val, t, idxs...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N}, val, ts::VariableTimestep{T_FIRST}, idxs::AnyIndex...) where {T, N, D_FIRST, T_FIRST}
	t = ts.t + findfirst(D_FIRST, T_FIRST[1]) - 1	
	setindex!(arr.data, val, t, idxs...)
end

# Old-style: first index is Int or Range, rather than a Timestep
# function Base.setindex!(arr::TimestepArray, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...)
# 	setindex!(arr.data, val, idx1, idx2, idxs...)
# end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, FIRST, STEP}
	setindex!(arr.data, val, idx1, idx2, idxs...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N}, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, TIMES}
	setindex!(arr.data, val, idx1, idx2, idxs...)
end

# function hasvalue(arr::TimestepArray, ts::T) where {T <: AbstractTimestep}
# 	return 1 <= ts.t <= size(arr, 1)	
# end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep) 

Return `true` or `false` regarding whether the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N}, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, N, FIRST, STEP, LAST}
	return 1 <= ts.t <= size(arr, 1)	
end

"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep) 

Return `true` or `false` regarding whether the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{VariableTimestep{TIMES}, T, N}, ts::VariableTimestep{TIMES}) where {T, N, TIMES}
	return 1 <= ts.t <= size(arr, 1)	
end

function hasvalue(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N}, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, N, D_FIRST, T_FIRST, STEP, LAST}
	return D_FIRST <= gettime(ts) <= last_period(arr)
end

function hasvalue(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N}, ts::VariableTimestep{T_FIRST}) where {T, N, T_FIRST, D_FIRST}
	return D_FIRST[1] <= gettime(ts) <= last_period(arr)	
end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep, idxs::Int...) 

Return `true` or `false` regarding whether the TimestepArray `arr` contains the Timestep `ts` within
indices `indxs`.
"""
# Array and Timestep have different FIRST, validating all dimensions
function hasvalue(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N}, 
	ts::FixedTimestep{T_FIRST, STEP, LAST}, 
	idxs::Int...) where {T, N, D_FIRST, T_FIRST, STEP, LAST}
	return D_FIRST <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end

"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep, idxs::Int...)

Return `true` or `false` regarding whether the TimestepArray `arr` contains the Timestep `ts` within
indices `indxs`.
"""
# Array and Timestep different TIMES, validating all dimensions
function hasvalue(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N}, 
	ts::VariableTimestep{T_FIRST}, 
	idxs::Int...) where {T, N, D_FIRST, T_FIRST}

	return D_FIRST[1] <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end

# TBD:  this function assumes fixed step size, need to parameterize properly 
# and then create a version for variable timestep; also this is never used so we 
# may just want to deprecate it
# function Base.indices(arr::TimestepArray{T, N, Start, Step}) where {T, N, Start, Step}
# 	idxs = [1:size(arr, i) for i in 2:ndims(arr)]
# 	stop = last_period(arr)
# 	return (Start:Step:stop, idxs...)
# end