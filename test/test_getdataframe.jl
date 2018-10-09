module TestGetDataframe

using Mimi
using Test

import Mimi:
    reset_compdefs, _load_dataframe

reset_compdefs()

#
# Test with > 2 dimensions
#

my_model = Model()

@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    par_scalar = Parameter()
    
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
add_comp!(my_model, testcomp1)
set_param!(my_model, :testcomp1, :par1, par)
set_param!(my_model, :testcomp1, :par_scalar, 5.)

# Test running before model built
@test_throws ErrorException dataframe = getdataframe(my_model, :testcomp1, :var1)

# Now run model
run(my_model)

# Regular getdataframe
dataframe = getdataframe(my_model, :testcomp1, :var1)
@test(dataframe[2] == par)

# Test trying to getdataframe from component that does not exist
@test_throws ErrorException getdataframe(my_model, :testcomp1, :var2)

# Test trying to load an item into an existing dataframe where that item key already exists
@test_throws ErrorException _load_dataframe(my_model, :testcomp1, :var1, dataframe)

# Test trying to load a dataframe for a scalar
@test_throws ErrorException _load_dataframe(my_model, :testcomp1, :par_scalar, dataframe)

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

data = Array{Int}(undef, length(years), length(regions), length(rates))
data[:] = 1:(length(years) * length(regions) * length(rates))

add_comp!(new_model, testcomp4)
set_param!(new_model, :testcomp4, :par1, data)

run(new_model)

df = getdataframe(new_model, :testcomp4, :par1)
@test size(df) == (8, 4)

# Test trying to combine two items with different dimensions into one dataframe
@test_throws ErrorException getdataframe(new_model, Pair(:testcomp4, :par1), Pair(:testcomp4, :var3))

end #module
