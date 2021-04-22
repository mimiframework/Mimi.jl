# How-to Guide 4: Work with Timesteps, Parameters, and Variables 

## Timesteps and available functions

An `AbstractTimestep` i.e. a `FixedTimestep` or a `VariableTimestep` is a type defined within Mimi in "src/time.jl". It is used to represent and keep track of time indices when running a model.

In the `run_timestep` functions which the user defines, it may be useful to use any of the following functions, where `t` is an `AbstractTimestep` object:

```julia
is_first(t) # returns true or false, true if t is the first timestep to be run for the respective component
is_last(t) # returns true or false, true if t is the last timestep to be run for the respective component
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
`TimestepIndex` has one field, `index`, which refers to the absolute index in the parameter or variable array's `time` dimension. Thus, constructing a `TimestepIndex` is done by simply writing `TimestepIndex(index::Int)`. Looking back at our original component example, one could modify the first line of `run_timestep` to always refer to the first timestep of `p.d` with the following. One may index into the `time` dimension with a single `TimestepIndex`, or an `Array` of them.
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


## DataType specification of Parameters and Variables 

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

## More on parameter indices

As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model's indexes. A parameter can also have an index specified in the following ways:

```julia
@defcomp MyComponent begin
  p1 = Parameter(index=[4]) # an array of length 4
  p2 = Parameter{Array{Float64, 2}}() # a two dimensional array of unspecified length
end
```

In both of these cases, the parameter's values are stored of as an array (p1 is one dimensional, and p2 is two dimensional). But with respect to the model, they are considered "scalar" parameters, simply because they do not use any of the model's indices (namely 'time', or 'regions').

## Updating an external parameter

When `set_param!` is called, it creates an external parameter by the name provided, and stores the provided scalar or array value. It is possible to later change the value associated with that parameter name using the functions described below. 

```julia
update_param!(m, :ParameterName, newvalues)
```

Note here that `newvalues` must be the same type (or be able to convert to the type) of the old values stored in that parameter, and the same size as the model dimensions indicate. 

#### Setting parameters with a dictionary

In larger models it can be beneficial to set some of the external parameters using a dictionary of values. To do this, use the following function:

```julia
set_leftover_params!(m, parameters)
```

Where `parameters` is a dictionary of type `Dict{String, Any}` where the keys are strings that match the names of the unset parameters in the model, and the values are the values to use for those parameters.

## Using NamedArrays for setting parameters

When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model's index values for those dimensions. Examples of this can be found in "test/test_parameter_labels.jl".
