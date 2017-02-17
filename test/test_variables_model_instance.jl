using Mimi
using Base.Test

my_model = Model()

@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    var2 = Variable(index=[time])
    par1 = Parameter(index=[time])
end

function run_timestep(tc1::testcomp1, t::Int)
    v = tc1.Variables
    p = tc1.Parameters
    v.var1[t] = p.par1[t]
end

par = collect(2015:5:2110)

addcomponent(my_model, testcomp1)
setindex(my_model, :time, collect(2015:5:2110))
setparameter(my_model, :testcomp1, :par1, par)
run(my_model);
#NOTE: this variables function does NOT take in Nullable instances
@test (variables(get(my_model.mi), :testcomp1) == [:var1, :var2])