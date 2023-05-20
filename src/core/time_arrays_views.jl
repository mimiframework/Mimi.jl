#
# VIEWS for TimestepVector and TimestepMatrix
#

# this file extends time_arrays.jl to create paired view methods for getindex methods

#
# Helpers
#

# Helper function for getindex; throws a MissingException if data is missing, otherwise returns data
function _missing_view_data_check(data, t)
	if data[1] === missing
		throw(MissingException("Cannot get index; data is missing. You may have tried to access a value in timestep $t that has not yet been computed."))
	else
		return data
	end
end

function _missing_view_data_check(data)
	if data[1] === missing
		throw(MissingException("Cannot get index; data is missing."))
	else
		return data
	end
end

#
# TimestepVector
#

function Base.view(v::TimestepVector, ts::FixedTimestep{FIRST, STEP, LAST}) where {FIRST, STEP, LAST}
	data = view(v.data, ts.t)
	_missing_view_data_check(data, ts.t)
end

function Base.view(v::TimestepVector, ts::VariableTimestep{TIMES}) where {TIMES}
	data = view(v.data, ts.t)
	_missing_view_data_check(data, ts.t)
end

function Base.view(v::TimestepVector{FixedTimestep{FIRST, STEP, LAST}, T_data}, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time} 
	t, remainder = divrem(ts.value - FIRST, STEP)
	remainder==0 || error("Invalid index.")

	t += ts.offset + 1

	0 < t <= length(FIRST:STEP:LAST) || error("Invalid index.")

	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	data = view(v.data, t)
	_missing_view_data_check(data, t)
end

function Base.view(v::TimestepVector{VariableTimestep{TIMES}, T_data}, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	v.data isa SubArray ? view_offset = v.data.offset1 : view_offset = 0
	t = t - view_offset
	data = view(v.data, t)
	_missing_view_data_check(data, t)
end

function Base.view(v::TimestepVector, ts::TimestepIndex) 
	_index_bounds_check(v.data, 1, ts.index)
	data = view(v.data, ts.index)
	_missing_view_data_check(data, ts.index)
end

#
# TimestepMatrix
#

function Base.view(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 1}, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}, idx::AnyIndex) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	data = view(mat.data, ts.t, idx)
	_missing_view_data_check(data, ts.t)
end

function Base.view(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 1}, ts::VariableTimestep{T_TIMES}, idx::AnyIndex) where {T, M_TIMES, T_TIMES}
	data = view(mat.data, ts.t, idx)
	_missing_view_data_check(data, ts.t)
end

function Base.view(mat::TimestepMatrix{FixedTimestep{M_FIRST, M_STEP, M_LAST}, T, 2}, idx::AnyIndex, ts::FixedTimestep{T_FIRST, T_STEP, T_LAST}) where {T, M_FIRST, M_STEP, M_LAST, T_FIRST, T_STEP, T_LAST}
	data = view(mat.data, idx, ts.t)
	_missing_view_data_check(data, ts.t)
end

function Base.view(mat::TimestepMatrix{VariableTimestep{M_TIMES}, T, 2}, idx::AnyIndex, ts::VariableTimestep{T_TIMES}) where {T, M_TIMES, T_TIMES}
	data = view(mat.data, idx, ts.t)
	_missing_view_data_check(data, ts.t)
end

function Base.view(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 1}, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, FIRST, STEP, LAST, T_time} 
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] - 1 : view_offset = 0
	t = t - view_offset
	data = view(mat.data, t, idx)
	_missing_view_data_check(data, t)
end

function Base.view(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 1}, ts::TimestepValue{T_time}, idx::AnyIndex) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[1][1] - 1 : view_offset = 0
	t = t - view_offset
	data = view(mat.data, t, idx)
	_missing_view_data_check(data, t)
end

function Base.view(mat::TimestepMatrix, ts::TimestepIndex, idx::AnyIndex)
	t = ts.index
	_index_bounds_check(mat.data, 1, t)
	data = view(mat.data, t, idx)
	_missing_view_data_check(data, t)
end

function Base.view(mat::TimestepMatrix{FixedTimestep{FIRST, STEP, LAST}, T_data, 2}, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, FIRST, STEP, LAST, T_time} 
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] - 1 : view_offset = 0
	t = t - view_offset
	data = view(mat.data, idx, t)
	_missing_view_data_check(data, t)
end

