# OptiMimi: Mimi wrapper for optimization

OptiMimi provides a simplified interface for finding optimal parameter
valuesfor Mimi models.  The core interface consists of `problem` to
define the optimization problem, and `solution` to solve it.

OptiMimi supports autodifferentiation using ForwardDiff.  To use it,
the Model must be created with the optional `autodiffable` set to
`true`, and all components must be created using the `@defcompo`
macro, instead of `@defcomp`.  Currently, errors will result if either
`autodiffable` is set to `false` but any component is defined with
`@defcompo` or `autodiffable` is set to true but any component is not
defined using `@defcompo`.

OptiMimi is currently implemented using NLopt, but it is meant to
provide a general interface for other optimization systems.

## Constructing an optimization problem

Setup an optimization problem with the `problem` function:
```
problem(model, names, lowers, uppers, objective; constraints, algorithm)
```

* `model` is a Mimi model, with some parameters intended for optimization.
* `components` and `names` are lists of the parameter names to be optimized, and must be the same length.
* `lowers` and `uppers` are a list of lower and upper bounds and must be the same length as `names`; the same bounds are used for all values within a parameter array.
* `objective` is a function that takes a Mimi Model, with parameters set and fully executed, and returns a value to be maximized.
* `constraints` (optional) is a vector of inequality constraint functions; each takes a Mimi Model, with parameters set (but not necessarily executed), and should return < 0 when the constraint is satisfied.
* `algorithm` (optional) is a symbol, currently chosen from the NLopt algorithms.

The return value is an object of the OptimizationProblem type, to be passed to `solution`.

### Example:

Start by creating a Mimi model and ensuring that it runs with all
parameters set.  In the example below, `my_model` is a model with an
agriculture component, in which N regions are evaluated in a single
timestep to consume energy and produce corn.

The optimization maximizes economic value, trading off the value of
the corn against the cost of the energy for fertilizer.  We also add a
constraint that the total fertilizer cannot be more than 1 million kg,
to reduce environmental impacts.

```
using OptiMimi

# Prices of goods
p_F = 0.25  # the global price of food (per kg of corn)
p_E = 0.4   # the global price of fuel (per kWh)

# Objective to maximize economic output
function objective(model::Model)
    sum(my_model[:agriculture, :cornproduction] * p_F - my_model[:agriculture, :cornenergyuse] * p_E)
end

constraints = [model -> sum(model.components[:agriculture].Parameters.fertilizer) - 1e6]

# Setup the optimization
optprob = problem(my_model, [:agriculture], [:fertilizer], [0.], [1e6], objective, constraints=constraints)
```

Note that (1) the objective function is provided with the prepared
model, not with the raw initialization values, and (2) even though
there are N values to be set and optimized over in the `fertilizer`
parameter, the lower and upper bounds are only specified once.

## Solving the optimization problem

The optimization problem, returned by `problem` is solved by `solution`:
```
solution(optprob, generator; maxiter, verbose)
```

* `optprob` is the result of the `problem` function.
* `generator` is a function of no arguments, which returns a full set of parameter values, with values concatenated across parameters in the order of `names` above.  This should generally be stochastic, and if the specified model fails the constraints then `generator` will be called again until it succeeds.
* `maxiter` (optional) is the maximum number of iterations for the optimization; currently it only is used for the maximum number of times that `generator` will be called.
* `verbose` (optional) is a boolean to specify if status messages should be printed.

The return value is a tuple of the maximum found objective value, and
the concatenated collection of model parameters that produced it.

### Example:

Continuing the example above, we solve the optimization problem:

```
(maxf, maxx) = solution(optprob, () -> [0. for i in 1:5])

println(maxf)
println(maxx)
```

Our generator function can only generate a single initial condition: all 0's.