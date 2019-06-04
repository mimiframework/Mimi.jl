module TestTimestepArrays

using Mimi
using Test

import Mimi:
    FixedTimestep, VariableTimestep, TimestepVector, TimestepMatrix, next_timestep, hasvalue, 
    isuniform, first_period, last_period, first_and_step

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

x[1] = 101
@test x[1] == 101


#------------------------------------------------------------------------------
# 2. Test TimestepVector - Variable Timestep 
#------------------------------------------------------------------------------

years = (2000, 2005, 2015, 2025)
x = TimestepVector{VariableTimestep{years}, Int}(a[:,3])

#2a.  test hasvalue, getindex, and setindex! (with both matching years and
# mismatched years)

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

x[1] = 101
@test x[1] == 101


#------------------------------------------------------------------------------
# 3. Test TimestepMatrix - Fixed Timestep 
#------------------------------------------------------------------------------
years = Tuple(2000:1:2003)

#3a.  test constructor (with both matching years 
# and mismatched years)

y = TimestepMatrix{FixedTimestep{2000, 1}, Int}(a[:,1:2])

#3b.  test hasvalue, getindex, and setindex! (with both matching years and
# mismatched years)

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

y[:,:] = 11
@test all([y[i,1] == 11 for i in 1:4])
@test all([y[1,j] == 11 for j in 1:2])    

#3c.  interval wider than 1
z = TimestepMatrix{FixedTimestep{2000, 2}, Int}(a[:,3:4])
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
y = TimestepMatrix{VariableTimestep{years}, Int}(a[:,1:2])

#4a.  test hasvalue, getindex, setindex!, and lastindex (with both matching years and
# mismatched years)

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

y[:,:] = 11
@test all([y[i,1] == 11 for i in 1:4])
@test all([y[1,j] == 11 for j in 1:2])    


#------------------------------------------------------------------------------
# 5. Test TimestepArray methods 
#------------------------------------------------------------------------------

x_years = Tuple(2000:5:2015) #fixed
y_years = Tuple([2000:5:2005; 2015:10:2025]) #variable

x_vec = TimestepVector{FixedTimestep{2000, 5}, Int}(a[:,3]) 
x_mat = TimestepMatrix{FixedTimestep{2000, 5}, Int}(a[:,1:2])
y_vec = TimestepVector{VariableTimestep{y_years}, Int}(a[:,3]) 
y_mat = TimestepMatrix{VariableTimestep{y_years}, Int}(a[:,1:2])

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

end #module
