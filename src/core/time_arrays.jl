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
		last = last_period(md)
		first === nothing && @warn "get_timestep_array: first === nothing"
		last === nothing && @warn "get_timestep_array: last === nothing"
        return TimestepArray{FixedTimestep{first, stepsize, last}, T, N, ti}(value)
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
function _missing_data_check(data, t)
	if data === missing
		throw(MissingException("Cannot get index; data is missing. You may have tried to access a value in timestep $t that has not yet been computed."))
	else
		return data
	end
end

# Helper function for getindex; throws an error if the TimestepIndex index is out of range of the TimestepArray
function _index_bounds_check(data, dim, t)
	if size(data, dim) < t
		error("TimestepIndex index $t extends beyond bounds of TimestepArray dimension $dim")
	end
end

# Helper function for getindex; throws an error if you index into a N-dimensional TimestepArray with only one index 
# if N > 1; Note that Julia does allow this and returns the column-major value, but this could produce unexpected 
# behavior for users in this case so we do not allow it for now
function _single_index_check(data, idxs)
	num_idxs = length(idxs)
	num_dims = length(size(data))
	if num_idxs < num_dims
		error("Not enough indices provided to index into TimestepArray, $num_idxs provided, $num_dims required")
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


# Helper functions for TimestepValue type
function _get_time_value_position(times::Union{Tuple, Array}, ts::TimestepValue{T}) where T
	t = findfirst(isequal.(ts.value, times))
	if t === nothing
		error("cannot use TimestepValue with value $(ts.value), value is not in the TimestepArray")
	end

	t_offset = t + ts.offset
	if t_offset > length(times) 
		error("cannot get TimestepValue offset of $(ts.offset) from value $(ts.value), offset is after the end of the TimestepArray")
	end
	return t_offset
end

# Helper function to get the array of indices from an Array{TimestepIndex,1} or Array{TimestepValue, 1}
function _get_ts_indices(ts_array::Array{TimestepIndex, 1})
    return [ts.index for ts in ts_array]
end

function _get_ts_indices(ts_array::Array{TimestepValue{T}, 1}, times::Union{Tuple, Array}) where T
	return [_get_time_value_position(times, ts) for ts in ts_array]
end

# Base.firstindex and Base.lastindex
function Base.firstindex(arr::TimestepArray{T_TS, T, N, ti}) where {T_TS, T, N, ti}
	if ti == 1
		return TimestepIndex(1)
	else
		return 1
	end
end

function Base.lastindex(arr::TimestepArray{T_TS, T, N, ti}) where {T_TS, T, N, ti}
	if ti == length(size(arr.data))
		return TimestepIndex(length(arr.data))
	else
		return length(arr.data)
	end
end

function Base.lastindex(arr::TimestepArray{T_TS, T, N, ti}, dim::Int) where {T_TS, T, N, ti}
	if ti == dim
		return TimestepIndex(size(arr.data, dim))
	else
		return size(arr.data, dim)
	end
end

function Base.firstindex(arr::TimestepArray{T_TS, T, N, ti}, dim::Int) where {T_TS, T, N, ti}
	if ti == dim
		return TimestepIndex(1)
	else
		return 1
	end
end

# add axes methos copied from abstarctarray.jl:56
function Base.axes(A::TimestepArray{T_TS, T, N, ti}, d::Int) where {T_TS, T, N, ti}
	_d_lessthan_N = d <= N;
	if d == ti
		if _d_lessthan_N
			return Tuple(TimestepIndex.(1:size(A,d)))
		else
			return TimestepIndex(1)
		end
	else
		if _d_lessthan_N
			if _d_lessthan_N
				return 1:size(A,d)
			else
				return 1
			end
		end
	end
end

#
# b. TimestepVector
#

function Base.length(v::TimestepVector)
	return length(v.data)
end

