module TestTimestepArrays

using Mimi
using Test

import Mimi:
    FixedTimestep, VariableTimestep, TimestepVector, TimestepMatrix, TimestepArray, next_timestep, hasvalue, 
    isuniform, first_period, last_period, first_and_step

# general variables
a = collect(reshape(1:16,4,4))

## quick check of isuniform
@test isuniform([]) == false
@test isuniform([1]) == true
@test isuniform([1,2,3]) == true
@test isuniform([1,2,3,5]) == false
@test isuniform(1) == true

@test first_and_step([2,3,4]) == (2,1)
@test first_and_step([1:2:10...]) == (1,2)

#------------------------------------------------------------------------------
# 1. Test TimestepVector - Fixed Timestep 
#------------------------------------------------------------------------------
years = collect(2000:1:2003)

#1a.  test constructor, lastindex, and length (with both 
# matching years and mismatched years)

x = TimestepVector{FixedTimestep{2000, 1}, Int}(a[:,3])
@test length(x) == 4
@test lastindex(x) == 4

#1b.  test hasvalue, getindex, and setindex! (with both matching years and
# mismatched years)

# TimestepValue and TimestepIndex Indexing
@test x[TimestepIndex(1)] == 9
@test x[TimestepIndex(1) + 1] == 10
@test x[TimestepIndex(4)] == 12
@test_throws ErrorException x[TimestepIndex(5)]

x[TimestepIndex(1)] = 100
@test x[TimestepIndex(1)] == 100
x[TimestepIndex(1)] = 9 # reset for later tests

@test x[TimestepValue(2000)] == 9
@test x[TimestepValue(2000; offset = 1)] == 10
@test x[TimestepValue(2000) + 1] == 10
@test_throws ErrorException x[TimestepValue(2005)]
@test_throws ErrorException x[TimestepValue(2004)+1]

x[TimestepValue(2000)] = 101
@test x[TimestepValue(2000)] == 101
x[TimestepValue(2000)] = 9 # reset for later tests

# AbstractTimestep Indexing
t = FixedTimestep{2001, 1, 3000}(1)

@test hasvalue(x, t)
@test !hasvalue(x, FixedTimestep{2000, 1, 2012}(10)) 
@test x[t] == 10

t2 = next_timestep(t)

@test x[t2] == 11

x[t2] = 99
@test x[t2] == 99

t3 = FixedTimestep{2000, 1, 2003}(1)
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

#------------------------------------------------------------------------------
# 2. Test TimestepVector - Variable Timestep 
#------------------------------------------------------------------------------

years = (2000, 2005, 2015, 2025)
x = TimestepVector{VariableTimestep{years}, Int}(a[:,3])

#2a.  test hasvalue, getindex, and setindex! (with both matching years and
# mismatched years)

# TimestepValue and TimestepIndex Indexing
@test x[TimestepIndex(1)] == 9
@test x[TimestepIndex(1) + 1] == 10
@test x[TimestepIndex(4)] == 12
@test_throws ErrorException x[TimestepIndex(5)]

x[TimestepIndex(1)] = 100
@test x[TimestepIndex(1)] == 100
x[TimestepIndex(1)] = 9 # reset

@test x[TimestepValue(2000)] == 9
@test x[TimestepValue(2000; offset = 1)] == 10
@test x[TimestepValue(2015)] == 11
@test x[TimestepValue(2015; offset = 1)] == 12
@test x[TimestepValue(2000) + 1] == 10
@test_throws ErrorException x[TimestepValue(2014)]
@test_throws ErrorException x[TimestepValue(2025)+1]

x[TimestepValue(2015)] = 100
@test x[TimestepValue(2015)] == 100
x[TimestepValue(2015)] = 11 # reset

# AbstractTimestep Indexing
y2 = Tuple([2005:5:2010; 2015:10:3000])
t = VariableTimestep{y2}()

@test hasvalue(x, t) 
@test !hasvalue(x, VariableTimestep{years}(10)) 
@test x[t] == 10

t2 =  next_timestep(t)

@test x[t2] == 11
#@test indices(x) == (2000:2003,) #may remove this function

