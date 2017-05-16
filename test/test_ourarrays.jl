using Mimi
using Base.Test

a = collect(reshape(1:16,4,4))

#####################
#  Test OurTVector  #
#####################

x = Mimi.OurTVector{Int, 2000}(a[:,3])
t = Mimi.Timestep{2001,3000}(2001)

@test x[t] == 10

t2 = Mimi.getnexttimestep(t)

@test x[t2] == 11

#####################
#  Test OurTMatrix  #
#####################

y = Mimi.OurTMatrix{Int, 2000}(a[:,1:2])

@test y[t,1] == 2
@test y[t,2] == 6

@test y[t2,1] == 3
@test y[t2,2] == 7