function Base.getindex(v::TimestepVector, ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	data = v.data[ts.t]
	_missing_data_check(data, ts.t)
end

function Base.getindex(v::TimestepVector, ts::VariableTimestep{TIMES}) where {TIMES}
	data = v.data[ts.t]
	_missing_data_check(data, ts.t)
end

function Base.getindex(v::TimestepVector{FixedTimestep{FIRST, STEP, LAST}, T_data}, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time} 
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	data = v.data[t]
	_missing_data_check(data, t)
end

function Base.getindex(v::TimestepVector{VariableTimestep{TIMES}, T_data}, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	data = v.data[t]
	_missing_data_check(data, t)
end

function Base.getindex(v::TimestepVector, ts::TimestepIndex) 
	_index_bounds_check(v.data, 1, ts.index)
	data = v.data[ts.index]
	_missing_data_check(data, ts.index)
end

function Base.setindex!(v::TimestepVector, val, ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	setindex!(v.data, val, ts.t)
end

function Base.setindex!(v::TimestepVector, val, ts::VariableTimestep{TIMES}) where {TIMES}
	setindex!(v.data, val, ts.t)
end

function Base.setindex!(v::TimestepVector{FixedTimestep{FIRST, STEP, LAST}, T_data}, val, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time}
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	setindex!(v.data, val, t)
end

function Base.setindex!(v::TimestepVector{VariableTimestep{TIMES}, T_data}, val, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	setindex!(v.data, val, t)
end

function Base.setindex!(v::TimestepVector, val, ts::TimestepIndex)
	setindex!(v.data, val, ts.index)
end

#
# c. TimestepMatrix
#

function Base.getindex(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 1}, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}, idx::AnyIndex) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	data = mat.data[ts.t, idx]
	_missing_data_check(data, ts.t)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 1}, ts::VariableTimestep{T_TIMES}, idx::AnyIndex) where {T, M_TIMES, T_TIMES}
	data = mat.data[ts.t, idx]
	_missing_data_check(data, ts.t)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 2}, idx::AnyIndex, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	data = mat.data[idx, ts.t]
	_missing_data_check(data, ts.t)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 2}, idx::AnyIndex, ts::VariableTimestep{T_TIMES}) where {T, M_TIMES, T_TIMES}
	data = mat.data[idx, ts.t]
	_missing_data_check(data, ts.t)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 1}, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, FIRST, STEP, LAST, T_time} 
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] + 1 : view_offset = 0
	t = t - view_offset
	data = mat.data[t, idx]
	_missing_data_check(data, t)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 1}, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] + 1 : view_offset = 0
	t = t - view_offset
	data = mat.data[t, idx]
	_missing_data_check(data, t)
end

function Base.getindex(mat::TimestepMatrix, ts::TimestepIndex, idx::AnyIndex)
	t = ts.index
	_index_bounds_check(mat.data, 1, t)
	data = mat.data[t, idx]
	_missing_data_check(data, t)
end

function Base.getindex(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 2}, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time} 
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] + 1 : view_offset = 0
	t = t - view_offset
	data = mat.data[idx, t]
	_missing_data_check(data, t)
end

function Base.getindex(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 2}, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] + 1 : view_offset = 0
	t = t - view_offset	
	data = mat.data[idx, t]
	_missing_data_check(data, t)
end

function Base.getindex(mat::TimestepMatrix, idx::AnyIndex, ts::TimestepIndex)
	t = ts.index
	_index_bounds_check(mat.data, 2, t)
	data = mat.data[idx, t]
	_missing_data_check(data, t)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 1}, val, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}, idx::AnyIndex) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 1}, val, ts::VariableTimestep{T_TIMES}, idx::AnyIndex) where {T, M_TIMES, T_TIMES}
	setindex!(mat.data, val, ts.t, idx)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 2}, val, idx::AnyIndex, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	setindex!(mat.data, val, idx, ts.t)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 2}, val, idx::AnyIndex, ts::VariableTimestep{T_TIMES}) where {T, M_TIMES, T_TIMES}
	setindex!(mat.data, val, idx, ts.t)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 1}, val, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, FIRST, STEP, LAST, T_time}
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 1}, val, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(mat.data, val, t, idx)
end

function Base.setindex!(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 2}, val, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time}
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(mat.data, val, idx, t)
end

function Base.setindex!(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 2}, val, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(mat.data, val, idx, t)
end

function Base.setindex!(mat::TimestepMatrix, val, idx::AnyIndex, ts::TimestepIndex)
	setindex!(mat.data, val, idx, ts.index)
end

function Base.setindex!(mat::TimestepMatrix, val, ts::TimestepIndex, idx::AnyIndex)
	setindex!(mat.data, val, ts.index, idx)
end

#
# TimestepArray methods
#

# _dotview_helper TODOs - we should add options for if the arg is a TimestepValue
# or an array of TimestepIndexes or TimestepValues
function _dotview_helper(arg)
	if arg isa AbstractTimestep
		return arg.t
	elseif arg isa TimestepIndex
		return arg.index
	else
		return arg
	end
end

