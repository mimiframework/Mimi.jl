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
    var2 = Variable(index=[time])
    par2 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp2, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var2[t] = p.par2[t]
end

@defcomp testcomp3 begin
    var3 = Variable(index=[time])
    par3 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp3, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var3[t] = p.par3[t]
end

par = collect(2015:5:2110)

addcomponent(my_model, testcomp1)
setindex(my_model, :time, collect(2015:5:2110))
setparameter(my_model, :testcomp1, :par1, par)
run(my_model)

#Regular getdataframe
dataframe = getdataframe(my_model, :testcomp1, :var1)
@test(dataframe[2] == par)
#Test trying to getdataframe from component that does not exist
@test_throws ErrorException getdataframe(my_model, :testcomp1, :var2)

#Expanded getdataframe
