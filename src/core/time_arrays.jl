#
# TimestepVector and TimestepMatrix
#

#
# a.  General
#

# Get a timestep array of type T with N dimensions. Time labels will match those from the time dimension in md
function get_timestep_array(md::ModelDef, T, N, ti, value)
	if isuniform(md)
		first, stepsize = first_and_step(md)
		first === nothing && @warn "get_timestep_array: first === nothing"
        return TimestepArray{FixedTimestep{first, stepsize}, T, N, ti}(value)
    else
        TIMES = (time_labels(md)...,)
        return TimestepArray{VariableTimestep{TIMES}, T, N, ti}(value)
    end
end

# Return the index position of the time dimension in the datumdef or parameter. If there is no time dimension, return nothing
get_time_index_position(dims::Union{Nothing, Array{Symbol}}) = findfirst(isequal(:time), dims)
get_time_index_position(obj::Union{AbstractDatumDef, ArrayModelParameter}) = get_time_index_position(dim_names(obj))

function get_time_index_position(obj::AbstractCompositeComponentDef, comp_name::Symbol, datum_name::Symbol)
	get_time_index_position(dim_names(compdef(obj, comp_name), datum_name))
end

const AnyIndex = Union{Int, Vector{Int}, Tuple, Colon, OrdinalRange}

# Helper function for getindex; throws a MissingException if data is missing, otherwise returns data
function _missing_data_check(data)
	if data === missing
		throw(MissingException("Cannot get index; data is missing. You may have tried to access a value that has not yet been computed."))
	else
		return data
	end
end

# Helper macro used by connector
macro allow_missing(expr)
	let e = gensym("e")
		retexpr = quote
			try
				$expr
			catch $e
				if $e isa MissingException
					missing
				else
					rethrow($e)
				end
			end
		end
		return esc(retexpr)
	end
end

#
# b. TimestepVector
#

function Base.getindex(v::TimestepVector{FixedTimestep{FIRST, STEP}, T}, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, FIRST, STEP, LAST}
	data = v.data[ts.t]
	_missing_data_check(data)
end

function Base.getindex(v::TimestepVector{VariableTimestep{TIMES}, T}, ts::VariableTimestep{TIMES}) where {T, TIMES}
	data = v.data[ts.t]
	_missing_data_check(data)
end

function Base.getindex(v::TimestepVector{FixedTimestep{D_FIRST, STEP}, T}, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	data = v.data[t]
	_missing_data_check(data)
end

function Base.getindex(v::TimestepVector{VariableTimestep{D_TIMES}, T}, ts::VariableTimestep{T_TIMES}) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	data = v.data[t]
	_missing_data_check(data)
end

# int indexing version supports old-style components and internal functions, not
# part of the public API

function Base.getindex(v::TimestepVector{FixedTimestep{FIRST, STEP}, T}, i::AnyIndex) where {T, FIRST, STEP}
	return v.data[i]
end

function Base.getindex(v::TimestepVector{VariableTimestep{TIMES}, T}, i::AnyIndex) where {T, TIMES}
	return v.data[i]
end

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

function Base.setindex!(v::TimestepVector{VariableTimestep{D_TIMES}, T}, val, ts::VariableTimestep{T_TIMES}) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	setindex!(v.data, val, t)
end

# int indexing version supports old-style components and internal functions, not
# part of the public API

function Base.setindex!(v::TimestepVector{FixedTimestep{Start, STEP}, T}, val, i::AnyIndex) where {T, Start, STEP}
	setindex!(v.data, val, i)
end

function Base.setindex!(v::TimestepVector{VariableTimestep{TIMES}, T}, val, i::AnyIndex) where {T, TIMES}
	setindex!(v.data, val, i)
end

function Base.length(v::TimestepVector)
	return length(v.data)
end

Base.lastindex(v::TimestepVector) = length(v)

#
# c. TimestepMatrix
#

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, 1}, ts::FixedTimestep{FIRST, STEP, LAST}, idx::AnyIndex) where {T, FIRST, STEP, LAST}
	data = mat.data[ts.t, idx]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T, 1}, ts::VariableTimestep{TIMES}, idx::AnyIndex) where {T, TIMES}
	data = mat.data[ts.t, idx]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T, 1}, ts::FixedTimestep{T_FIRST, STEP, LAST}, idx::AnyIndex) where {T, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	data = mat.data[t, idx]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{D_TIMES}, T, 1}, ts::VariableTimestep{T_TIMES}, idx::AnyIndex) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	data = mat.data[t, idx]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, 2}, idx::AnyIndex, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, FIRST, STEP, LAST}
	data = mat.data[idx, ts.t]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T, 2}, idx::AnyIndex, ts::VariableTimestep{TIMES}) where {T, TIMES}
	# WAS THIS: data = mat.data[ts.t, idx, ts.t]
	data = mat.data[idx, ts.t]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T, 2}, idx::AnyIndex, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	data = mat.data[idx, ts.t]
	_missing_data_check(data)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{D_TIMES}, T, 2}, idx::AnyIndex, ts::VariableTimestep{T_TIMES}) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	data = mat.data[idx, ts.t]
	_missing_data_check(data)
