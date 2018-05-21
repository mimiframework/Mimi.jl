using Mimi
using Base.Test

import Mimi: 
    external_params, update_external_param, TimestepMatrix, TimestepVector, 
    ArrayModelParameter, ScalarModelParameter

@defcomp MyComp begin
    a = Parameter(index=[time, regions])
    b = Parameter(index=[time])
    c = Parameter(index=[regions])
    d = Parameter()
    e = Parameter(index=[four])
    f::Array{Float64, 2} = Parameter()

    x = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.x[t, r] = 0
        end
    end
end

m = Model()
set_dimension!(m, :time, 2000:2100)
set_dimension!(m, :regions, 3)
set_dimension!(m, :four, 4)

addcomponent(m, MyComp)
set_parameter!(m, :MyComp, :a, ones(101,3))
set_parameter!(m, :MyComp, :b, 1:101)
set_parameter!(m, :MyComp, :c, [4,5,6])
set_parameter!(m, :MyComp, :d, .5)
set_parameter!(m, :MyComp, :e, [1,2,3,4])
set_parameter!(m, :MyComp, :f, [1.0 2.0; 3.0 4.0])

# THIS FAILS: Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}} != Array{Float64,2}
#set_parameter!(m, :MyComp, :f, reshape(1:16, 4, 4))

extpars = external_params(m)

@test isa(extpars[:a], ArrayModelParameter)
@test isa(extpars[:b], ArrayModelParameter)
@test isa(extpars[:c], ArrayModelParameter)
@test isa(extpars[:d], ScalarModelParameter)
@test isa(extpars[:e], ArrayModelParameter)

@test isa(extpars[:f], ScalarModelParameter) # note that :f is stored as a scalar parameter even though its values are an array

@test typeof(extpars[:a].values) == TimestepMatrix{Float64, 2000, 1}
@test typeof(extpars[:b].values) == TimestepVector{Float64, 2000, 1}
@test typeof(extpars[:c].values) == Array{Float64, 1}
@test typeof(extpars[:d].value) == Float64
@test typeof(extpars[:e].values) == Array{Float64, 1}
@test typeof(extpars[:f].value) == Array{Float64, 2}

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

# THIS FAILS:  haven't set f yet because of errors above
@test length(extpars) == 6
@test typeof(extpars[:a].values) == TimestepMatrix{Float64, 2000, 1}
@test typeof(extpars[:d].value) == Float64
@test typeof(extpars[:e].values) == Array{Float64, 1}
