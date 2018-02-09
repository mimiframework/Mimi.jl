# don't need to encode N (number of dimensions) as a type parameter because we 
# are hardcoding it as 1 for the vector case
mutable struct TimestepVector{T, Offset, Duration} 
	data::Vector{T}

    function TimestepVector{T, Offset, Duration}(d::Vector{T}) where {T, Offset, Duration}
		v = new()
		v.data = d
		return v
	end

    function TimestepVector{T, Offset, Duration}(i::Int) where {T, Offset, Duration}
		v = new()
		v.data = Vector{T}(i)
		return v
	end
end

# don't need to encode N (number of dimensions) as a type parameter because we 
# are hardcoding it as 2 for the matrix case
mutable struct TimestepMatrix{T, Offset, Duration} 
	data::Array{T, 2}

    function TimestepMatrix{T, Offset, Duration}(d::Array{T, 2}) where {T, Offset, Duration}
		m = new()
		m.data = d
		return m
	end

    function TimestepMatrix{T, Offset, Duration}(i::Int, j::Int) where {T, Offset, Duration}
		m = new()
		m.data = Array{T,2}(i, j)
		return m
	end
end