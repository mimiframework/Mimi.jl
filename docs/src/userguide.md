# User Guide

## Overview

See the Tutorial for in depth examples of one-region and multi-region models.

This guide is organized into four main sections for understanding how to use Mimi.

1) Defining components
2) Constructing a model
3) Running the model
4) Accessing results
5) Advanced topics

## Defining Components

Any Mimi model is made up of at least one component, so before you construct a model, you need to create your components.
We define a component in the following way:

```julia
using Mimi

@defcomp MyComponentName begin
  regions = index()

  A = Variable(index = [time])
  B = Variable(index = [time, regions])

  c = Parameter()
  d = Parameter(index = [time])
  e = Parameter(index = [time, regions])
  f = Parameter(index = [regions])
end
```
A component can have any number of parameters and variables. Parameters are data values that will be provided to the component as input, and variables are values that the component will calculate in the run_timestep function when the model is run. The index of a parameter or variable determines the number of dimensions that parameter or variable has. They can be scalar values and have no index, such as parameter 'c' in the example above. They can be one-dimensional, such as the variable 'A' and the parameters 'd' and 'f' above. They can be two dimensional such as variable 'B' and parameter 'e' above. Note that any index other than 'time' must be declared at the top of the component, as shown by `regions = index()` above.

The user must define a run_timestep function for each component. That looks like the following:

```julia
function run_timestep(c::MyComponentName, t::Timestep)
  params = c.Parameters
  vars = c.Variables
  dims = c.Dimensions

  vars.A[t] = params.c + params.d[t]
  for r in dims.regions
    vars.B[t, r] = params.f[r] * params.e[t, r]
  end
end

```

The run_timestep function is responsible for calculating values for each variable in that component. The first argument to the function is a 'ComponentState', a type whose name matches the component you defined. The second argument is a Timestep, which represents which timestep the model is at each time the function gets called. Note that the component state (the first argument) has fields for the Parameters, Variables, and Dimensions of that component you defined. You can access each parameter, variable, or dimension using dot notation as shown above.

To access the data in a parameter or to assign a value to a variable, you must use the appropriate index or indices (in this example, either the Timestep or region or both).

## Constructing a Model

The first step in constructing a model is to set the values for each index of the model. Below is an example for setting the 'time' and 'regions' indexes. The time index expects either a numerical range or an array of numbers. If a single value is provided, say '100', then that index will be set from 1 to 100. Other indexes can have values of any type.

```julia
mymodel = Model()
setindex(mymodel, :time, 1850:2200)
setindex(mymodel, :regions, ["USA", "EU", "LATAM"])

```

The next step is to add components to the model. This is done by the following syntax:

```julia
addcomponent(mymodel, :ComponentA, :GDP)
addcomponent(mymodel, :ComponentB; start=2010)
addcomponent(mymodel, :ComponentC; start=2010, final=2100)

```

The first argument to addcomponent is the model, the second is the name of the component type. If an optional second symbol is provided (as in the first line above), this will be used as the name of the component in this model. This allows you to add multiple versions of the same component to a model, with different names. You can also have components that do not run for the full length of the model. You can specify custom start and final times with the optional keyword arguments as shown above. If no start or final time is provided, the component will assume the start or final time of the model's time index values that were specified in setindex.

The next step is to set the values for all the parameters in the components. Parameters can either have their values assigned from external data, or they can internally connect to the values from variables in other components of the model.

To make an external connection, the syntax is as follows:

```julia
setparameter(mymodel, :ComponentName, :parametername, 0.8) # a scalar parameter
setparameter(mymodel, :ComponentName, :parametername2, rand(351, 3)) # a two-dimensional parameter

```

To make an internal connection:

```julia
connectparameter(mymodel, :TargetComponent=>:parametername, :SourceComponent=>:variablename)

```

If you wish to delete a component that has already been added, do the following:
```julia
delete!(mymodel, :ComponentName)
```
This will delete the component from the model and remove any existing connections it had. Thus if a different component was previously connected to this component, you will need to connect its parameter(s) to something else.

## Running a Model

After all components have been added to your model and all parameters have been connected to either external values or internally to another component, then the model is ready to be run. Note: at each timestep, the model will run the components in the order you added them. So if one component is going to rely on the value of another component, then the user must add them to the model in the appropriate order.

```julia
run(mymodel)

```

## Results

After a model has been run, you can access the results (the calculated variable values in each component) in a few different ways.

You can use the `getindex` syntax as follows:

```julia
mymodel[:ComponentName, :VariableName]
mymodel[:ComponentName, :VariableName][100]

```
Indexing into a model with the name of the component and variable will return an array with values from each timestep.
You can index into this array to get one value (as in the second line, which returns just the 100th value). Note that if the requested variable is tow-dimensional, then a 2-D array will be returned.