end


function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, 1}, val, ts::FixedTimestep{FIRST, STEP, LAST}, idx::AnyIndex) where {T, FIRST, STEP, LAST}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T, 1}, val, ts::VariableTimestep{TIMES}, idx::AnyIndex) where {T, TIMES}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T, 1}, val, ts::FixedTimestep{T_FIRST, STEP, LAST}, idx::AnyIndex) where {T, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{D_TIMES}, T, 1}, val, ts::VariableTimestep{T_TIMES}, idx::AnyIndex) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, 2}, val, idx::AnyIndex, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, FIRST, STEP, LAST}
	setindex!(mat.data, val, idx, ts.t)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T, 2}, val, idx::AnyIndex, ts::VariableTimestep{TIMES}) where {T, TIMES}
	setindex!(mat.data, val, idx, ts.t)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{D_FIRST, STEP}, T, 2}, val, idx::AnyIndex, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, D_FIRST, T_FIRST, STEP, LAST}
	t = Int(ts.t + (T_FIRST - D_FIRST) / STEP)
	setindex!(mat.data, val, idx, t)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{D_TIMES}, T, 2}, val, idx::AnyIndex, ts::VariableTimestep{T_TIMES}) where {T, D_TIMES, T_TIMES}
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	setindex!(mat.data, val, idx, t)
end

# int indexing version supports old-style components and internal functions, not
# part of the public API

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, ti}, idx1::AnyIndex, idx2::AnyIndex) where {T, FIRST, STEP, ti}
	return mat.data[idx1, idx2]
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T, ti}, idx1::AnyIndex, idx2::AnyIndex) where {T, TIMES, ti}
	return mat.data[idx1, idx2]
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, ti}, val, idx1::Int, idx2::Int) where {T, FIRST, STEP, ti}
	setindex!(mat.data, val, idx1, idx2)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP}, T, ti}, val, idx1::AnyIndex, idx2::AnyIndex) where {T, FIRST, STEP, ti}
	mat.data[idx1, idx2] .= val
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T, ti}, val, idx1::Int, idx2::Int) where {T, TIMES, ti}
	setindex!(mat.data, val, idx1, idx2)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T, ti}, val, idx1::AnyIndex, idx2::AnyIndex) where {T, TIMES, ti}
	mat.data[idx1, idx2] .= val
end

#
# TimestepArray methods
#
function Base.dotview(v::Mimi.TimestepArray, args...)
	# convert any timesteps to their underlying index
	args = map(arg -> (arg isa AbstractTimestep ? arg.t : arg), args)
	Base.dotview(v.data, args...)
end

Base.fill!(obj::TimestepArray, value) = fill!(obj.data, value)

Base.size(obj::TimestepArray) = size(obj.data)

Base.size(obj::TimestepArray, i::Int) = size(obj.data, i)

Base.ndims(obj::TimestepArray{T_ts, T, N, ti}) where {T_ts, T, N, ti} = N

Base.eltype(obj::TimestepArray{T_ts, T, N, ti}) where {T_ts, T, N, ti} = T

first_period(obj::TimestepArray{FixedTimestep{FIRST,STEP}, T, N, ti}) where {FIRST, STEP, T, N, ti} = FIRST
first_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = TIMES[1]

last_period(obj::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}) where {FIRST, STEP, T, N, ti} = (FIRST + (size(obj, 1) - 1) * STEP)
last_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = TIMES[end]

