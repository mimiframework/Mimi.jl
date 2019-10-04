module TestParameterTypes

using Mimi
using Test

import Mimi: 
    external_params, external_param, TimestepMatrix, TimestepVector, 
    ArrayModelParameter, ScalarModelParameter, FixedTimestep

#
# Test that parameter type mismatches are caught
#
expr = :(
    @defcomp BadComp1 begin
        a = Parameter(index=[time, regions], default=[10, 11, 12])  # should be 2D default
        function run_timestep(p, v, d, t)
        end
    end
)
@test_throws LoadError eval(expr)

expr = :(
    @defcomp BadComp2 begin
        a = Parameter(default=[10, 11, 12])  # should be scalar default
        function run_timestep(p, v, d, t)
        end
    end
)
@test_throws LoadError eval(expr)


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
arrtype = Union{Missing, numtype}

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

@test typeof(extpars[:a].values) == TimestepMatrix{FixedTimestep{2000, 1}, arrtype, 1}
@test typeof(extpars[:b].values) == TimestepVector{FixedTimestep{2000, 1}, arrtype}
@test typeof(extpars[:c].values) == Array{arrtype, 1}
@test typeof(extpars[:d].value) == numtype
@test typeof(extpars[:e].values) == Array{arrtype, 1}
@test typeof(extpars[:f].value) == Array{Float64, 2}
@test typeof(extpars[:g].value) <: Int
@test typeof(extpars[:h].value) == numtype

# test updating parameters
@test_throws ErrorException update_param!(m, :a, 5) # expects an array
@test_throws ErrorException update_param!(m, :a, ones(101)) # wrong size
@test_throws ErrorException update_param!(m, :a, fill("hi", 101, 3)) # wrong type
update_param!(m, :a, Array{Int,2}(zeros(101, 3))) # should be able to convert from Int to Float

@test_throws ErrorException update_param!(m, :d, ones(5)) # wrong type; should be scalar
update_param!(m, :d, 5) # should work, will convert to float
@test extpars[:d].value == 5
@test_throws ErrorException update_param!(m, :e, 5) # wrong type; should be array
@test_throws ErrorException update_param!(m, :e, ones(10)) # wrong size
update_param!(m, :e, [4,5,6,7])

@test length(extpars) == 8
@test typeof(extpars[:a].values) == TimestepMatrix{FixedTimestep{2000, 1}, arrtype, 1}
@test typeof(extpars[:d].value) == numtype
@test typeof(extpars[:e].values) == Array{arrtype, 1}


#------------------------------------------------------------------------------
# Test updating TimestepArrays with update_param!
#------------------------------------------------------------------------------

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
add_comp!(m, MyComp2) # ; first=2000, last=2002)
set_param!(m, :MyComp2, :x, [1, 2, 3])

# N.B. `first` and `last` are now disabled.
# Can't move last beyond last for a component
# @test_throws ErrorException set_dimension!(m, :time, 2001:2003)

set_dimension!(m, :time, 2001:2002)

update_param!(m, :x, [4, 5, 6], update_timesteps = false)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{2000, 1, LAST} where LAST, Union{Missing,Float64}, 1}
@test x.values.data == [4., 5., 6.]
# TBD: this fails, but I'm not sure how it's supposed to behave. It says:
# (ERROR: BoundsError: attempt to access 3-element Array{Float64,1} at index [4])
# run(m)
# @test m[:MyComp2, :y][1] == 5   # 2001
# @test m[:MyComp2, :y][2] == 6   # 2002

update_param!(m, :x, [2, 3], update_timesteps = true)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{2001, 1, LAST} where LAST, Union{Missing,Float64}, 1}
@test x.values.data == [2., 3.]
run(m)
@test m[:MyComp2, :y][1] == 2   # 2001
@test m[:MyComp2, :y][2] == 3   # 2002


# 2. Test with Variable Timesteps

m = Model()
set_dimension!(m, :time, [2000, 2005, 2020])

