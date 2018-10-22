using Mimi

_default_years = 2000:2100
_default_regions = [:A, :B]

function run_getindex(; years = collect(_default_years), regions = _default_regions)
    # Test with one scalar parameter, one 1-D timestep array, and one 2-D timestep array
    types = [Mimi.ScalarModelParameter{Float64}, _get_timesteparray_type(years, 1), _get_timesteparray_type(years, 2)]

    names = [:d1, :d2, :d3]
    values = [
        types[1](4.),
        types[2](Array{Union{Missing, Float64}, 1}(rand(length(years)))), 
        types[3](Array{Union{Missing, Float64}, 2}(rand(length(years), length(regions))))
        ]

    datum = NamedTuple{(names...,), Tuple{types...,}}(values)
    
    clock = _get_clock(years)

    while ! Mimi.finished(clock)
        ts = Mimi.timestep(clock)
        _run_timestep(datum, ts)
        Mimi.advance(clock)
    end 
end 

function _run_timestep(datum::NamedTuple, ts)
    datum.d1
    datum.d2[ts]
    datum.d3[ts, :]
    nothing
end 

function _get_timesteparray_type(years, num_dims, dtype=Float64)
    if Mimi.isuniform(years)
        first, stepsize = Mimi.first_and_step(years)
        T = Mimi.TimestepArray{Mimi.FixedTimestep{first, stepsize}, Union{dtype, Missing}, num_dims}
    else
        T = Mimi.TimestepArray{Mimi.VariableTimestep{(years...,)}, Union{dtype, Missing}, num_dims}
    end
    return T
end 

function _get_clock(years)
    if Mimi.isuniform(years)
        last = years[end]
        first, stepsize = Mimi.first_and_step(years)
        return Mimi.Clock{Mimi.FixedTimestep}(first, stepsize, last)
    else
        last_index = findfirst(isequal(last), years)
        times = (years[1:last_index]...,)
        return Mimi.Clock{Mimi.VariableTimestep}(times)
    end
end