time_labels(obj::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}) where {FIRST, STEP, T, N, ti} = collect(FIRST:STEP:(FIRST + (size(obj, 1) - 1) * STEP))
time_labels(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = collect(TIMES)

split_indices(idxs, ti) = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}, idxs::Union{FixedTimestep{FIRST, STEP, LAST}, AnyIndex}...) where {T, N, ti, FIRST, STEP, LAST}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	return arr.data[idxs1..., ts.t, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idxs::Union{VariableTimestep{TIMES}, AnyIndex}...) where {T, N, ti, TIMES}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	return arr.data[idxs1..., ts.t, idxs2...]
end

function Base.getindex(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N, ti}, idxs::Union{FixedTimestep{T_FIRST, STEP, LAST}, AnyIndex}...) where {T, N, ti, D_FIRST, T_FIRST, STEP, LAST}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = Int(ts.t + (FIRST - TIMES[1]) / STEP)
	return arr.data[idxs1..., t, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{D_TIMES}, T, N, ti}, idxs::Union{VariableTimestep{T_TIMES}, AnyIndex}...) where {T, N, ti, D_TIMES, T_TIMES}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = ts.t + findfirst(isequal(T_TIMES[1]), D_TIMES) - 1
	return arr.data[idxs1..., t, idxs2...]
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}, val, idxs::Union{FixedTimestep{FIRST, STEP, LAST}, AnyIndex}...) where {T, N, ti, FIRST, STEP, LAST}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, val, idxs::Union{VariableTimestep{TIMES}, AnyIndex}...) where {T, N, ti, TIMES}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N, ti}, val, idxs::Union{FixedTimestep{T_FIRST, STEP, LAST}, AnyIndex}...) where {T, N, ti, D_FIRST, T_FIRST, STEP, LAST}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = ts.t + findfirst(isequal(T_FIRST[1]), D_FIRST) - 1
	setindex!(arr.data, val, idxs1..., t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{D_TIMES}, T, N, ti}, val, idxs::Union{VariableTimestep{T_TIMES}, AnyIndex}...) where {T, N, ti, D_TIMES, T_TIMES}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = ts.t + findfirst(isequal(T_FIRST[1]), T_TIMES) - 1
	setindex!(arr.data, val, idxs1..., t, idxs2...)
end

# int indexing version supports old-style components and internal functions, not
# part of the public API; first index is Int or Range, rather than a Timestep

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, ti, FIRST, STEP}
	return arr.data[idx1, idx2, idxs...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, ti, TIMES}
	return arr.data[idx1, idx2, idxs...]
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, ti, FIRST, STEP}
	setindex!(arr.data, val, idx1, idx2, idxs...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, val, idx1::AnyIndex, idx2::AnyIndex, idxs::AnyIndex...) where {T, N, ti, TIMES}
	setindex!(arr.data, val, idx1, idx2, idxs...)
end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{FixedTimestep{FIRST, STEP}, T, N, ti}, ts::FixedTimestep{FIRST, STEP, LAST}) where {T, N, ti, FIRST, STEP, LAST}
	return 1 <= ts.t <= size(arr, 1)
end

"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, ts::VariableTimestep{TIMES}) where {T, N, ti, TIMES}
	return 1 <= ts.t <= size(arr, 1)
end

function hasvalue(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N, ti}, ts::FixedTimestep{T_FIRST, STEP, LAST}) where {T, N, ti, D_FIRST, T_FIRST, STEP, LAST}
	return D_FIRST <= gettime(ts) <= last_period(arr)
end

function hasvalue(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N, ti}, ts::VariableTimestep{T_FIRST}) where {T, N, ti, T_FIRST, D_FIRST}
	return D_FIRST[1] <= gettime(ts) <= last_period(arr)
end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep, idxs::Int...)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts` within
indices `idxs`. Used when Array and Timestep have different FIRST, validating all dimensions.
"""
function hasvalue(arr::TimestepArray{FixedTimestep{D_FIRST, STEP}, T, N, ti},
	ts::FixedTimestep{T_FIRST, STEP, LAST},
	idxs::Int...) where {T, N, ti, D_FIRST, T_FIRST, STEP, LAST}
	return D_FIRST <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end

"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep, idxs::Int...)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts` within
indices `idxs`. Used when Array and Timestep different TIMES, validating all dimensions.
"""
function hasvalue(arr::TimestepArray{VariableTimestep{D_FIRST}, T, N, ti},
	ts::VariableTimestep{T_FIRST},
	idxs::Int...) where {T, N, ti, D_FIRST, T_FIRST}

	return D_FIRST[1] <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end
