module TestReferences

using Test
using Mimi

import Mimi: model_params

@defcomp A begin
    p1 = Parameter()
    v1 = Variable(index = [time])
    function run_timestep(p, v, d, t)
        v.v1[t] = gettime(t)
    end
end

@defcomp B begin
    p1 = Parameter()
    p2 = Parameter(index = [time])
end

m = Model()
set_dimension!(m, :time, 10)
refA = add_comp!(m, A, :foo)
refB = add_comp!(m, B)

refA[:p1] = 3   # creates a parameter specific to this component, with name "foo_p1"
@test Mimi.get_model_param_name(m.md, :foo, :p1) == :foo_p1
@test :foo_p1 in keys(model_params(m))
@test Mimi.UnnamedReference(:B, :p1) in Mimi.nothing_params(m.md)

refB[:p1] = 5
@test Mimi.get_model_param_name(m.md, :B, :p1) == :B_p1
@test :B_p1 in keys(model_params(m))

# Use the ComponentReferences to make an internal connection
refB[:p2] = refA[:v1]

run(m)
@test m[:foo, :p1] == 3
@test m[:B, :p1] == 5
@test m[:B, :p2] == collect(1:10)

# Test `connect_param!` methods for ComponentReferences

connect_param!(refB, :p2, refA, :v1)
run(m)
@test m[:B, :p2] == collect(1:10)

@defcomp C begin
    v1 = Parameter(index = [time])
end
refC = add_comp!(m, C)
connect_param!(refC, refA, :v1)
run(m)
@test m[:C, :v1] == collect(1:10)

# test `update_param!` for references
refA[:p1] = 10
run(m)
@test m[:foo, :p1] == 10

end