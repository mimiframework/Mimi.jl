include("../src/OptiMimi.jl")
using Base.Test

using Mimi
using OptiMimi
using ForwardDiff

# Differentiation-free optimization
# Create quadratic component
@defcomp quad1 begin
    regions = Index()

    # The x-value of the maximum of the quadratic
    maximum = Parameter(index=[regions])

    # The x-value to evaluate the quadratic
    input = Parameter(index=[regions])

    # The y-value of the quadratic at the x-value
    value = Variable(index=[regions])
end

function timestep(state::quad1, t)
    v = state.Variables
    p = state.Parameters

    v.value = -(p.input - p.maximum).^2
end

# Prepare model
model1 = Model()
setindex(model1, :time, 1)
setindex(model1, :regions, 2)
addcomponent(model1, quad1)
setparameter(model1, :quad1, :maximum, [2., 10.])
setparameter(model1, :quad1, :input, [0., 0.])

objective1(model::Model) = sum(model[:quad1, :value])

optprob = problem(model1, [:quad1], [:input], [0.], [100.0], objective1)
(maxf, maxx) = solution(optprob, () -> [0., 0.])

@test_approx_eq_eps maxf 0 1e-2
@test_approx_eq_eps maxx[1] 2 1e-2
@test_approx_eq_eps maxx[2] 10 1e-2

# Automatic differentiation

# Create quadratic component
@defcomp quad2 begin
    regions = Index()

    # The x-value of the maximum of the quadratic
    maximum = Parameter(index=[regions])

    # The x-value to evaluate the quadratic
    input = Parameter(index=[regions])

    # The y-value of the quadratic at the x-value
    value = Variable(index=[regions])
end

function timestep(state::quad2, t)
    v = state.Variables
    p = state.Parameters

    v.value = -(p.input - p.maximum).^2
end

# Prepare model
model2 = Model(Number)
setindex(model2, :time, 1)
setindex(model2, :regions, 2)
addcomponent(model2, quad2)
setparameter(model2, :quad2, :maximum, [2., 10.])
setparameter(model2, :quad2, :input, [0., 0.])

objective2(model::Model) = sum(model[:quad2, :value])

# Test the translation to a simple objective function
uo = unaryobjective(model2, [:quad2], [:input], objective2)
guo = ForwardDiff.gradient(uo)
guos = guo([0., 0.])
@test_approx_eq_eps guos[1] 4 1e-2
@test_approx_eq_eps guos[2] 20 1e-2

# Optimize
optprob = problem(model2, [:quad2], [:input], [0.], [100.0], objective2)
(maxf, maxx) = solution(optprob, () -> [0., 0.])


@test_approx_eq_eps maxf 0 1e-2
@test_approx_eq_eps maxx[1] 2 1e-2
@test_approx_eq_eps maxx[2] 10 1e-2
