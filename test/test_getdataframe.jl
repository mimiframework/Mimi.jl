using Mimi
using Base.Test

my_model = Model()

#Testing that you cannot add two components of the same name
@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp testcomp2 begin
    var2 = Variable(index=[time])
    par2 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var2[t] = p.par2[t]
    end
end

@defcomp testcomp3 begin
    var3 = Variable(index=[time])
    par3 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var3[t] = p.par3[t]
    end
end

par = collect(2015:5:2110)

set_dimension!(my_model, :time, 2015:5:2110)
addcomponent(my_model, testcomp1)
set_parameter!(my_model, :testcomp1, :par1, par)
run(my_model)

# Regular getdataframe
dataframe = getdataframe(my_model, :testcomp1, :var1)
@test(dataframe[2] == par)

# Test trying to getdataframe from component that does not exist
@test_throws ErrorException getdataframe(my_model, :testcomp1, :var2)
