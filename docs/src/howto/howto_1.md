# How-to Guide 1: Construct and Run a Model

This how-to guide pairs nicely with Tutorial 4: Create a Model, serving as an abbreviated, less-detailed version and refresher for those with some experience with Mimi. If this is your first time constructing and running a Mimi model, we recommend you start with Tutorial 4, which will give you more detailed step-by step instructions.

## Defining Components

Any Mimi model is made up of at least one component, so before you construct a model, you need to create your components.

A component can have any number of parameters and variables. Parameters are data values that will be provided to the component as input, and variables are values that the component will calculate in the `run_timestep` function when the model is run. The index of a parameter or variable determines the number of dimensions that parameter or variable has. They can be scalar values and have no index, such as parameter 'c' in the example below. They can be one-dimensional, such as the variable 'A' and the parameters 'd' and 'f' below. They can be two dimensional such as variable 'B' and parameter 'e' below. Note that any index other than 'time' must be declared at the top of the component, as shown by `regions = Index()` below.

The user must define a `run_timestep` function for each component. 

We define a component in the following way:

```jldoctest; output = false
using Mimi

@defcomp MyComponentName begin
  regions = Index()

  A = Variable(index = [time])
  B = Variable(index = [time, regions])

  c = Parameter()
  d = Parameter(index = [time])
  e = Parameter(index = [time, regions])
  f = Parameter(index = [regions])

  function run_timestep(p, v, d, t)
    v.A[t] = p.c + p.d[t]
    for r in d.regions
      v.B[t, r] = p.f[r] * p.e[t, r]
    end
  end
end

# output

```

The `run_timestep` function is responsible for calculating values for each variable in that component.  Note that the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined. You can access each parameter, variable, or dimension using dot notation as shown above.  The fourth argument is an `AbstractTimestep`, i.e., either a `FixedTimestep` or a `VariableTimestep`, which represents which timestep the model is at.

The API for using the fourth argument, represented as `t` in this explanation, is described in a following how-to guide How-to Guide 4: Work with Timesteps, Parameters, and Variables. 

To access the data in a parameter or to assign a value to a variable, you must use the appropriate index or indices (in this example, either the Timestep or region or both).

By default, all parameters and variables defined in the `@defcomp` will be allocated storage as scalars or Arrays of type `Float64.` For a description of other data type options, see How-to Guide 4: Work with Timesteps, Parameters, and Variables 

## Constructing a Model

The first step in constructing a model is to set the values for each index of the model. Below is an example for setting the 'time' and 'regions' indexes. The time index expects either a numerical range or an array of numbers.  If a single value is provided, say '100', then that index will be set from 1 to 100. Other indexes can have values of any type.

```jldoctest; output = false
using Mimi

m = Model()
set_dimension!(m, :time, 1850:2200)
set_dimension!(m, :regions, ["USA", "EU", "LATAM"])

# output

["USA", "EU", "LATAM"]
```

*A Note on Time Indexes:* It is important to note that the values used for the time index are the *start times* of the timesteps.  If the range or array of time values has a uniform timestep length, the model will run *through* the last year of the range with a last timestep period length consistent with the other timesteps.  If the time values are provided as an array with non-uniform timestep lengths, the model will run *through* the last year in the array with a last timestep period length *assumed to be one*. 

The next step is to add components to the model. This is done by the following syntax:

```julia 
add_comp!(m, ComponentA, :GDP)
add_comp!(m, ComponentB; first=2010)
add_comp!(m, ComponentC; first=2010, last=2100)
```

The first argument to `add_comp!` is the model, the second is the name of the ComponentId defined by `@defcomp`. If an optional third symbol is provided (as in the first line above), this will be used as the name of the component in this model. This allows you to add multiple versions of the same component to a model, with different names.

The next step is to set the values for all the parameters in the components. Parameters can either have their values assigned from external data, or they can internally connect to the values from variables in other components of the model.

To make an external connection, the syntax is as follows:

```julia
set_param!(m, :ComponentName, :ParameterName, 0.8) # a scalar parameter
set_param!(m, :ComponentName, :ParameterName2, rand(351, 3)) # a two-dimensional parameter
```

To make an internal connection, the syntax is as follows.  

```julia
connect_param!(m, :TargetComponent=>:ParameterName, :SourceComponent=>:VariableName)
connect_param!(m, :TargetComponent=>:ParameterName, :SourceComponent=>:VariableName)
```

If you wish to delete a component that has already been added, do the following:

```julia
delete!(m, :ComponentName)
```

This will delete the component from the model and remove any existing connections it had. Thus if a different component was previously connected to this component, you will need to connect its parameter(s) to something else.

## Running a Model

After all components have been added to your model and all parameters have been connected to either external values or internally to another component, then the model is ready to be run. Note: at each timestep, the model will run the components in the order you added them. So if one component is going to rely on the value of another component, then the user must add them to the model in the appropriate order.

```julia
run(m)
```