function Base.dotview(v::TimestepArray, args...)
	# convert any timesteps to their underlying index
	args = map(_dotview_helper, args)
	Base.dotview(v.data, args...)
end

Base.fill!(obj::TimestepArray, value) = fill!(obj.data, value)

Base.size(obj::TimestepArray) = size(obj.data)

Base.size(obj::TimestepArray, i::Int) = size(obj.data, i)

Base.ndims(obj::TimestepArray{T_ts, T, N, ti}) where {T_ts, T, N, ti} = N

Base.eltype(obj::TimestepArray{T_ts, T, N, ti}) where {T_ts, T, N, ti} = T

first_period(obj::TimestepArray{FixedTimestep{FIRST,STEP, LAST}, T, N, ti}) where {FIRST, STEP, LAST, T, N, ti} = FIRST
first_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = TIMES[1]

last_period(obj::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}) where {FIRST, STEP, LAST, T, N, ti} = (FIRST + (size(obj, 1) - 1) * STEP)
last_period(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = TIMES[end]

time_labels(obj::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}) where {FIRST, STEP, LAST, T, N, ti} = collect(FIRST:STEP:(FIRST + (size(obj, 1) - 1) * STEP))
time_labels(obj::TimestepArray{VariableTimestep{TIMES}, T, N, ti}) where {TIMES, T, N, ti} = collect(TIMES)

split_indices(idxs, ti) = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]

function Base.getindex(arr::TimestepArray{FixedTimestep{A_FIRST, A_STEP, A_LAST}, T, N, ti}, idxs::Union{FixedTimestep{T_FIRST, T_STEP, T_LAST}, AnyIndex}...) where {A_FIRST, A_STEP, A_LAST, T_FIRST, T_STEP, T_LAST, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	return arr.data[idxs1..., ts.t, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{A_TIMES}, T, N, ti}, idxs::Union{VariableTimestep{T_TIMES}, AnyIndex}...) where {A_TIMES, T_TIMES, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	return arr.data[idxs1..., ts.t, idxs2...]
end

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	t = t - view_offset
	return arr.data[idxs1..., t, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = _get_time_value_position(TIMES, ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	t = t - view_offset
	return arr.data[idxs1..., t, idxs2...]
end

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, idxs::Union{TimestepIndex, AnyIndex}...) where {T, N, ti, FIRST, STEP, LAST}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = ts.index
	_index_bounds_check(arr.data, ti, t)
	return arr.data[idxs1..., t, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idxs::Union{TimestepIndex, AnyIndex}...) where {T, N, ti, TIMES}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = ts.index
	_index_bounds_check(arr.data, ti, t)
	return arr.data[idxs1..., t, idxs2...]
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{A_FIRST, A_STEP, A_LAST}, T, N, ti}, val, idxs::Union{FixedTimestep{T_FIRST, T_STEP, T_LAST}, AnyIndex}...) where {A_FIRST, A_STEP, A_LAST, T_FIRST, T_STEP, T_LAST, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{A_TIMES}, T, N, ti}, val, idxs::Union{VariableTimestep{T_TIMES}, AnyIndex}...) where {A_TIMES, T_TIMES, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, val, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(arr.data, val, idxs1..., t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, val, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	t = _get_time_value_position(TIMES, ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	t = t - view_offset
	setindex!(arr.data, val, idxs1..., t, idxs2...)
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, val, idxs::Union{TimestepIndex, AnyIndex}...) where {FIRST, STEP, LAST, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.index, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, val, idxs::Union{TimestepIndex, AnyIndex}...) where {TIMES, T, N, ti}
	idxs1, ts, idxs2 = split_indices(idxs, ti)
	setindex!(arr.data, val, idxs1..., ts.index, idxs2...)
end

# Indexing with arrays of TimestepIndexes or TimestepValues
function Base.getindex(arr::TimestepArray{TS, T, N, ti}, idxs::Union{Array{TimestepIndex,1}, AnyIndex}...) where {TS, T, N, ti}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array)
	return arr.data[idxs1..., ts_idxs, idxs2...]
end

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array, [FIRST:STEP:LAST...])
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	return arr.data[idxs1..., ts_idxs, idxs2...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array, TIMES)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	return arr.data[idxs1..., ts_idxs, idxs2...]
end

