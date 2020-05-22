# How-to Guide 4: Advanced Topics

## Advanced Topics

### Timesteps and available functions

An `AbstractTimestep` i.e. a `FixedTimestep` or a `VariableTimestep` is a type defined within Mimi in "src/time.jl". It is used to represent and keep track of time indices when running a model.

In the `run_timestep` functions which the user defines, it may be useful to use any of the following functions, where `t` is an `AbstractTimestep` object:

```julia
is_first(t) # returns true or false, true if t is the first timestep to be run
is_last(t) # returns true or false, true if t is the last timestep to be run
gettime(t) # returns the year represented by timestep t
```
There are also two helper types `TimestepValue` and `TimestepIndex` that can be used with comparison operators (`==`, `<`, and `>`) to check whether an `AbstractTimestep` `t` during the `run_timestep` function corresponds with a certain year or index number. For example:
```julia
if t > TimestepValue(2020)
  # run this code only for timesteps after the year 2020
end

if t == TimestepIndex(3)
  # run this code only during the third timestep
end
```
See below for further discussion of the `TimestepValue` and `TimestepIndex` objects and how they should be used.

The API details for AbstractTimestep object `t` are as follows:

- you may index into a variable or parameter with `[t]` or `[t +/- x]` as usual
- to access the time value of `t` (currently a year) as a `Number`, use `gettime(t)`
- useful functions for commonly used conditionals are `is_first(t)` and `is_last(t)`
- to access the index value of `t` as a `Number` representing the position in the time array, use `t.t`.  Users are encouraged to avoid this access, and instead use comparisons with `TimestepIndex` objects to check if an AbstractTimestep `t` corresponds with a specific index number, as described above.

Indexing into a variable or parameter's `time` dimension with an `Integer` is deprecated and will soon error. Instead, users should take advantage of the `TimestepIndex` and `TimestepValue` types. For examples we will refer back to our component definition above, and repeated below.
```julia
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
```
`TimestepIndex` has one field, `index`, which refers to the absolute index in the parameter or variable array's `time` dimension. Thus, constructing a `TimestepIndex` is done by simply writing `TimestepIndex(index::Int)`. Looking back at our original component example
one could modify the first line of `run_timestep` to always refer to the first timestep of `p.d` with the following. One may index into the `time` dimension with a single `TimestepIndex`, or an `Array` of them.
```julia
v.A[t] = p.c + p.d[TimestepIndex(1)]
```
`TimestepValue` has two fields, `value` and `offset`, referring to the value within the `time` dimension and an optional `offset` from that `value`. Thus, constructing a `TimestepValue` is done either by writing `TimestepValue(value)`, with an implied offset of 0, or `TimestepValue(value, offset = i::Int)`, with an explicit offset of i. One may index into the `time` dimension with a single `TimestepValue`, or an `Array` of them. For example, you can use a `TimestepValue` to keep track of a baseline year.
```julia
v.A[t] = p.c + p.d[TimestepValue(2000)]
```
You may also use shorthand to create arrays of `TimestepIndex` using Colon syntax.
```julia
TimestepIndex(1):TimestepIndex(10) # implicit step size of 1
TimestepIndex(1):2:TimestepIndex(10) # explicit step of type Int 
```
Both `TimestepIndex` and `TimestepArray` have methods to support addition and subtraction of integers.  Note that the addition or subtraction is relative to the definition of the `time` dimension, so while `TimestepIndex(1) + 1 == TimestepIndex(2)`, `TimestepValue(2000) + 1` could be equivalent to `TimestepValue(2001)` **if** 2001 is the next year in the time dimension, or `TimestepValue(2005)` if the array has a step size of 5. Hence adding or subtracting is relative to the definition of the `time` dimension. 


### DataType specification of Parameters and Variables 

By default, the Parameters and Variables defined by a user will be allocated storage arrays of type `Float64` when a model is constructed. This default "number_type" can be overriden when a model is created, with the following syntax:
```
m = Model(Int64)    # creates a model with default number type Int64
```
But you can also specify individual Parameters or Variables to have different data types with the following syntax in a `@defcomp` macro:
```
@defcomp example begin
  p1 = Parameter{Bool}()                         # ScalarModelParameter that is a Bool
  p2 = Parameter{Bool}(index = [regions])        # ArrayModelParameter with one dimension whose eltype is Bool
  p3 = Parameter{Matrix{Int64}}()                # ScalarModelParameter that is a Matrix of Integers
  p4 = Parameter{Int64}(index = [time, regions]) # ArrayModelParameter with two dimensions whose eltype is Int64
end
```
If there are "index"s listed in the Parameter definition, then it will be an `ArrayModelParameter` whose `eltype` is the type specified in the curly brackets. If there are no "index"s listed, then the type specified in the curly brackets is the actual type of the parameter value, and it will be represent by Mimi as a `ScalarModelParameter`.

### Parameter connections between different length components

As mentioned earlier, it is possible for some components to start later or end sooner than the full length of the model. This presents potential complications for connecting their parameters. If you are setting the parameters to external values, then the provided values just need to be the right size for that component's parameter. If you are making an internal connection, this can happen in one of two ways:

1. A shorter component is connected to a longer component. In this case, nothing additional needs to happen. The shorter component will pick up the correct values it needs from the longer component.
2. A longer component is connected to a shorter component. In this case, the shorter component will not have enough values to supply to the longer component. In order to make this connection, the user must also provide an array of backup data for the parameter to default to when the shorter component does not have values to give. Do this in the following way:

```julia
backup = rand(100) # data array of the proper size
connect_param!(m, :LongComponent=>:ParameterName, :ShortComponent=>:VariableName, backup)
```

Note: for now, to avoid discrepancy with timing and alignment, the backup data must be the length of the whole component's first to last time, even though it will only be used for values not found in the shorter component.

### More on parameter indices

As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model's indexes. A parameter can also have an index specified in the following ways:

```julia
@defcomp MyComponent begin
  p1 = Parameter(index=[4]) # an array of length 4
  p2 = Parameter{Array{Float64, 2}}() # a two dimensional array of unspecified length
end
```

In both of these cases, the parameter's values are stored of as an array (p1 is one dimensional, and p2 is two dimensional). But with respect to the model, they are considered "scalar" parameters, simply because they do not use any of the model's indices (namely 'time', or 'regions').

### Updating an external parameter

When `set_param!` is called, it creates an external parameter by the name provided, and stores the provided scalar or array value. It is possible to later change the value associated with that parameter name using the functions described below. If the external parameter has a `:time` dimension, use the optional argument `update_timesteps=true` to indicate that the time keys (i.e., year labels) associated with the parameter should be updated in addition to updating the parameter values.

```julia
update_param!(m, :ParameterName, newvalues) # update values only 
update_param!(m, :ParameterName, newvalues, update_timesteps=true) # also update time keys
```

Note: `newvalues` must be the same size and type (or be able to convert to the type) of the old values stored in that parameter.

### Setting parameters with a dictionary

In larger models it can be beneficial to set some of the external parameters using a dictionary of values. To do this, use the following function:

```julia
set_leftover_params!(m, parameters)
```

Where `parameters` is a dictionary of type `Dict{String, Any}` where the keys are strings that match the names of the unset parameters in the model, and the values are the values to use for those parameters.

### Using NamedArrays for setting parameters

When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model's index values for those dimensions. Examples of this can be found in "test/test_parameter_labels.jl".

### The internal 'build' function and model instances

 When you call the run function on your model, first the internal `build` function is called, which produces a ModelInstance, and then the ModelInstance is run. A model instance is an instantiated version of the model you have designed where all of the component constructors have been called and all of the data arrays have been allocated. If you wish to create and run multiple versions of your model, you can use the intermediate build function and store the separate ModelInstances. This may be useful if you want to change some parameter values, while keeping the model's structure mostly the same. For example:

```julia
instance1 = Mimi.build(m)
run(instance1)

update_param!(m, ParameterName, newvalue)
instance2 = Mimi.build(m)
run(instance2)

result1 = instance1[:Comp, :Var]
result2 = instance2[:Comp, :Var]
```

Note that you can retrieve values from a ModelInstance in the same way previously shown for indexing into a model.

### The init function ###

The `init` function can optionally be called within `@defcomp` and **before** `run_timestep`.  Similarly to `run_timestep`, this function is called with parameters `init(p, v, d)`, where the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined.   

If defined for a specific component, this function will run **before** the timestep loop, and should only be used for parameters or variables without a time index e.g. to compute the values of scalar variables that only depend on scalar parameters. Note that when using `init`, it may be necessary to add special handling in the `run_timestep` function for the first timestep, in particular for difference equations.  A skeleton `@defcomp` script using both `run_timestep` and `init` would appear as follows:

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
### Using References


#### Component References

Component references allow you to write cleaner model code when connecting components.  The `add_comp!` function returns a reference to the component that you just added:

```jldoctest faq1; output = false
using Mimi

# create a component
@defcomp MyComp begin
    # empty
end

# construct a model and add the component
m = Model()
set_dimension!(m, :time, collect(2015:5:2110))
add_comp!(m, MyComp)
typeof(MyComp) # note the type is a Mimi Component Definition

# output

Mimi.ComponentDef
```

If you want to get a reference to a component after the `add_comp!` call has been made, you can construct the reference as:

```jldoctest faq1; output = false
mycomponent = Mimi.ComponentReference(m, :MyComp)
typeof(mycomponent) # note the type is a Mimi Component Reference

# output

Mimi.ComponentReference
```

You can use this component reference in place of the `set_param!` and `connect_param!` calls.

#### References in place of `set_param!`

The line `set_param!(model, :MyComponent, :myparameter, myvalue)` can be written as `mycomponent[:myparameter] = myvalue`, where `mycomponent` is a component reference.

#### References in place of `connect_param!`

The line `connect_param!(model, :MyComponent, :myparameter, :YourComponent, :yourparameter)` can be written as `mycomponent[:myparameter] = yourcomponent[:yourparameter]`, where `mycomponent` and `yourcomponent` are component references.
