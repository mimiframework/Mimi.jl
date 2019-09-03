module TestGetDataframe

using Mimi
using Test

import Mimi:
    reset_compdefs, _load_dataframe

reset_compdefs()

#------------------------------------------------------------------------------
#   1. Test with 1 dimension
#------------------------------------------------------------------------------

model1 = Model()

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

years = collect(2015:5:2110)
late_first = 2030
early_last = 2100

set_dimension!(model1, :time, years)
add_comp!(model1, testcomp1)
set_param!(model1, :testcomp1, :par1, years)
set_param!(model1, :testcomp1, :par_scalar, 5.)
add_comp!(model1, testcomp2; first = late_first, last = early_last)
set_param!(model1, :testcomp2, :par2, late_first:5:early_last)


# Test running before model built
@test_throws ErrorException df = getdataframe(model1, :testcomp1, :var1)

# Now run model
run(model1)

# Test trying to load a dataframe for a scalar parameter
@test_throws ErrorException getdataframe(model1, :testcomp1, :par_scalar)

# Test trying to getdataframe from a variable that does not exist in the component
@test_throws ErrorException getdataframe(model1, :testcomp1, :var2)

# Regular getdataframe
df = getdataframe(model1, :testcomp1=>:var1, :testcomp1=>:par1, :testcomp2=>:var2, :testcomp2=>:par2)
dim = Mimi.dimension(model1, :time)
@test df.var1 == df.par1 == years
@test all(ismissing, df.var2[1 : dim[late_first]-1])
@test all(ismissing, df.par2[1 : dim[late_first]-1])
@test df.var2[dim[late_first] : dim[early_last]] == df.par2[dim[late_first] : dim[early_last]] == late_first:5:early_last
@test all(ismissing, df.var2[dim[years[end]] : dim[early_last]])
@test all(ismissing, df.par2[dim[years[end]] : dim[early_last]])

# Test trying to load an item into an existing dataframe where that item key already exists
@test_throws ErrorException _load_dataframe(model1, :testcomp1, :var1, df)


#------------------------------------------------------------------------------
#   2. Test with > 2 dimensions
#------------------------------------------------------------------------------

@defcomp testcomp3 begin
    par3 = Parameter(index=[time, regions, rates])
    var3 = Variable(index=[time])
end

regions = [:reg1, :reg2]
rates   = [0.025, 0.05]

# A. Simple case where component has same time length as model

model2 = Model()

set_dimension!(model2, :time, years)
set_dimension!(model2, :regions, regions)
set_dimension!(model2, :rates, rates)

data = Array{Int}(undef, length(years), length(regions), length(rates))
data[:] = 1:(length(years) * length(regions) * length(rates))

add_comp!(model2, testcomp3)
set_param!(model2, :testcomp3, :par3, data)

run(model2)

df2 = getdataframe(model2, :testcomp3, :par3)
@test size(df2) == (length(data), 4)

# Test trying to combine two items with different dimensions into one dataframe
@test_throws ErrorException getdataframe(model2, Pair(:testcomp3, :par3), Pair(:testcomp3, :var3))


# B. Test with shorter time than model 

model3 = Model()
set_dimension!(model3, :time, years)
set_dimension!(model3, :regions, regions)
set_dimension!(model3, :rates, rates)
add_comp!(model3, testcomp3; first = late_first, last = early_last)

par3 = Array{Float64}(undef, length(late_first:5:early_last), length(regions), length(rates))
par3[:] = 1:(length(late_first:5:early_last) * length(regions) * length(rates))
set_param!(model3, :testcomp3, :par3, par3)
run(model3)

df3 = getdataframe(model3, :testcomp3=>:par3)
@test size(df3) == (length(rates)*length(regions)*length(years), 4)

# Test that times outside the component's time span are padded with `missing` values
@test all(ismissing, df3.par3[1 : (length(rates)*length(regions)*(dim[late_first]-1))])
@test all(ismissing, df3.par3[end - (length(rates)*length(regions)*(dim[end]-dim[early_last]))+1: end])

end #module