x[t2] = 99
@test x[t2] == 99

t3 = VariableTimestep{years}()
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

#------------------------------------------------------------------------------
# 3. Test TimestepMatrix - Fixed Timestep 
#------------------------------------------------------------------------------
years = Tuple(2000:1:2003)

#3a.  test constructor (with both matching years 
# and mismatched years)

y = TimestepMatrix{FixedTimestep{2000, 1}, Int, 1}(a[:,1:2])

# TimestepValue and TimestepIndex Indexing
@test y[TimestepIndex(1), 1] == 1
@test y[TimestepIndex(1), 2] == 5
@test y[TimestepIndex(1) + 1, 1] == 2
@test y[TimestepIndex(4), 2] == 8
@test_throws ErrorException y[TimestepIndex(5), 2]

y[TimestepIndex(1), 1] = 100
@test y[TimestepIndex(1), 1] == 100
y[TimestepIndex(1), 1] = 1 # reset

@test y[TimestepValue(2000), 1] == 1
@test y[TimestepValue(2000), 2] == 5
@test y[TimestepValue(2001), :] == [2,6]
@test y[TimestepValue(2000; offset = 1), 1] == 2
@test y[TimestepValue(2000) + 1, 1] == 2
@test_throws ErrorException y[TimestepValue(2005), 1]
@test_throws ErrorException y[TimestepValue(2004)+1, 1]

y[TimestepValue(2000), 1] = 101
@test y[TimestepValue(2000), 1] == 101
y[TimestepValue(2000), 1] = 1 # reset

#3b.  test hasvalue, getindex, and setindex! (with both matching years and
# mismatched years)

# AbstractTimestep Indexing
t = FixedTimestep{2001, 1, 3000}(1)

@test hasvalue(y, t, 1) 
@test !hasvalue(y, FixedTimestep{2000, 1, 3000}(10), 1)
@test y[t,1] == 2
@test y[t,2] == 6

t2 = next_timestep(t)

@test y[t2,1] == 3
@test y[t2,2] == 7
 
y[t2, 1] = 5
@test y[t2, 1] == 5

t3 = FixedTimestep{2000, 1, 2005}(1)

@test y[t3, 1] == 1
@test y[t3, 2] == 5

y[t3, 1] = 10
@test y[t3,1] == 10

# Colon indexing 
y[:,:] = 11
@test y[:,:] == fill(11,4,2)

#3c.  interval wider than 1
z = TimestepMatrix{FixedTimestep{2000, 2}, Int, 1}(a[:,3:4])
t = FixedTimestep{1980, 2, 3000}(11)

@test z[t,1] == 9
@test z[t,2] == 13

t2 = next_timestep(t)
@test z[t2,1] == 10
@test z[t2,2] == 14


#------------------------------------------------------------------------------
# 4. Test TimestepMatrix - Variable Timestep 
#------------------------------------------------------------------------------

years = Tuple([2000:5:2005; 2015:10:2025])
y = TimestepMatrix{VariableTimestep{years}, Int, 1}(a[:,1:2])

#4a.  test hasvalue, getindex, setindex!, and lastindex (with both matching years and
# mismatched years)

# TimestepValue and TimestepIndex Indexing
@test y[TimestepIndex(1), 1] == 1
@test y[TimestepIndex(1), 2] == 5
@test y[TimestepIndex(1) + 1, 1] == 2
@test y[TimestepIndex(4), 2] == 8
@test_throws ErrorException y[TimestepIndex(5), 2]

y[TimestepIndex(1), 1] = 101
@test y[TimestepIndex(1), 1] == 101
y[TimestepIndex(1), 1] = 1 # reset

@test y[TimestepValue(2000), 1] == 1
@test y[TimestepValue(2000), 2] == 5
@test y[TimestepValue(2000; offset = 1), 1] == 2
@test y[TimestepValue(2000) + 1, 1] == 2
@test y[TimestepValue(2015), 1] == 3
@test y[TimestepValue(2015) + 1, 2] == 8
@test_throws ErrorException y[TimestepValue(2006), 1]
@test_throws ErrorException y[TimestepValue(2025)+1, 1]