You can also get data in the form of a dataframe, which will display the corresponding index labels rather than just a raw array. The syntax for this is:

```julia
getdataframe(mymodel, :ComponentName=>:Variable) # request one variable from one component
getdataframe(mymodel, :ComponentName=>(:Variable1, :Variable2)) # request multiple variables from the same component
getdataframe(mymodel, :Component1=>:Var1, :Component2=>:Var2) # request variables from different components

```

## Plotting
![Plotting Example](figs/plotting_example.png)


Mimi provides support for plotting using the [Plots](https://github.com/tbreloff/Plots.jl) module. Mimi extends Plots by adding an additional method to the `Plots.plot` function. Specifically, it adds a new method with the signature

```julia
function Plots.plot(m::Model, component::Symbol, parameter::Symbol ; index::Symbol, legend::Symbol, x_label::String, y_label::String)
```
A few important things to note:

- The model `m` must be built and run before it is passed into `plot`
- `index`, `legend`, `x_label`, and `y_label` are optional keyword arguments. If no values are provided, the plot will index by `time` and use the data it has to best fill in the axis labels.
- `legend` should be a `Symbol` that refers to an index on the model set by a call to `setindex`

This method returns a ``Plots.Plot`` object, so calling it in an instance of an IJulia Notebook will display the plot. Because this method is defined on the Plots package, it is easy to use the other features of the Plots package. For example, calling `savefig("x")` will save the plot as `x.png`, etc. See the [Plots Documentaton](https://juliaplots.github.io/) for a full list of capabilities.



## Advanced Topics

### Timesteps and available functions

A `Timestep` is an immutable type defined within Mimi in "src/clock.jl". It is used to represent and keep track of time indices when running a model.

In the run_timestep functions which the user defines, it may be useful to use any of the following functions, where `t` is a Timestep object:

```julia
isfinaltimestep(t) # returns true or false
isfirsttimestep(t) # returns true or false
gettime(t) # returns the year represented by timestep t
```

### Parameter connections between different length components

As mentioned earlier, it is possible for some components to start later or end sooner than the full length of the model. This presents potential complications when for connecting their parameters. If you are setting the parameters to external values, then the provided values just need to be the right size for that component's parameter. If you are making an internal connection, this can happen in one of two ways:

1. A shorter component is connected to a longer component. In this case, nothing additional needs to happen. The shorter component will pick up the correct values it needs from the longer component.
2. A longer component is connected to a shorter component. In this case, the shorter component will not have enough values to supply to the longer component. In order to make this connection, the user must also provide an array of backup data for the parameter to default to when the shorter component does not have values to give. Do this in the following way:

```julia
backup = rand(100) # data array of the proper size
connectparameter(mymodel, :LongComponent=>:parametername, :ShortComponent=>:variablename, backup)
```

Note: for now, to avoid discrepancy with timing and alignment, the backup data must be the length of the whole component's start to final time, even though it will only be used for values not found in the shorter component.

### More on parameter indices

As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model's indexes. A parameter can also have an indexes specified in the following ways:

```julia
@defcomp MyComponent begin
  p1 = Parameter(index=[4])
  p2::Array{Float64, 2} = Parameter()
end
```

### Updating an external parameter

When `setparameter` is called, it creates an external parameter by the name provided, and stores the provided value(s). It is possible to later change the value(s) associated with that parameter name. Use the following available function:

```julia
update_external_parameter(mymodel, :parametername, newvalues)
```

Note: newvalues must be the same size and type (or be able to convert to the type) as the old values stored in that parameter.

### Setting parameters with a dictionary

In larger models it can be beneficial to set some of the external parameters using a dictionary of values. To do this, use the following function:

```julia
setleftoverparameters(mymodel, parameters)
```

Where `parameters` is a dictionary of type `Dict{String, Any}` where the keys are strings that match the names of the unset parameters in the model, and the values are the values to use for those parameters.

### Using NamedArrays for setting parameters

When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model's index values for those dimensions.

### The internal 'build' function and model instances

 When you call the run function on your model, first the internal `build` function is called, which produces a ModelInstance, and then the ModelInstance is run. A model instance is an instantiated version of the model you have designed where all of the component constructors have been called and all of the data arrays have been allocated. If you wish to create and run multiple versions of your model, you can use the intermediate build function and store the separate ModelInstances. This may be useful if you want to change some parameter values, while keeping the model's structure mostly the same. For example:

```julia
instance1 = Mimi.build(mymodel)
run(instance1)

update_external_parameter(mymodel, paramname, newvalue)
instance2 = Mimi.build(mymodel)
run(instance2)

result1 = instance1[:Comp, :Var]
result2 = instance2[:Comp, :Var]

```

Note that you can index into a ModelInstance in the same way previously shown for indexing into a model.
