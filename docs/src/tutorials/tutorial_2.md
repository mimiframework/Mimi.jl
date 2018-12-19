# Tutorial 2: Modify an Existing Model

This tutorial walks through the steps to modify an existing model.  There are several existing models public on Github, and for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download. 

Futhermore, and especially relevant for the application portion of this tutorial, if you are not yet comfortable with downloading (only needs to be done once) and running FUND, refer to Tutorial 1 for instructions.  Carry out **Steps 1 and 2** from Tutorial 1, and then return to continue with this tutorial.

## The API

There are various ways to modify an existing model, and this section aims to introduce the Mimi API relevant to this broad category of tasks.  It is important to note that regardless of the goals and complexities of user modifications, the API aims to allow for modification **without user alteration of the original code for the model being modified**.  Instead, users will download and run the new model, and then use API calls to modify it. This means that in practice, users should not need to alter the source code of the model they are modifying. Thus, it is easy to keep up with any external updates or improvements made to that model.

Possible modifications range in complexity, from simply altering parameter values, to adjusting an existing component, to adding a brand new component. These will take advantage of the public API listed [here](http://anthofflab.berkeley.edu/Mimi.jl/dev/reference/), as well as other functions listed in the Mimi Documentation.

### Parametric Changes

Several types of changes to models revolve around the parameters themselves, and may include updating the values of parameters and changing parameter connections without altering the elements of the components themselves or changing the general component structure of the model.  The most useful functions of the common API in these cases are likely **`update_param(s)!`, `disconnect_param!`, and `connect_param!`**.  For detail on these functions look at the API reference [here](http://anthofflab.berkeley.edu/Mimi.jl/dev/reference/).

When `set_param!` is called in the original model, it creates an external parameter by the name provided, and stores the provided scalar or array value. The functions `update_param!` and `update_params` allow the user to change the value associated with this external parameter.  Note that if the external parameter has a `:time` dimension, use the optional argument `update_timesteps=true` to indicate that the time keys (i.e., year labels) associated with the parameter should be updated in addition to updating the parameter values.

```julia
update_param!(mymodel, :parametername, newvalues) # update values only 

update_param!(mymodel, :parametername, newvalues, update_timesteps=true) # also update time keys
```

Also note that in the code above,`newvalues` must be the same size and type (or be able to convert to the type) of the old values stored in that parameter.

If a user wishes to alter the connections within an existing model, `disconnect_param!` and `connect_param` can be used in conjunction with each other to update the connections within the model, although this is more likely to be done as part of larger changes involving components themslves, as discussed in the next subsection.

### Component Changes

Most existing model modifications will include not only parametric updates, but also component modification, addition, replacement, and deletion along with the required re-wiring of parameters etc. The most useful functions of the common API, in these cases are likely **`replace_comp!`, `add_comp!`** along with **`Mimi.delete!`** and the requisite functions for parameter setting and connecting.  For detail on the public API functions look at the API reference [here](http://anthofflab.berkeley.edu/Mimi.jl/dev/reference/). 

Users who wish to modify the component structure would also do well to look into the **built-in helper components`adder`, `ConnectorCompVector`, and `ConnectorCompMatrix`** in the `src\components` folder, as these can prove quite useful.  

* `adder.jl` -- Defines `Mimi.adder`, which simply adds two parameters, `input` and `add` and stores the result in `output`.

* `connector.jl` -- Defines a pair of components, `Mimi.ConnectorCompVector` and `Mimi.ConnectorCompMatrix`. These copy the value of parameter `input1`, if available, to the variable `output`, otherwise the value of parameter `input2` is used. It is an error if neither has a value.

## Steps to Modify to FUND (TODO)

### Step 1.

### Step 2.

### Step 3.
 