y[TimestepValue(2015), 1] = 100
@test y[TimestepValue(2015), 1] == 100
y[TimestepValue(2015), 1] = 3 # reset

# AbstractTimestep Indexing
t = VariableTimestep{Tuple([2005:5:2010; 2015:10:3000])}()

@test hasvalue(y, t, 1) 
@test !hasvalue(y, VariableTimestep{years}(10)) 
@test y[t,1] == 2
@test y[t,2] == 6

t2 = next_timestep(t)

@test y[t2,1] == 3
@test y[t2,2] == 7
 
y[t2, 1] = 5
@test y[t2, 1] == 5

t3 = VariableTimestep{years}()

@test y[t3, 1] == 1
@test y[t3, 2] == 5

y[t3, 1] = 10
@test y[t3,1] == 10

# Colon indexing 
y[:,:] = 11
@test y[:,:] == fill(11,4,2)

#------------------------------------------------------------------------------
# 5. Test TimestepArray methods 
#------------------------------------------------------------------------------

# 3 dimensional array
years = Tuple([2000:5:2005; 2015:10:2025])
data = collect(reshape(1:64, 4, 4, 4))
arr_fixed = TimestepArray{FixedTimestep{2000, 5}, Int, 3, 1}(data)
arr_variable = TimestepArray{VariableTimestep{years}, Int, 3, 1}(data)

# Indexing with TimestepIndex

@test arr_fixed[TimestepIndex(1), 1, 1] == 1
@test arr_fixed[TimestepIndex(3), 3, 3] == 43
@test arr_variable[TimestepIndex(1), 1, 1] == 1
@test arr_variable[TimestepIndex(3), 3, 3] == 43

arr_fixed[TimestepIndex(1), 1, 1] = 101
arr_variable[TimestepIndex(1), 1, 1] = 101
@test arr_fixed[TimestepIndex(1), 1, 1] == 101
@test arr_variable[TimestepIndex(1), 1, 1] == 101
arr_fixed[TimestepIndex(1), 1, 1] = 1 # reset
arr_variable[TimestepIndex(1), 1, 1] = 1 # reset

@test_throws ErrorException arr_fixed[TimestepIndex(1)]
@test_throws ErrorException arr_variable[TimestepIndex(1)]

# Indexing with Array{TimestepIndex, N} (TODO_LFR)

@test arr_fixed[TimestepIndex.([1,3]), 1, 1] == [1, 3]
@test arr_variable[TimestepIndex.([2,4]), 1, 1] == [2,4]

# Indexing with TimestepValue

@test arr_fixed[TimestepValue(2000), 1, 1] == 1
@test arr_fixed[TimestepValue(2010), 3, 3] == 43
@test arr_variable[TimestepValue(2000), 1, 1] == 1
@test arr_variable[TimestepValue(2015), 3, 3] == 43

arr_fixed[TimestepValue(2000), 1, 1] = 101
arr_variable[TimestepValue(2000), 1, 1] = 101
@test arr_fixed[TimestepValue(2000), 1, 1] == 101
@test arr_variable[TimestepValue(2000), 1, 1] == 101
arr_fixed[TimestepValue(2000), 1, 1] = 1 # reset
arr_variable[TimestepValue(2000), 1, 1] = 1 # reset

@test_throws ErrorException arr_fixed[TimestepValue(2000)]
@test_throws ErrorException arr_variable[TimestepValue(2000)]

# Indexing with Array{TimestepValue, N} (TODO_LFR)

@test arr_fixed[TimestepValue.([2000, 2010]), 1, 1] == [1, 3]
@test arr_variable[TimestepValue.([2000, 2005, 2025]), 1, 1] == [1, 2,4]

# other methods
x_years = Tuple(2000:5:2015) #fixed
y_years = Tuple([2000:5:2005; 2015:10:2025]) #variable

