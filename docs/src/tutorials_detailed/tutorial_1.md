# Tutorial 1: Explore an Existing Model

This tutorial walks through the steps to download, run, and view the output of an existing model.  There are several existing models public on Github, and for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

## Step 1. Download FUND

The first step in this process is downloading the FUND model.  Open a Julia REPL (here done with the alias command `Julia`) and navigate to the folder where you would like to download FUND.

```
Julia 
cd("directory")
```

Next, clone the existing FUND repository from Github and enter the new repository.
```
git clone https://github.com/fund-model/fund.git
cd("fund")
```

You have now successfully downloaded FUND to your local machine.

## Step 2. Run FUND

The next step is to run FUND.  If you wish to first get more aquainted with the model itself, take a look at the provided online documentation.  

In order to run FUND, you will need to navigate to the source code folder, labeled `src`, and run the main fund file `fund.jl`.  This file defines a new [module](https://docs.julialang.org/en/v1/manual/modules/index.html) called `Fund`, which exports the function `getfund`, a function that returns a version of fund allowing for different user specifications.  Note that in order to allow access to the module, we must call `using .Fund`, where `.Fund` is a shortcut for `Main.Fund`, since the `Fund` module is nested inside the `Main` module. After creating the model `m`, simply run the model using the `run` function.

```
include("src\fund.jl")
using .Fund
m = getfund
run(m)
```

Note that these steps should be relatively consistent across models, where a repository for `ModelX` should contain a primary file `ModelX.jl` which exports, at minimum, a function named something like `getModelX` which returns a version of the model, and can allow for model customization within the call.

In this case, the function `getfund` has the declaration
``` 
getfund(; nsteps = default_nsteps, datadir = default_datadir, params = default_params)
```
Thus there are no required arguments, although the user can input `nsteps` to define the number of timesteps (years in this case) the model runs for, `datadir` to define the location of the input data, and `params`, a dictionary definining the parameters of the model.  For example, if you wish to see only the first 100 timesteps,you may use
```
include("src\fund.jl")
using .Fund
m = getfund(nsteps = 100)
run(m)
```
## Step 3. Access Results: Values
<!-- TODO -->

## Step 4. Access Results: Plots and Graphs

Now that you have run the FUND model, you may explore the results.  If you wish to explore the results graphically, use the explorer UI, described [here](http://anthofflab.berkeley.edu/Mimi.jl/stable/userguide/#Plotting-and-the-Explorer-UI-1) in section 5 of the Mimi User Guide.

To explore all variables and parameters of FUND in a dynamic UI app window, use the `explore` function called with the model as the required first argument, and the optional argument of the `title`  The menu on the left hand side will list each element in a label formatted as `component: variable/parameter`.
```
explore(m, "My Window")
```
<!-- TODO: plot and save single graphs
TODO: plot_comp_graph -->
