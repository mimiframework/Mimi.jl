using Mimi
using Base.Test

import Mimi:
    AbstractTimestep, Timestep, VariableTimestep, TimestepVector, 
    TimestepMatrix, TimestepArray, next_timestep, hasvalue, is_start, is_stop, 
    gettime

#####################################################
#  Test basic timestep functions for Fixed Timestep #
#####################################################

t = Timestep{1850, 10, 3000}(1)
@test is_start(t)
t1 = next_timestep(t)
#t2 = new_timestep(t1, 1860)
#@test is_start(t2)
#t3 = new_timestep(t2, 1840)
#@test t3.t == 3

t = Timestep{2000, 1, 2050}(51)
@test is_stop(t)
t = next_timestep(t)
@test_throws ErrorException next_timestep(t)

########################################################
#  Test basic timestep functions for Variable Timestep #
########################################################
years = tuple([2000:1:2024; 2025:5:2105]...)

t = VariableTimestep{years}()
@test is_start(t)

t = VariableTimestep{years}(41)
@test is_stop(t)
t = next_timestep(t)
@test_throws ErrorException next_timestep(t)

#########################################################
#  Test a model with components with different offsets  #
#########################################################

# we'll have Bar run from 2000 to 2010
# and Foo from 2005 to 2010

@defcomp Foo begin
    inputF = Parameter()
    output = Variable(index=[time])
    
    function run_timestep(p, v, d, ts)
        v.output[ts] = p.inputF + ts.t
    end
end

@defcomp Bar begin
    inputB = Parameter(index=[time])
    output = Variable(index=[time])
    
    function run_timestep(p, v, d, ts)      # TBD: Was ts::Timestep, but it's broken currently...
        if gettime(ts) < 2005
            v.output[ts] = p.inputB[ts]
        else
            v.output[ts] = p.inputB[ts] * ts.t
        end
    end
end

m = Model()
set_dimension!(m, :time, 2000:2010)

# test that you can only add components with start/final within model's time index range
@test_throws ErrorException addcomponent(m, Foo; start=1900)
@test_throws ErrorException addcomponent(m, Foo; stop=2100)

foo = addcomponent(m, Foo; start=2005) #offset for foo
bar = addcomponent(m, Bar)

set_parameter!(m, :Foo, :inputF, 5.)
set_parameter!(m, :Bar, :inputB, collect(1:11))

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
    
    function run_timestep(p, v, d, ts)
        v.output[ts] = p.inputF[ts]
    end
end

m2 = Model()
set_dimension!(m2, :time, 2000:2010)
bar = addcomponent(m2, Bar)
foo2 = addcomponent(m2, Foo2, start=2005) #offset for foo

set_parameter!(m2, :Bar, :inputB, collect(1:11))
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
    
    function run_timestep(p, v, d, ts)
        if gettime(ts) < 2005
            v.output[ts] = 0
        else
            v.output[ts] = p.inputB[ts] * ts.t
        end
    end
end

m3 = Model()

set_dimension!(m3, :time, 2000:2010)
addcomponent(m3, Foo, start=2005)
addcomponent(m3, Bar2)

set_parameter!(m3, :Foo, :inputF, 5.)
connectparameter(m3, :Bar2, :inputB, :Foo, :output)
run(m3)

@test length(m3[:Foo, :output]) == 6
@test length(m3[:Bar2, :inputB]) == 6
@test length(m3[:Bar2, :output]) == 11