x_vec = TimestepVector{FixedTimestep{2000, 5}, Int}(a[:,3]) 
x_mat = TimestepMatrix{FixedTimestep{2000, 5}, Int, 1}(a[:,1:2])
y_vec = TimestepVector{VariableTimestep{y_years}, Int}(a[:,3]) 
y_mat = TimestepMatrix{VariableTimestep{y_years}, Int, 1}(a[:,1:2])

@test first_period(x_vec) == first_period(x_mat) == x_years[1] 
@test first_period(y_vec) == first_period(y_mat) == y_years[1]
@test last_period(x_vec) == last_period(x_mat) == x_years[end] 
@test last_period(y_vec) == last_period(y_mat) == y_years[end]

@test size(x) == size(a[:,3])
@test size(y) == size(a[:,1:2])
@test size(y,2) == size(a[:,1:2],2)

@test ndims(x) == 1
@test ndims(y) == 2

@test eltype(x) == eltype(a) 
@test eltype(y) == eltype(a) 

fill!(x, 2)
fill!(y, 2)
@test x.data == fill(2, (4))
@test y.data == fill(2, (4, 2))

#------------------------------------------------------------------------------
# 6. Test that getindex for TimestepArrays doesn't allow access to `missing`
#       values during `run` that haven't been computed yet.
#------------------------------------------------------------------------------

@defcomp foo begin
    par = Parameter(index=[time])
    var = Variable(index=[time])
    function run_timestep(p, v, d, t)
        if is_last(t)
            v.var[t] = 0
        else
            v.var[t] = p.par[t+1]   # This is where the error will be thrown, if connected to an internal variable that has not yet been computed.
        end
    end 
end 

years = 2000:2010

m = Model()
set_dimension!(m, :time, years)
add_comp!(m, foo, :first)
add_comp!(m, foo, :second)
connect_param!(m, :second => :par, :first => :var)
set_param!(m, :first, :par, 1:length(years))

@test_throws MissingException run(m)

# Check broadcast assignment to underlying array
x = Mimi.TimestepVector{Mimi.FixedTimestep{2005,10}, Float64}(zeros(10))
x[:] .= 10
@test all(x.data .== 10)

#------------------------------------------------------------------------------
# 7. Test TimestepArrays with time not as the first dimension
#------------------------------------------------------------------------------

@defcomp gdp begin
    growth = Parameter(index=[regions, foo, time, 2])   # test that time is not first but not last
    gdp = Variable(index=[regions, foo, time, 2])
    gdp0 = Parameter(index=[regions, foo, 2])

    pgrowth = Parameter(index=[regions, 3, time])       # test time as last
    pop = Variable(index=[regions, 3, time])

    mat = Parameter(index=[regions, time])              # test time as last for a matrix
    mat2 = Variable(index=[regions, time])

    function run_timestep(p, v, d, ts)
        if is_first(ts)
            v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* p.gdp0
            v.pop[:, :, ts] = zeros(2, 3)
        else
            v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* v.gdp[:, :, ts-1, :]
            v.pop[:, :, ts] = v.pop[:, :, ts-1] .+ p.pgrowth[:, :, ts]
        end
        v.mat2[:, ts] = p.mat[:, ts]
    end
end

time_index = 2000:2100
regions = ["OECD","non-OECD"]
nsteps=length(time_index)

m = Model()
set_dimension!(m, :time, time_index)
set_dimension!(m, :regions, regions)
set_dimension!(m, :foo, 3)
add_comp!(m, gdp)
set_param!(m, :gdp, :gdp0, [3; 7] .* ones(length(regions), 3, 2))
set_param!(m, :gdp, :growth, [0.02; 0.03] .* ones(length(regions), 3, nsteps, 2))
set_leftover_params!(m, Dict{String, Any}([
    "pgrowth" => ones(length(regions), 3, nsteps),
    "mat" => rand(length(regions), nsteps)
]))
run(m)
w = explore(m)
close(w)

@test size(m[:gdp, :gdp]) == (length(regions), 3, length(time_index), 2)

@test all(!ismissing, m[:gdp, :gdp])
@test all(!ismissing, m[:gdp, :pop])
@test all(!ismissing, m[:gdp, :mat2])

end #module
