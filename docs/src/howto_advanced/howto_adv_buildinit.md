# Advanced How-to Guide: Build and Init Functions

In some cases, it may be useful for a user to better understand the inner-workings of the internal `build` function, as well as the ModelInstance and ModelDef types. In addition, components with one-time computations irrespective of timesteps may lend themselves to the use of the optional `init` function, as described below.

## The Internal 'build' Function and Model Instances

 The structural definition of a Model is held in the mutable ModelDef, and then when you call the run function on your model, first the internal `build` function is called, which produces a ModelInstance, and then the ModelInstance is run. A model instance is an instantiated version of the model you have designed where all of the component constructors have been called and all of the data arrays have been allocated. If you wish to create and run multiple versions of your model, you can use the intermediate build function and store the separate ModelInstances. This may be useful if you want to change some parameter values, while keeping the model's structure mostly the same. For example:

```julia
instance1 = Mimi.build(m)
run(instance1)

update_param!(m, ParameterName, newvalue)
instance2 = Mimi.build(m)
run(instance2)

result1 = instance1[:Comp, :Var]
result2 = instance2[:Comp, :Var]
```

Note that you can retrieve values from a ModelInstance in the same way you index into a model.

## The init function

The `init` function can optionally be called within [`@defcomp`](@ref) and **before** `run_timestep`.  Similarly to `run_timestep`, this function is called with parameters `init(p, v, d)`, where the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined.   

If defined for a specific component, this function will run **before** the timestep loop, and should only be used for parameters or variables without a time index e.g. to compute the values of scalar variables that only depend on scalar parameters. Note that when using `init`, it may be necessary to add special handling in the `run_timestep` function for the first timestep, in particular for difference equations.  A skeleton [`@defcomp`](@ref) script using both `run_timestep` and `init` would appear as follows:

```julia
@defcomp component1 begin

    # First define the state this component will hold
    savingsrate = Parameter()

    # Second, define the (optional) init function for the component
    function init(p, v, d)
    end

    # Third, define the run_timestep function for the component
    function run_timestep(p, v, d, t)
    end

end
```
