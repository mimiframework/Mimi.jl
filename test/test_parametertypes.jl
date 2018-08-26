using Mimi
using Base.Test

import Mimi: 
    external_params, update_external_param, TimestepMatrix, TimestepVector, 
    ArrayModelParameter, ScalarModelParameter, FixedTimestep

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
@test_throws ErrorException update_external_param(m, :a, 5) #expects an array
@test_throws ErrorException update_external_param(m, :a, ones(101)) #wrong size
@test_throws ErrorException update_external_param(m, :a, fill("hi", 101, 3)) #wrong type
update_external_param(m, :a, zeros(101,3))

@test_throws ErrorException update_external_param(m, :d, ones(5)) #wrong type; should be scalar
update_external_param(m, :d, 5) # should work, will convert to float
@test_throws ErrorException update_external_param(m, :e, 5) #wrong type; should be array
@test_throws ErrorException update_external_param(m, :e, ones(10)) #wrong size
update_external_param(m, :e, [4,5,6,7])

@test length(extpars) == 8
@test typeof(extpars[:a].values) == TimestepMatrix{FixedTimestep{2000, 1}, numtype}
@test typeof(extpars[:d].value) == numtype
@test typeof(extpars[:e].values) == Array{numtype, 1}
