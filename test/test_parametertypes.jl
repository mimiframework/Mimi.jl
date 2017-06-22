using Mimi
using Base.Test

@defcomp MyComp begin
    a = Parameter(index=[time, regions])
    b = Parameter(index=[time])
    c = Parameter(index=[regions])
    d = Parameter()
    e = Parameter(index=[4])
    f::Array{Float64, 2} = Parameter()

    x = Variable(index=[time, regions])
end

function run_timestep(s::MyComp, ts::Timestep)
    p = s.Parameters
    v = s.Variables
    d = s.Dimensions

    for r in d.regions
        v.x[ts, r] = 0
    end

end

m = Model()
setindex(m, :time, 2000:2100)
setindex(m, :regions, [1,2,3])
addcomponent(m, MyComp)
setparameter(m, :MyComp, :a, ones(101,3))
setparameter(m, :MyComp, :b, 1:101)
setparameter(m, :MyComp, :c, [4,5,6])
setparameter(m, :MyComp, :d, .5)
setparameter(m, :MyComp, :e, [1,2,3,4])
setparameter(m, :MyComp, :f, reshape(1:16, 4, 4))

@test isa(m.external_parameters[:a], Mimi.ArrayModelParameter)
@test isa(m.external_parameters[:b], Mimi.ArrayModelParameter)
@test isa(m.external_parameters[:c], Mimi.ArrayModelParameter)
@test isa(m.external_parameters[:d], Mimi.ScalarModelParameter)
@test isa(m.external_parameters[:e], Mimi.ArrayModelParameter)
@test isa(m.external_parameters[:f], Mimi.ScalarModelParameter) # note that :f is stored as a scalar parameter even though its values are an array

@test typeof(m.external_parameters[:a].values) == Mimi.TimestepMatrix{Float64, 2000, 1}
@test typeof(m.external_parameters[:b].values) == Mimi.TimestepVector{Float64, 2000, 1}
@test typeof(m.external_parameters[:c].values) == Array{Float64, 1}
@test typeof(m.external_parameters[:d].value) == Float64
@test typeof(m.external_parameters[:e].values) == Array{Float64, 1}
@test typeof(m.external_parameters[:f].value) == Array{Float64, 2}

# test updating parameters
@test_throws ErrorException update_external_parameter(m, :a, 5) #expects an array
@test_throws ErrorException update_external_parameter(m, :a, ones(101)) #wrong size
@test_throws ErrorException update_external_parameter(m, :a, fill("hi", 101, 3)) #wrong type
update_external_parameter(m, :a, zeros(101,3))

@test_throws ErrorException update_external_parameter(m, :d, ones(5)) #wrong type; should be scalar
update_external_parameter(m, :d, 5) # should work, will convert to float
@test_throws ErrorException update_external_parameter(m, :e, 5) #wrong type; should be array
@test_throws ErrorException update_external_parameter(m, :e, ones(10)) #wrong size
update_external_parameter(m, :e, [4,5,6,7])

@test length(m.external_parameters) == 6
@test typeof(m.external_parameters[:a].values) == Mimi.TimestepMatrix{Float64, 2000, 1}
@test typeof(m.external_parameters[:d].value) == Float64
@test typeof(m.external_parameters[:e].values) == Array{Float64, 1}