function Base.view(mat::TimestepMatrix{VariableTimestep{TIMES}, T_data, 2}, idx::AnyIndex, ts::TimestepValue{T_time}) where {T_data, TIMES, T_time}
	t = _get_time_value_position(TIMES, ts)
	mat.data isa SubArray ? view_offset = mat.data.indices[2][1] - 1 : view_offset = 0
	t = t - view_offset	
	data = view(mat.data, idx, t)
	_missing_view_data_check(data, t)
end

function Base.view(mat::TimestepMatrix, idx::AnyIndex, ts::TimestepIndex)
	t = ts.index
	_index_bounds_check(mat.data, 2, t)
	data = view(mat.data, idx, t)
	_missing_view_data_check(data, t)
end

#
# TimestepArray methods
#

function Base.view(arr::TimestepArray{FixedTimestep{A_FIRST, A_STEP, A_LAST}, T, N, ti}, idxs::Union{FixedTimestep{T_FIRST, T_STEP, T_LAST}, AnyIndex}...) where {A_FIRST, A_STEP, A_LAST, T_FIRST, T_STEP, T_LAST, T, N, ti}
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	data = view(arr.data, idxs1..., ts.t, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{VariableTimestep{A_TIMES}, T, N, ti}, idxs::Union{VariableTimestep{T_TIMES}, AnyIndex}...) where {A_TIMES, T_TIMES, T, N, ti}
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	data = view(arr.data, idxs1..., ts.t, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	t = _get_time_value_position([FIRST:STEP:LAST...], ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] - 1 : view_offset = 0
	t = t - view_offset
	data = view(arr.data, idxs1..., t, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, idxs::Union{TimestepValue{T_time}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	t = _get_time_value_position(TIMES, ts)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] - 1 : view_offset = 0
	t = t - view_offset
	data = view(arr.data, idxs1..., t, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, idxs::Union{TimestepIndex, AnyIndex}...) where {T, N, ti, FIRST, STEP, LAST}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	t = ts.index
	_index_bounds_check(arr.data, ti, t)
	data = view(arr.data, idxs1..., t, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idxs::Union{TimestepIndex, AnyIndex}...) where {T, N, ti, TIMES}
	_single_index_check(arr.data, idxs)
	idxs1, ts, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	t = ts.index
	_index_bounds_check(arr.data, ti, t)
	data = view(arr.data, idxs1..., t, idxs2...)
	return _missing_view_data_check(data)
end

# Indexing with arrays of TimestepIndexes or TimestepValues
function Base.view(arr::TimestepArray{TS, T, N, ti}, idxs::Union{Array{TimestepIndex,1}, AnyIndex}...) where {TS, T, N, ti}
	idxs1, ts_array, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	ts_idxs = _get_ts_indices(ts_array)
	data = view(arr.data, idxs1..., ts_idxs, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T_data, N, ti}, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, FIRST, STEP, LAST, T_time}
	idxs1, ts_array, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	ts_idxs = _get_ts_indices(ts_array, [FIRST:STEP:LAST...])
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] - 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	data = view(arr.data, idxs1..., ts_idxs, idxs2...)
	return _missing_view_data_check(data)
end

function Base.view(arr::TimestepArray{VariableTimestep{TIMES}, T_data, N, ti}, idxs::Union{Array{TimestepValue{T_time},1}, AnyIndex}...) where {T_data, N, ti, TIMES, T_time}
	idxs1, ts_array, idxs2 = idxs[1:ti - 1], idxs[ti], idxs[ti + 1:end]
	ts_idxs = _get_ts_indices(ts_array, TIMES)
	arr.data isa SubArray ? view_offset = arr.data.indices[ti][1] - 1 : view_offset = 0
	ts_idxs = ts_idxs .- view_offset
	data = view(arr.data, idxs1..., ts_idxs, idxs2...)
	return _missing_view_data_check(data)
end

# Colon support - this allows the time dimension to be indexed with a colon

function Base.view(arr::TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti}, idxs::AnyIndex...) where {FIRST, STEP, LAST, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_getindex_error() : nothing
	return view(arr.data, idxs...)
end

function Base.view(arr::TimestepArray{VariableTimestep{TIMES}, T, N, ti}, idxs::AnyIndex...) where {TIMES, T, N, ti}
	isa(idxs[ti], AnyIndex_NonColon) ? _throw_int_getindex_error() : nothing
	return view(arr.data,idxs...)
end
