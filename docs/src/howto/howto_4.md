# How-to Guide 4: Work with Timesteps

## Timesteps and Available Functions

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
