using Mimi
using Base.Test

###################################
#  Test basic timestep functions  #
###################################

t = Timestep{1850, 10, 3000}(1)
@test isfirsttimestep(t)
t1 = Mimi.getnexttimestep(t)
t2 = Mimi.getnewtimestep(t1, 1860)
@test isfirsttimestep(t2)
t3 = Mimi.getnewtimestep(t2, 1840)
@test t3.t == 3

t = Timestep{2000, 1, 2050}(51)
@test isfinaltimestep(t)
t = Mimi.getnexttimestep(t)
@test_throws ErrorException Mimi.getnexttimestep(t)

#########################################################
#  Test a model with components with different offsets  #
#########################################################

# we'll have Bar run from 2000 to 2010
# and Foo from 2005 to 2010

@defcomp Foo begin
    inputF = Parameter()
    output = Variable(index=[time])
end

function run_timestep(c::Foo, ts::Timestep)
    c.Variables.output[ts] = c.Parameters.inputF + ts.t
end

@defcomp Bar begin
    inputB = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Bar, ts::Timestep)
    if Mimi.gettime(ts) < 2005
        c.Variables.output[ts] = c.Parameters.inputB[ts]
    else
        c.Variables.output[ts] = c.Parameters.inputB[ts] * ts.t
    end
end

m = Model()
setindex(m, :time, 2000:2010)
# test that you can only add components with start/final within model's time index range
@test_throws ErrorException addcomponent(m, Foo, start=1900)
@test_throws ErrorException addcomponent(m, Foo, final=2100)

foo = addcomponent(m, Foo, start=2005) #offset for foo
bar = addcomponent(m, Bar)

setparameter(m, :Foo, :inputF, 5.)
setparameter(m, :Bar, :inputB, collect(1:11))

run(m)

@test length(m[:Foo, :output])==6
@test length(m[:Bar, :output])==11

for i in 1:6
    @test m[:Foo, :output][i] == 5+i
end

for i in 1:5
    @test m[:Bar, :output][i] == i
end

for i in 6:11
    @test m[:Bar, :output][i] == i*i
end

##################################################
#  Now build a model with connecting components  #
##################################################

@defcomp Foo2 begin
    inputF = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Foo2, ts::Timestep)
    c.Variables.output[ts] = c.Parameters.inputF[ts]
end

m2 = Model()
setindex(m2, :time, 2000:2010)
bar = addcomponent(m2, Bar)
foo2 = addcomponent(m2, Foo2, start=2005) #offset for foo

setparameter(m2, :Bar, :inputB, collect(1:11))
connectparameter(m2, :Foo2, :inputF, :Bar, :output)

run(m2)

for i in 1:6
    @test m2[:Foo2, :output][i] == (i+5)^2
end

#########################################
#  Connect them in the other direction  #
#########################################

@defcomp Bar2 begin
    inputB = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Bar2, ts::Timestep)
    # c.Variables.output[ts] = c.Parameters.input[ts] * ts.t
    if Mimi.gettime(ts) < 2005
        c.Variables.output[ts] = 0
    else
        c.Variables.output[ts] = c.Parameters.inputB[ts] * ts.t
    end
end

m3 = Model()
setindex(m3, :time, 2000:2010)
addcomponent(m3, Foo, start=2005)
addcomponent(m3, Bar2)
setparameter(m3, :Foo, :inputF, 5.)
connectparameter(m3, :Bar2, :inputB, :Foo, :output)
run(m3)

@test length(m3[:Foo, :output])==6
@test length(m3[:Bar2, :inputB])==6
@test length(m3[:Bar2, :output])==11