function Base.setindex!(arr::TimestepArray{TS, T, N, ti}, vals, idxs::Union{Array{TimestepIndex,1}, AnyIndex}...) where {TS, T, N, ti}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array)
	setindex!(arr.data, vals, idxs1..., ts_idxs, idxs2...)
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, vals, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array, [FIRST:STEP:LAST...])
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	setindex!(arr.data, vals, idxs1..., ts_idxs, idxs2...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, vals, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	idxs1, ts_array, idxs2 = split_indices(idxs, ti)
	ts_idxs = _get_ts_indices(ts_array, TIMES)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] + 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	setindex!(arr.data, vals, idxs1..., ts_idxs, idxs2...)
end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{FixedTimestep{A_FIRST, A_STEP, A_LAST}, T, N, ti}, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}) where {T, N, ti, A_FIRST, A_STEP, A_LAST, T_FIRST, T_STEP, T_LAST}
	return A_FIRST <= gettime(ts) <= last_period(arr)
end
"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts`.
"""
function hasvalue(arr::TimestepArray{VariableTimestep{A_TIMES}, T, N, ti}, ts::VariableTimestep{T_TIMES}) where {T, N, ti, A_TIMES, T_TIMES}
	return A_TIMES[1] <= gettime(ts) <= last_period(arr)
end

"""
	hasvalue(arr::TimestepArray, ts::FixedTimestep, idxs::Int...)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts` within
indices `idxs`. Used when Array and Timestep have different FIRST, validating all dimensions.
"""
function hasvalue(arr::TimestepArray{FixedTimestep{A_FIRST, A_STEP, A_LAST}, T, N, ti},
	ts::FixedTimestep{T_FIRST, T_STEP, T_LAST},
	idxs::Int...) where {T, N, ti, A_FIRST, A_STEP, A_LAST, T_FIRST, T_STEP, T_LAST}
	return A_FIRST <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end

"""
	hasvalue(arr::TimestepArray, ts::VariableTimestep, idxs::Int...)

Return `true` or `false`, `true` if the TimestepArray `arr` contains the Timestep `ts` within
indices `idxs`. Used when Array and Timestep have different TIMES, validating all dimensions.
"""
function hasvalue(arr::TimestepArray{VariableTimestep{A_TIMES}, T, N, ti},
	ts::VariableTimestep{T_TIMES},
	idxs::Int...) where {T, N, ti, A_TIMES, T_TIMES}

	return A_TIMES[1] <= gettime(ts) <= last_period(arr) && all([1 <= idx <= size(arr, i) for (i, idx) in enumerate(idxs)])
end

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

# -- throw errors --

const AnyIndex_NonColon = Union{Int, Vector{Int}, Tuple, OrdinalRange}

# Helper function for getindex; throws an error if one indexes into a TimestepArray with an integer
function _throw_int_getindex_error()
	error("Indexing with getindex into a TimestepArray with Integer(s) is deprecated, please index with a TimestepIndex(index::Int) instead ie. instead of t[2] use t[TimestepIndex(2)]")
end

# Helper function for setindex; throws an error if one indexes into a TimestepArray with an integer
function _throw_int_setindex_error()
	error("Indexing with setindex into a TimestepArray with Integer(s) is deprecated, please index with a TimestepIndex(index::Int) instead ie. instead of t[2] use t[TimestepIndex(2)]")
end

# int indexing version supports old-style components and internal functions, not
# part of the public API

function Base.getindex(v::TimestepVector, i::AnyIndex_NonColon)
	_throw_int_getindex_error()
end

function Base.setindex!(v::TimestepVector, val, i::AnyIndex_NonColon)
	_throw_int_setindex_error()
end

# int indexing version supports old-style components and internal functions, not
# part of the public API

function Base.getindex(mat::TimestepMatrix, idx1::AnyIndex_NonColon, idx2::AnyIndex_NonColon)
	_throw_int_getindex_error()
end

function Base.setindex!(mat::TimestepMatrix, val, idx1::Int, idx2::Int)
	_throw_int_setindex_error()
end

# Colon support - this allows the time dimension to be indexed with a colon

function Base.getindex(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, idxs::AnyIndex...) where {FIRST, STEP, LAST, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_getindex_error() : nothing
	return arr.data[idxs...]
end

function Base.getindex(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idxs::AnyIndex...) where {TIMES, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_getindex_error() : nothing
	return arr.data[idxs...]
end

function Base.setindex!(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, val, idxs::AnyIndex...) where {FIRST, STEP, LAST, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_setindex_error() : nothing
	setindex!(arr.data, val, idxs...)
end

function Base.setindex!(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, val, idxs::AnyIndex...) where {TIMES, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_setindex_error() : nothing
	setindex!(arr.data, val, idxs...)
end
