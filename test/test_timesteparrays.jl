using Mimi
using Base.Test

import Mimi:
    Timestep, TimestepVector, TimestepMatrix, next_timestep, hasvalue, 
    get_timestep_instance

a = collect(reshape(1:16,4,4))

#####################
#  Test TimestepVector - Fixed Timestep#
#####################
years = tuple(collect(2000:1:2005)...)

i = get_timestep_instance(Int, years, 1, a[:,3])
x = TimestepVector{Int, years}(a[:,3])
@test typeof(i) == typeof(x)
@test length(x) == 4

t = Timestep{2001, 1, 3000}(1)

@test hasvalue(x, t) #failing
@test !hasvalue(x, Timestep{2000, 1, 2012}(10)) #failing
@test x[t] == 10
@test endof(x) ==4

t2 = Mimi.next_timestep(t)

@test x[t2] == 11
#@test indices(x) == (2000:2003,)

x[t2] = 99
@test x[t2] == 99

t3 = Timestep{2000, 1, 2005}(1)
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

#####################
#  Test TimestepVector - Variable Timestep#
#####################
years = tuple([2000:5:2005; 2015:10:2025]...)

i = get_timestep_instance(Int, years, 1, a[:,3])
x = TimestepVector{Int, years}(a[:,3])
@test typeof(i) == typeof(x)
@test length(x) == 4
@test endof(x) ==4

t = VariableTimestep{tuple([2005:5:2010; 2015:10:3000]...)}()

@test hasvalue(x, t) #failing
@test !hasvalue(x, Timestep{2000, 1, 2012}(10)) #failing
@test x[t] == 10

t2 = Mimi.next_timestep(t)

@test x[t2] == 11
#@test indices(x) == (2000:2003,)

x[t2] = 99
@test x[t2] == 99

t3 = VariableTimestep{years}()
@test x[t3] == 9

x[t3] = 100
@test x[t3] == 100

#####################
#  Test TimestepMatrix  - Fixed Timestep#
#####################

y = TimestepMatrix{Int, 2000, 1}(a[:,1:2])

@test hasvalue(y, t, 1)
@test !hasvalue(y, Timestep{2000, 1, 3000}(10), 1)
@test y[t,1] == 2
@test y[t,2] == 6

@test y[t2,1] == 3
@test y[t2,2] == 7

@test y[t3, 1] == 1
@test y[t3, 2] == 5

@test indices(y) == (2000:2003, 1:2)


#####################
#  Test TimestepMatrix  - Variable Timestep#
#####################

######################################
#  Test with intervals wider than 1  #
######################################

z = TimestepMatrix{Int, 1850, 10}(a[:,3:4]) # duration of 10
t = Timestep{1800,10,3000}(6)
@test z[t,1] == 9
@test z[t,2] == 13

t2 = next_timestep(t)
@test z[t2,1] == 10
@test z[t2,2] == 14
