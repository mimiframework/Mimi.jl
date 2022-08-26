# How-to Guide 7: Port to Mimi v0.5.0

The release of Mimi v0.5.0 is a breaking release, necessitating the adaptation of existing models' syntax and structure in order for those models to run on this new version.  This guide provides an overview of the steps required to get most models using the v0.4.0 API working with v0.5.0.  It is **not** a comprehensive review of all changes and new functionalities, but a guide to the minimum steps required to port old models between versions.  For complete information on the new version and its functionalities, see the full documentation.

This guide is organized into six main sections, each describing an independent set of changes that can be undertaken in any order desired.  

1) Defining components
2) Constructing a model
3) Running the model
4) Accessing results
5) Plotting
6) Advanced topics

**A Note on Function Naming**: There has been a general overhaul on function names, especially those in the explicitly user-facing API, to be consistent with Julia conventions and the conventions of this Package.  These can be briefly summarized as follows:

- use `_` for readability
- append all functions with side-effects, i.e., non-pure functions that return a value but leave all else unchanged with a `!`
- the commonly used terms `component`, `variable`, and `parameter` are shortened to `comp`, `var`, and `param`
- functions that act upon a `component`, `variable`, or `parameter` are often written in the form `[action]_[comp/var/param]`

## Defining Components

The `run_timestep` function is now contained by the `@defcomp` macro, and takes the parameters `p, v, d, t`, referring to Parameters, Variables, and Dimensions of the component you defined.  The fourth argument is an `AbstractTimestep`, i.e., either a `FixedTimestep` or a `VariableTimestep`.  Similarly, the optional `init` function is also contained by `@defcomp`, and takes the parameters `p, v, d`.  Thus, as described in the user guide, defining a single component is now done as follows:

In this version, the fourth argument (`t` below) can no longer always be used simply as an `Int`. Indexing with `t` is still permitted, but special care must be taken when comparing `t` with conditionals or using it in arithmetic expressions.  The full API as described later in this document in **Advanced Topics:  Timesteps and available functions**.  Since differential equations are commonly used as the basis for these models' equations, the most commonly needed change will be changing `if t == 1` to `if is_first(t)`

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

## Constructing a Model

In an effort to standardize the function naming protocol within Mimi, and to streamline it with the Julia convention, several function names have been changed.  The table below lists a **subset** of these changes, focused on the exported API functions most commonly used in model construction.  

| Old Syntax                | New Syntax                |
| ------------------------  |:-------------------------:|
|`addcomponent!`            |`add_comp!`                |
|`connectparameter`         |`connect_param!`           |
|`setleftoverparameters`    |`set_leftover_params!`     |
|`setparameter`             |`set_param!`               |
|`adddimension`             |`add_dimension!`           |
|`setindex`                 |`set_dimension!`           |  

Changes to various optional keyword arguments:

- `add_comp!`:  Through Mimi v0.9.4, the optional keyword arguments `first` and `last` could be used to specify times for components that do not run for the full length of the model, like this: `add_comp!(mymodel, ComponentC; first=2010, last=2100)`. This functionality is currently disabled, and all components must run for the full length of the model's time dimension. This functionality may be re-implemented in a later version of Mimi.

## Running a Model

## Accessing Results

## Plotting and the Explorer UI

This release of Mimi does not include the plotting functionality previously offered by Mimi.  While the previous files are still included, the functions are not exported as efforts are made to simplify and improve the plotting associated with Mimi.  

The new version does, however, include a new UI tool that can be used to visualize model results.  This `explore` function is described in the User Guide under **Advanced Topics**.

## Advanced Topics

#### Timesteps and available functions

As previously mentioned, some relevant function names have changed.  These changes were made to eliminate ambiguity.  For example, the new naming clarifies that `is_last` returns whether the timestep is on the last valid period to be run, not whether it has run through that period already.  This check can still be achieved with `is_finished`, which retains its name and function.  Below is a subset of such changes related to timesteps and available functions.

| Old Syntax                | New Syntax                |
| ------------------------  |:-------------------------:|
|`isstart`                  |`is_first`                 |
|`isstop`                   |`is_last`                  |    

As mentioned in earlier in this document, the fourth argument in `run_timestep` is an `AbstractTimestep` i.e. a `FixedTimestep` or a `VariableTimestep` and is a type defined within Mimi in "src/time.jl".  In this version, the fourth argument (`t` below) can no longer always be used simply as an `Int`. Defining the `AbstractTimestep` object as `t`, indexing with `t` is still permitted, but special care must be taken when comparing `t` with conditionals or using it in arithmatic expressions.  Since differential equations are commonly used as the basis for these models' equations, the most commonly needed change will be changing `if t == 1` to `if is_first(t)`.

The full API:

- you may index into a variable or parameter with `[t]` or `[t +/- x]` as usual
- to access the time value of `t` (currently a year) as a `Number`, use `gettime(t)`
- useful functions for commonly used conditionals are `is_first(t)` and `is_last(t)`
- to access the index value of `t` as a `Number` representing the position in the time array, use `t.t`.  Users are encouraged to avoid this access, and instead use the options listed above or a separate counter variable. each time the function gets called.  

#### Parameter connections between different length components

#### More on parameter indices

#### Updating an external parameter

To update an external parameter, use the functions `update_param!` and `update_params!` (previously known as `update_external_parameter` and `update_external_parameters`, respectively.)  Their calling signatures are:

*  `update_params!(md::ModelDef, parameters::Dict; update_timesteps = false)`

*  `update_param!(md::ModelDef, name::Symbol, value; update_timesteps = false)`

For external parameters with a `:time` dimension, passing `update_timesteps=true` indicates that the time _keys_ (i.e., year labels) should also be updated in addition to updating the parameter values.

#### Setting parameters with a dictionary

The function `set_leftover_params!` replaces the function `setleftoverparameters`.
