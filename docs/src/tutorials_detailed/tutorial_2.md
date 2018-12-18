# Tutorial 2: Modify an Existing Model

This tutorial walks through the steps to modify an existing model.  There are several existing models public on Github, and for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download. 

Futhermore, and especially relevant for the application portion of this tutorial, if you are not yet comfortable with downloading (only needs to be done once) and running FUND, refer to Tutorial 1 for instructions.  Carry out **Steps 1 and 2** from Tutorial 1, and then return to continue with this tutorial.

## Modification API

There are various ways to modify an existing model, and this section aims to introduce the Mimi API relevant to this broad category of tasks.  It is important to note that regardless of the goals and complexities of user modifications, the API aims to allow for modification **without user alteration of the original code for the model being modified**.  Instead, users will download and run the new model, and then use API calls to modify it. This means that in practice, users should not need to alter the source code of the model they are modifying. Thus, it is easy to keep up with any external updates or improvements made to that model.

Possible modifications range in complexity, from simply altering parameter values, to adjusting an existing component, to adding a brand new component. These will take advantage of the public API listed [here](http://anthofflab.berkeley.edu/Mimi.jl/dev/reference/), as well as other functions listed in the Mimi Documentation.

### Parametric Changes (TODO)
- `set_param!`

### Structural Changes (TODO)
- Parameters: `disconnect_param!`, `connect_param!`, and `update_params!`
- Components: `replace_comp`, `new_comp`, `delete!`, and `add_comp!` 

## Steps to Modify to FUND (TODO)

### Step 1.

### Step 2.

### Step 3.
 