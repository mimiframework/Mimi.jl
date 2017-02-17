
using Mimi
using Base.Test

my_model = Model()

#Testing that you cannot add two components of the same name
@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp1, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var1[t] = p.par1[t]
end

@defcomp testcomp2 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp2, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var1[t] = p.par1[t]
end

@defcomp testcomp3 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp3, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var1[t] = p.par1[t]
end

println("~~Starting component_ordering tests~~")
addcomponent(my_model, testcomp1)
@test_throws ErrorException addcomponent(my_model, testcomp1)
#Testing to catch adding component twice
@test_throws ErrorException addcomponent(my_model, testcomp1)
#Testing to catch if before or after does not exist
@test_throws ErrorException addcomponent(my_model, testcomp2, before=testcomp3)
@test_throws ErrorException addcomponent(my_model, testcomp2, after=testcomp3)
println("~~Passed all component_ordering tests~~")
