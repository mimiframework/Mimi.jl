using Mimi
using Base.Test

a = collect(reshape(1:16,4,4))

#####################
#  Test OurTVector  #
#####################

x = Mimi.OurTVector{Int, 2000, 1}(a[:,3])
t = Mimi.Timestep{2001, 1, 3000}(2001)

@test x[t] == 10

t2 = Mimi.getnexttimestep(t)

@test x[t2] == 11

@test Mimi.indices(x) == (2000:2003,)
@test Mimi.linearindices(x) == Base.OneTo(4)

#####################
#  Test OurTMatrix  #
#####################

y = Mimi.OurTMatrix{Int, 2000, 1}(a[:,1:2])

@test y[t,1] == 2
@test y[t,2] == 6

@test y[t2,1] == 3
@test y[t2,2] == 7

@test Mimi.indices(y) == (2000:2003, 1:2)
@test Mimi.length(linearindices(y)) == 8

######################################
#  Test with intervals wider than 1  #
######################################

z = Mimi.OurTMatrix{Int, 1850, 10}(a[:,3:4])
t = Timestep{1800,10,3000}(1850)
@test z[t,1] == 9
@test z[t,2] == 13

t2 = Mimi.getnexttimestep(t)
@test z[t2,1] == 10
@test z[t2,2] == 14
