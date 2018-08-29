module TestParameterTypes

using Mimi
using Base.Test

import Mimi: 
    external_params, update_external_param!, TimestepMatrix, TimestepVector, 
    ArrayModelParameter, ScalarModelParameter, FixedTimestep, reset_compdefs

reset_compdefs()

#
# Test that parameter type mismatches are caught
#
expr = @macroexpand @defcomp BadComp1 begin
    a = Parameter(index=[time, regions], default=[10, 11, 12])  # should be 2D default
    function run_timestep(p, v, d, t)
    end
end
@test_throws ErrorException eval(expr)

expr = @macroexpand @defcomp BadComp2 begin
    a = Parameter(default=[10, 11, 12])  # should be scalar default
    function run_timestep(p, v, d, t)
    end
end
@test_throws ErrorException eval(expr)


@defcomp MyComp begin
    a = Parameter(index=[time, regions], default=ones(101,3))
    b = Parameter(index=[time], default=1:101)
    c = Parameter(index=[regions])
    d = Parameter()
    e = Parameter(index=[four])
    f::Array{Float64, 2} = Parameter()
    g::Int = Parameter(default=10.0)    # value should be Int despite Float64 default
    h = Parameter(default=10)           # should be "numtype", despite Int default

    x = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.x[t, r] = 0
        end
    end
end

# Check that explicit number type for model works as expected
numtype = Float32
m = Model(numtype)

set_dimension!(m, :time, 2000:2100)
set_dimension!(m, :regions, 3)
set_dimension!(m, :four, 4)

add_comp!(m, MyComp)
# set_param!(m, :MyComp, :a, ones(101,3))
# set_param!(m, :MyComp, :b, 1:101)
set_param!(m, :MyComp, :c, [4,5,6])
set_param!(m, :MyComp, :d, 0.5)   # 32-bit float constant
set_param!(m, :MyComp, :e, [1,2,3,4])
set_param!(m, :MyComp, :f, [1.0 2.0; 3.0 4.0])

# THIS FAILS: Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}} != Array{Float64,2}
# set_param!(m, :MyComp, :f, reshape(1:16, 4, 4))

extpars = external_params(m)

@test isa(extpars[:a], ArrayModelParameter)
@test isa(extpars[:b], ArrayModelParameter)
@test isa(extpars[:c], ArrayModelParameter)
@test isa(extpars[:d], ScalarModelParameter)
@test isa(extpars[:e], ArrayModelParameter)
@test isa(extpars[:f], ScalarModelParameter) # note that :f is stored as a scalar parameter even though its values are an array

@test typeof(extpars[:a].values) == TimestepMatrix{FixedTimestep{2000, 1}, numtype}
@test typeof(extpars[:b].values) == TimestepVector{FixedTimestep{2000, 1}, numtype}
@test typeof(extpars[:c].values) == Array{numtype, 1}
@test typeof(extpars[:d].value) == numtype
@test typeof(extpars[:e].values) == Array{numtype, 1}
@test typeof(extpars[:f].value) == Array{Float64, 2}
@test typeof(extpars[:g].value) <: Int
@test typeof(extpars[:h].value) == numtype

# test updating parameters

@test_throws ErrorException update_external_param!(m, :a, 5) # expects an array
@test_throws ErrorException update_external_param!(m, :a, ones(101)) # wrong size
@test_throws ErrorException update_external_param!(m, :a, fill("hi", 101, 3)) # wrong type
update_external_param!(m, :a, Array{Int,2}(zeros(101, 3))) # should be able to convert from Int to Float

@test_throws ErrorException update_external_param!(m, :d, ones(5)) # wrong type; should be scalar
update_external_param!(m, :d, 5) # should work, will convert to float
@test extpars[:d].value == 5
@test_throws ErrorException update_external_param!(m, :e, 5) # wrong type; should be array
@test_throws ErrorException update_external_param!(m, :e, ones(10)) # wrong size
update_external_param!(m, :e, [4,5,6,7])

@test length(extpars) == 8
@test typeof(extpars[:a].values) == TimestepMatrix{FixedTimestep{2000, 1}, numtype}
@test typeof(extpars[:d].value) == numtype
@test typeof(extpars[:e].values) == Array{numtype, 1}


#------------------------------------------------------------------------------
# Test updating TimestepArrays with update_external_parameter
#------------------------------------------------------------------------------

using Mimi
using Base.Test
import Mimi: update_external_param!
@defcomp MyComp2 begin 
    x=Parameter(index=[time]) 
    y=Variable(index=[time])
    function run_timestep(p,v,d,t)
        v.y[t]=p.x[t]
    end
end

# 1. Test with Fixed Timesteps

m = Model()
set_dimension!(m, :time, 2000:2002)
add_comp!(m, MyComp2)
set_param!(m, :MyComp2, :x, [1, 2, 3])
set_dimension!(m, :time, 2001:2003)

update_external_param!(m, :x, [4, 5, 6], update_timesteps = false)
x = m.md.external_params[:x]
@test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{2000, 1, LAST} where LAST, Float64, 1}
@test x.values.data == [4., 5., 6.]
run(m)
@test m[:MyComp2, :y][1] == 5   # 2001
@test m[:MyComp2, :y][2] == 6   # 2002

update_external_param!(m, :x, [2, 3, 4], update_timesteps = true)
x = m.md.external_params[:x]
@test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{2001, 1, LAST} where LAST, Float64, 1}
@test x.values.data == [2., 3., 4.]
run(m)
@test m[:MyComp2, :y][1] == 2   # 2001
@test m[:MyComp2, :y][2] == 3   # 2002


# 2. Test with Variable Timesteps

m = Model()
set_dimension!(m, :time, [2000, 2005, 2020])
add_comp!(m, MyComp2)
set_param!(m, :MyComp2, :x, [1, 2, 3])
set_dimension!(m, :time, [2005, 2020, 2050])

update_external_param!(m, :x, [4, 5, 6], update_timesteps = false)
x = m.md.external_params[:x]
@test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2000, 2005, 2020)}, Float64, 1}
@test x.values.data == [4., 5., 6.]
run(m)
@test m[:MyComp2, :y][1] == 5   # 2005
@test m[:MyComp2, :y][2] == 6   # 2020

update_external_param!(m, :x, [2, 3, 4], update_timesteps = true)
x = m.md.external_params[:x]
@test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2005, 2020, 2050)}, Float64, 1}
@test x.values.data == [2., 3., 4.]
run(m)
@test m[:MyComp2, :y][1] == 2   # 2005
@test m[:MyComp2, :y][2] == 3   # 2020


end #module
