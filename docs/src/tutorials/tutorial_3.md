# Tutorial 3: Modify an Existing Model

This tutorial walks through the steps to modify an existing model.  There are several existing models publically available on Github, and for the purposes of this tutorial we will use the `MimiDICE2010` model.

Working through the following tutorial will require:

- [Julia v1.4.0](https://julialang.org/downloads/) or higher
- [Mimi v0.10.0](https://github.com/mimiframework/Mimi.jl) or higher
- connection of your julia installation with the central Mimi registry of Mimi models

**If you have not yet prepared these, go back to the first tutorial to set up your system.**

## Introduction

There are various ways to modify an existing model, and this tutorial aims to introduce the Mimi API relevant to this broad category of tasks.  It is important to note that regardless of the goals and complexities of your modifications, the API aims to allow for modification **without alteration of the original code for the model being modified**.  Instead, you will download and run the existing model, and then use API calls to modify it. This means that in practice, you should not need to alter the source code of the model you are modifying. This should make it simple to keep up with any external updates or improvements made to that model. 

Possible modifications range in complexity, from simply altering parameter values, to adjusting an existing component, to adding a brand new component.

## Parametric Modifications: The API

Several types of changes to models revolve around the parameters themselves, and may include updating the values of parameters and changing parameter connections without altering the elements of the components themselves or changing the general component structure of the model.  The most useful functions of the common API in these cases are likely [`update_param!`](@ref)/[`update_params!`](@ref), [`add_shared_param!`](@ref), [`disconnect_param!`](@ref) and [`connect_param!`](@ref).  For detail on these functions see the [How-to Guide 5: Work with Parameters and Variables](@ref) and the API reference guide, [Reference Guide: The Mimi API](@ref).

By the Mimi structure, the parameters in a model you start with receive their values either from an exogenously set model parameters (shared or unshared as described in How To Guide 5) through an external parameter connection, or from another component's variable through an internal parameter connection.

The functions [`update_param!`](@ref) and [`update_params!`](@ref) allow you to change the value associated with a given model parameter, and thus value connected to the respective component-parameter pair(s) connected to it. If the model parameter is a shared model parameter you can use the following to update it:
```julia
update_param!(mymodel, :model_parameter_name, newvalues)
```
If the model parameter is unshared, and thus the value can only be connected to one component/parameter pair, you can use the following to update it:
```julia
update_param!(mymodel, :comp_name, :param_name, newvalues)
```
Note here that `newvalues` must be the same type (or be able to convert to the type) of the old values stored in that parameter, and the same size as the model dimensions indicate. 

**If you are unsure whether the component-parameter pair you wish to update is connected to a shared or unshared model parameter** use the latter, four argument call above and an error message will give you specific instructions on how to proceed. As described in How To Guide 5, parameters default to being unshared.

The functions [`disconnect_param!`](@ref) and [`connect_param!`](@ref) can be used to alter or add connections within an existing model. These two can be used in conjunction with each other to update the connections within the model, although this is more likely to be done as part of larger changes involving components themselves, as discussed in the next subsection.

**Once again, for specific instructions and details on various cases of updating and changing parameters, and their connections, please view [How-to Guide 5: Work with Parameters and Variables](@ref).  We do not repeat all information here for brevity and to avoid duplication.**

## Parametric Modifications: DICE Example

#### Step 1. Download MimiDICE2010

The first step in this process is downloading the DICE2010 model, which is now made easy with the Mimi registry. Assuming you have already done the one-time run of the following to connect your julia installation with the central Mimi registry of Mimi models,

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

you simply need to add the MimiDICE2010 model in the Pkg REPL with:
```julia
pkg> add MimiDICE2010
```
You have now successfully downloaded MimiDICE2010 to your local machine.

#### Step 2. Run DICE

The next step is to run DICE using the provided API for the package:

```julia
using MimiDICE2010
m = MimiDICE2010.get_model()
run(m)
```

These steps should be relatively consistent across models, where a repository for `ModelX` should contain a primary file `ModelX.jl` which exports, at minimum, a function named something like `get_model` or `construct_model` which returns a version of the model, and can allow for model customization within the call.

In this case, the function `MimiDICE2010.get_model()` has the signature

```julia
get_model(params=nothing)
```

Thus there are no required arguments, although the user can input `params`, a dictionary definining the parameters of the model. If nothing is provided, the model will be built with the default parameters for DICE2010.

#### Step 3. Altering Parameters

In the case that you wish to alter an parameter retrieving an exogenously set value from a model parameter, you may use the [`update_param!`](@ref) function.  Per usual, you will start by importing the Mimi package to your space with 

```julia
using Mimi
```

In DICE the parameter `fco22x` is the forcings of equilibrium CO2 doubling in watts per square meter, and is a shared model parameter (named `fco22x`) and connected to component parameters with the same name, `fco22x`, in components `climatedynamics` and `radiativeforcing`.  We can change this value from its default value of `3.200` to `3.000` in both components, using the following code:

```julia
update_param!(m, :fco22x, 3.000)
run(m)
```

A more complex example may be a situation where you want to update several parameters, including some with a `:time` dimension, in conjunction with altering the time index of the model itself. DICE uses a default time horizon of 2005 to 2595 with 10 year increment timesteps.  If you wish to change this, say, to 1995 to 2505 by 10 year increment timesteps and use parameters that match this time, you could use the following code:

First you update the `time` dimension of the model as follows:

```julia
const ts = 10
const years = collect(1995:ts:2505)
nyears = length(years)
set_dimension!(m, :time, years)
```

At this point all parameters with a `:time` dimension have been slightly modified under the hood, but the original values are still tied to their original years.  In this case, for example, the model parameter has been shorted by 9 values (end from 2595 --> 2505) and padded at the front with a value of `missing` (start from 2005 --> 1995). Since some values, especially initializing values, are not time-agnostic, we maintain the relationship between values and time labels.  If you wish to attach new values, you can use [`update_param!`](@ref) as below.  In this case this is probably necessary, since having a `missing` in the first spot of a parameter with a `:time` dimension will likely cause an error when this value is accessed.

Updating the `:time` dimension can be tricky, depending on your use case, so **we recommend reading [How-to Guide 6: Update the Time Dimension](@ref)** if you plan to do this often in your work.

To batch update **shared** model parameters, create a dictionary `params` with one entry `(k, v)` per model parameter you want to update by name `k` to value `v`. Each key `k` must be a symbol or convert to a symbol matching the name of a shared model parameter that already exists in the model definition.  Part of this dictionary may look like:

```julia
params = Dict{Any, Any}()
params[:a1]         = 0.00008162
params[:a2]         = 0.00204626
...
params[:S]          = repeat([0.23], nyears)
...
```

To batch update **unshared** model parameters, follow a similar pattern but use tuples (:comp_name, :param_name) as your dictionary keys, which might look like:

```julia
params = Dict{Any, Any}()
params[(:comp1, :a1)]         = 0.00008162
params[(:comp1, :a2)]         = 0.00204626
...
params[(:comp2, :S)]          = repeat([0.23], nyears)
...
```
Finally, you can combine these two dictionaries and Mimi will recognize and resolve the two different key types under the hood. 

Now you simply update the parameters listen in `params` and re-run the model with

```julia
update_params!(m, params)
run(m)
```
## Component and Structural Modifications: The API

Most model modifications will include not only parametric updates, but also structural changes and component modification, addition, replacement, and deletion along with the required re-wiring of parameters etc. 

We recommend trying to use the user-facing API to modify existing models by importing the model (and with it its various components) as demonstrated in examples such as [MimiFUND-MimiFAIR-Flat.jl](https://github.com/anthofflab/MimiFUND-MimiFAIR-Flat.jl/blob/main/MimiFUND-MimiFAIR-Flat.ipynb) from Tutorial 7.  When this API is not satisfactory, you may wish to make changes directly to the model repository, which for many completed models is configured as a julia Package. **In this case, the use of environments and package versioning may become one level more complicated, so please do not hesitate to reach out on the forum** for up-front help on workflow ... pausing for a moment to get that straight **will save you a lot of time**.  We will work on getting standard videos and tutorials up as resources as well.

The most useful functions of the common API, in these cases are likely **[`replace!`](@ref), [`add_comp!`](@ref)** along with **`delete!`** and the requisite functions for parameter setting and connecting.  For detail on the public API functions look at the API reference. 

If you wish to modify the component structure we recommend you also look into the **built-in helper components `adder`, `multiplier`,`ConnectorCompVector`, and `ConnectorCompMatrix`** in the `src/components` folder, as these can prove quite useful.  

* `adder.jl` -- Defines `Mimi.adder`, which simply adds two parameters, `input` and `add` and stores the result in `output`.

* `multiplier.jl` -- Defines `Mimi.multiplier`, which simply multiplies two parameters, `input` and `multiply` and stores the result in `output`.

* `connector.jl` -- Defines a pair of components, `Mimi.ConnectorCompVector` and `Mimi.ConnectorCompMatrix`. These copy the value of parameter `input1`, if available, to the variable `output`, otherwise the value of parameter `input2` is used. It is an error if neither has a value.

## Component and Structural Modifications: DICE Example

This example is in progress and will be built out soon.

----
Next, feel free to move on to the next tutorial, which will go into depth on how to **create** your own model.
