using Mimi
using Base.Test

import Mimi:
    Timestep, TimestepVector, TimestepMatrix, next_timestep, hasvalue, 
    get_timestep_instance

a = collect(reshape(1:16,4,4))

##########################################
#1. Test TimestepVector - Fixed Timestep #
##########################################
years = tuple(collect(2000:1:2005)...)

#1a.  test get_timestep_instance, constructor, endof, and length (with both 
# matching years and mismatched years)

i = get_timestep_instance(Int, years, 1, a[:,3])
x = TimestepVector{Int, years}(a[:,3])
@test typeof(i) == typeof(x)
@test length(x) == 4

#1b.  test hasvalue, getindex, and setindex (with both matching years and
# mismatched years)

t = Timestep{2001, 1, 3000}(1)

@test hasvalue(x, t) #failing
@test !hasvalue(x, Timestep{2000, 1, 2012}(10)) #failing
@test x[t] == 10
@test endof(x) ==4

t2 = Mimi.next_timestep(t)

@test x[t2] == 11
#@test indices(x) == (2000:2003,) #may remove this function

x[t2] = 99
@test x[t2] == 99

t3 = Timestep{2000, 1, 2005}(1)
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

##############################################
# 2. Test TimestepVector - Variable Timestep #
##############################################

years = tuple([2000:5:2005; 2015:10:2025]...)

#1a.  test get_timestep_instance, constructor, endof, and length (with both 
# matching years and mismatched years)

i = get_timestep_instance(Int, years, 1, a[:,3])
x = TimestepVector{Int, years}(a[:,3])
@test typeof(i) == typeof(x)
@test length(x) == 4
@test endof(x) == 4

#1b.  test hasvalue, getindex, setindex, and (with both matching years and
# mismatched years)

t = VariableTimestep{tuple([2005:5:2010; 2015:10:3000]...)}()

@test hasvalue(x, t) #failing
@test !hasvalue(x, Timestep{2000, 1, 2012}(10)) #failing
@test x[t] == 10

t2 = Mimi.next_timestep(t)

@test x[t2] == 11
#@test indices(x) == (2000:2003,) #may remove this function

x[t2] = 99
@test x[t2] == 99

t3 = VariableTimestep{years}()
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

###########################################
# 3. Test TimestepMatrix - Fixed Timestep #
###########################################
years = tuple([2000:5:2005; 2015:10:2025]...)

#1a.  test get_timestep_instance, and constructor (with both matching years 
# and mismatched years)

i = get_timestep_instance(Int, years, 2, a[:,1:2])
y = TimestepMatrix{Int, years}(a[:,1:2])
@test typeof(i) == typeof(y)

#1b.  test hasvalue, getindex, and setindex (with both matching years and
# mismatched years)

t = Timestep{2001, 1, 3000}(1)

@test hasvalue(y, t, 1) #failing
@test !hasvalue(y, Timestep{2000, 1, 3000}(10), 1) #failing
@test y[t,1] == 2
@test y[t,2] == 6

t2 = Mimi.next_timestep(t)

@test y[t2,1] == 3
@test y[t2,2] == 7
 
y[t2, 1] = 5
@test y[t2, 1] == 5

t3 = Timestep{2000, 1, 2005}(1)

@test y[t3, 1] == 1
@test y[t3, 2] == 5

y[t3, 1] = 10
@test y[t3,1] == 10

#@test indices(y) == (2000:2003, 1:2) 

##############################################
# 4. Test TimestepMatrix - Variable Timestep #
##############################################

years = tuple([2000:5:2005; 2015:10:2025]...)
y = TimestepMatrix{Int, years}(a[:,1:2])

#1b.  test hasvalue, getindex, setindex, and endof (with both matching years and
# mismatched years)

t = VariableTimestep{tuple([2005:5:2010; 2015:10:3000]...)}()

@test hasvalue(y, t, 1) #failing
@test !hasvalue(y, Timestep{2000, 1, 3000}(10), 1) #failing
@test y[t,1] == 2
@test y[t,2] == 6

t2 = Mimi.next_timestep(t)

@test y[t2,1] == 3
@test y[t2,2] == 7
 
y[t2, 1] = 5
@test y[t2, 1] == 5

t3 = VariableTimestep{years}()

@test y[t3, 1] == 1
@test y[t3, 2] == 5

y[t3, 1] = 10
@test y[t3,1] == 10

