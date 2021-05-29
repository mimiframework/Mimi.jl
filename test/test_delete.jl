module TestDelete

# Test the behavior of the `delete!` function with and without the `deep` kwarg.

using Mimi
using Test

@defcomp A begin
    p1 = Parameter()
    p2 = Parameter()
end

function _get_model()
    
    m = Model()
    set_dimension!(m, :time, 1:2)
    add_comp!(m, A, :A1)
    add_comp!(m, A, :A2)

    add_shared_param!(m, :p1, 1)
    connect_param!(m, :A1, :p1, :p1)
    connect_param!(m, :A2, :p1, :p1)

    add_shared_param!(m, :p2_A1, 21)
    connect_param!(m, :A1, :p2, :p2_A1)
    
    add_shared_param!(m, :p2_A2, 22)
    connect_param!(m, :A2, :p2, :p2_A2)

    return m
end

# Test component deletion without removing unbound component parameters
m1 = _get_model()
run(m1)
@test length(Mimi.components(m1)) == 2
@test length(m1.md.external_param_conns) == 4   # two components with two connections each
@test length(m1.md.model_params) == 3

delete!(m1, :A1)    
run(m1) # run before and after to test that `delete!` properly "dirties" the model, and builds a new instance on the next run
@test length(Mimi.components(m1)) == 1
@test length(m1.md.external_param_conns) == 2   # Component A1 deleted, so only two connections left
@test length(m1.md.model_params) == 3
@test :p2_A1 in keys(m1.md.model_params)

# Test component deletion that removes unbound component parameters
m2 = _get_model()
delete!(m2, :A1, deep = true)
@test length(Mimi.components(m2.md)) == 1
@test length(m2.md.model_params) == 2  # :p2_A1 has been removed
@test !(:p2_A1 in keys(m2.md.model_params))
run(m2)

# Test the `delete_param! function on its own
m3 = _get_model()
run(m3)
delete_param!(m3, :p1)
@test_throws KeyError run(m3)     # will not be able to run because p1 in both components can't find it's key
@test length(m3.md.external_param_conns) == 2   # The external param connections to p1 have also been removed

end