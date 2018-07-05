using Mimi
using Base.Test

reset_compdefs()

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

# Test running before model built
@test_throws ErrorException dataframe = getdataframe(my_model, :testcomp1, :var1)

# Now run model
run(my_model)

# Regular getdataframe
dataframe = getdataframe(my_model, :testcomp1, :var1)
@test(dataframe[2] == par)

# Test trying to getdataframe from component that does not exist
@test_throws ErrorException getdataframe(my_model, :testcomp1, :var2)

#
# Test with > 2 dimensions
#
new_model = Model()

@defcomp testcomp4 begin
    par1 = Parameter(index=[time, regions, rates])
    var3 = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
    end
end

years   = 2015:5:2020
regions = [:reg1, :reg2]
rates   = [0.025, 0.05]

set_dimension!(new_model, :time, years)
set_dimension!(new_model, :regions, regions)
set_dimension!(new_model, :rates, rates)

data = Array{Int}(length(years), length(regions), length(rates))
data[:] = 1:(length(years) * length(regions) * length(rates))

addcomponent(new_model, testcomp4)
set_parameter!(new_model, :testcomp4, :par1, data)

# TBD: This doesn't work; needs TimestepArray or the like to handle > 2 dimensions
# run(new_model)