@test_logs(
    (:warn, "add_comp!: Keyword arguments 'first' and 'last' are currently disabled."),
    add_comp!(m, MyComp2; first=2000, last=2020)
)
set_param!(m, :MyComp2, :x, [1, 2, 3])

set_dimension!(m, :time, [2005, 2020, 2050])

update_param!(m, :x, [4, 5, 6], update_timesteps = false)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2000, 2005, 2020)}, Union{Missing,Float64}, 1}
@test x.values.data == [4., 5., 6.]
#run(m)
#@test m[:MyComp2, :y][1] == 5   # 2005
#@test m[:MyComp2, :y][2] == 6   # 2020

update_param!(m, :x, [2, 3, 4], update_timesteps = true)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2005, 2020, 2050)}, Union{Missing,Float64}, 1}
@test x.values.data == [2., 3., 4.]
run(m)
@test m[:MyComp2, :y][1] == 2   # 2005
@test m[:MyComp2, :y][2] == 3   # 2020


# 3. Test updating from a dictionary

m = Model()
set_dimension!(m, :time, [2000, 2005, 2020])
add_comp!(m, MyComp2)
set_param!(m, :MyComp2, :x, [1, 2, 3])
    
set_dimension!(m, :time, [2005, 2020, 2050])

update_params!(m, Dict(:x=>[2, 3, 4]), update_timesteps = true)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2005, 2020, 2050)}, Union{Missing,Float64}, 1}
@test x.values.data == [2., 3., 4.]
run(m)
@test m[:MyComp2, :y][1] == 2   # 2005
@test m[:MyComp2, :y][2] == 3   # 2020
@test m[:MyComp2, :y][3] == 4   # 2050


# 4. Test updating the time index to a different length

m = Model()
set_dimension!(m, :time, 2000:2002)     # length 3
add_comp!(m, MyComp2)
set_param!(m, :MyComp2, :x, [1, 2, 3])

set_dimension!(m, :time, 1999:2003)     # length 5

@test_throws ErrorException update_param!(m, :x, [2, 3, 4, 5, 6], update_timesteps = false)
update_param!(m, :x, [2, 3, 4, 5, 6], update_timesteps = true)
x = external_param(m.md, :x)
@test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{1999, 1, LAST} where LAST, Union{Missing,Float64}, 1}
@test x.values.data == [2., 3., 4., 5., 6.]

run(m)
@test m[:MyComp2, :y] == [2., 3., 4., 5., 6.]

# 5. Test all the warning and error cases

@defcomp MyComp3 begin 
    regions=Index()
    x=Parameter(index=[time])       # One timestep array parameter
    y=Parameter(index=[regions])    # One non-timestep array parameter
    z=Parameter()                   # One scalar parameter
end 

m = Model()                             # Build the model
set_dimension!(m, :time, 2000:2002)     # Set the time dimension
set_dimension!(m, :regions, [:A, :B])
add_comp!(m, MyComp3)
set_param!(m, :MyComp3, :x, [1, 2, 3])
set_param!(m, :MyComp3, :y, [10, 20])
set_param!(m, :MyComp3, :z, 0)

@test_throws ErrorException update_param!(m, :x, [1, 2, 3, 4]) # Will throw an error because size
@test_throws ErrorException update_param!(m, :y, [10, 15], update_timesteps=true) # Not a timestep array
update_param!(m, :y, [10, 15])
@test external_param(m.md, :y).values == [10., 15.]
@test_throws ErrorException update_param!(m, :z, 1, update_timesteps=true) # Scalar parameter
update_param!(m, :z, 1)
@test external_param(m.md, :z).value == 1

# Reset the time dimensions
set_dimension!(m, :time, 2005:2007)

update_params!(m, Dict(:x=>[3,4,5], :y=>[10,20], :z=>0), update_timesteps=true) # Won't error when updating from a dictionary

@test external_param(m.md, :x).values isa Mimi.TimestepArray{Mimi.FixedTimestep{2005,1},Union{Missing,Float64},1}
@test external_param(m.md, :x).values.data == [3.,4.,5.]
@test external_param(m.md, :y).values == [10.,20.]
@test external_param(m.md, :z).value == 0

end #module
