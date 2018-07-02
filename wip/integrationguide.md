# Integration Guide

## Overview

The release of Mimi v0.5.0 is a breaking release, necessitating the adaptation of existing models' syntax and structure in order for those models to run on this new version.  This guide describes the minimum required steps in order to get your model working with v0.5.0.  FOr more information on the new functionalities in v0.5.0, including options for setting defualt parameters, working with marginal models, and a new Monte Carlo Simulation framework, see the documentation.

This guide is organized into xxx main sections, which describes edits that are independent and can be undertaken in any order desired.  For clarity, these sections echo the organization of the `userguide`.

1) Defining components
2) Constructing a model
3) Running the model
4) Accessing results
5) Plotting
6) Advanced topics

## Defining Components

The `run_timestep` function is now contained by the `@defcomp` macro, and takes the parameters `p, v, d, t`, referring to Parameters, Variables, and Dimensions of the component you defined.  The fourth argument is a Timestep, which represents which timestep the model is at each time the function gets called.  Similarly, the optional `init` function is also contained by `@defcomp`, and takes the parameters `p, v, d`.

## Constructing a Model

In an effort to standardize the function naming protocol within Mimi, and to streamline it with the standards of Julia,several function names have been changed.  Below are listed the a subset of these changed functions, focused on the exported user-facing API functions most commonly changed when adapting Mimi model constructoin to v0.5.0.  A complete list can be found in the current documentation or in `Mimi.jl`.

| Old Syntax                | New Syntax                |
| ------------------------  |:-------------------------:|
|`connectparameter`         |`connect_parameter`        |
|`setleftoverparameters`    |`set_leftover_params!`     |
|`setparameter`             |`set_parameter!`           |

In the case that a specific component parameter is connected to a variable of another component with an offset, meaning that this parameter can only be evaluated *after* the connected component has been run for a certain number of teimsteps, use the optional `offset` keyword argument to specify the offset in terms of timesteps such as:  

```julia
connect_parameter(mymodel, :TargetComponent=>:parametername, :SourceComponent=>:variablename, offset = 1)
```
                        
In order to finish connecting components, it is necessary to run `add_connector_comps` as below:

```julia
add_connector_comps(mymodel)

```

## Running a Model

As previously mentioned, some relevant function names have changed.  Below is a subset of such changes related to running a model.

| Old Syntax                | New Syntax                |
| ------------------------  |:-------------------------:|
|`adddimension`             |`add_dimension`            |
|`setindex`                 |`set_dimension!`           |          

## Accessing Results

## Plotting

This release of Mimi does not include the plotting functionality previously offered by Mimi.  While the previous files are still included, the functions are not exported as efforts are made to simplify and improve the plotting associated with Mimi.  

The new version does, however, include a new UI tool that can be used to visualize model results.  This `explore` funcion is described in the below section.

## Advanced Topics

### Timesteps and available functions

As previously mentioned, some relevant function names have changed.  Below is a subset of such changes related to timesteps and available functions.

| Old Syntax                | New Syntax                |
| ------------------------  |:-------------------------:|
|`isstart`                  |`is_first`                 |
|`isstop`                   |`is_last`                  |    

### Parameter connections between different length components

### More on parameter indices

### Updating an external parameter

The function `update_external_parameter` is now written as `update_external_param`.

### Setting parameters with a dictionary

The function `setleftoverparameters` is now written as `set_leftover_params!`.

### Using NamedArrays for setting parameters

### The internal 'build' function and model instances

###  The explorer UI
 
 The new `explore` function allows the user to view and explore the variables and parameters of a model run.  To invoke the explorer UI, simply call the function `explore` with the model run as the required argument, and a window title as an optional keyword argument, as shown below.  This will produce a new browser window containing a selectable list of parameters and variables, organized by component, each of which produces a graphic.  The exception here being that if the parameter or variable is a single scalar value, the value will appear alongside the name in the left-hand list.
 
 ```julia
 run1 = run(my_model)
 explore(run1, title = "run1 results")
 
 ```




