# Tutorial 1: Run an Existing Model

This tutorial walks through the steps to download, run, and view the output of an existing model.  There are several existing models publically available on Github for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

### Step 1. Download FUND

The first step in this process is downloading the FUND model.  First, open your command line interface and navigate to the folder where you would like to download FUND.

```
cd(<directory-path>) # directory-path is a placeholder for the string describing your desired file path
```

Next, clone the FUND repository from Github, enter the repository, and checkout the `next` branch, which holds the Julia version of FUND.

```
git clone https://github.com/fund-model/fund.git
cd("fund")
git checkout next
```
You have now successfully downloaded FUND to your local machine.

### Step 2. Run FUND

The next step is to run FUND.  If you wish to first get more aquainted with the model itself, take a look at the provided online documentation.  

In order to run FUND, you will need to open a Julia REPL (here done with the alias `julia`) and navigate to the source code folder, labeled `src`.

```
Julia 
cd(<fund-directory-path>) # fund-directory-path is a placeholder for the string describing your the file path of the downloaded `fund` folder from Step 1.
```

Next, run the main fund file `fund.jl` (make sure to have the packages `Distributions` and `StatsBase` installed -using `Pkg.add("StatsBase")`-.  This file defines a new [module](https://docs.julialang.org/en/v1/manual/modules/index.html) called `Fund`, which exports the function `getfund`, a function that returns a version of fund allowing for different user specifications.  Note that in order to allow access to the module, we must call `using .Fund`, where `.Fund` is a shortcut for `Main.Fund`, since the `Fund` module is nested inside the `Main` module. After creating the model `m`, simply run the model using the `run` function.

```
include("src/fund.jl")
using .Fund
m = getfund()
run(m)
```

Note that these steps should be relatively consistent across models, where a repository for `ModelX` should contain a primary file `ModelX.jl` which exports, at minimum, a function named something like `getModelX` or `construct_ModelX` which returns a version of the model, and can allow for model customization within the call.

In this case, the function `getfund` has the signature
``` 
getfund(; nsteps = default_nsteps, datadir = default_datadir, params = default_params)
```
Thus there are no required arguments, although the user can input `nsteps` to define the number of timesteps (years in this case) the model runs for, `datadir` to define the location of the input data, and `params`, a dictionary definining the parameters of the model.  For example, if you wish to see only the first 100 timesteps,you may use:
```
include("src/fund.jl")
using .Fund
m = getfund(nsteps = 100)
run(m)
```
### Step 3. Access Results: Values
After the model has been run, you may access the results (the calculated variable values in each component) in a few different ways.

Start off by importing the Mimi package to your space with 
```
using Mimi
```

First of all, you may use the `getindex` syntax as follows:

```julia
m[:ComponentName, :VariableName] # returns the whole array of values
m[:ComponentName, :VariableName][100] # returns just the 100th value

```
Indexing into a model with the name of the component and variable will return an array with values from each timestep. You may index into this array to get one value (as in the second line, which returns just the 100th value). Note that if the requested variable is two-dimensional, then a 2-D array will be returned. For example, try taking a look at the `income` variable of the `socioeconomic` component using the code below:
```
m[:socioeconomic, :income] 
m[:socioeconomic, :income][100] 
```

You may also get data in the form of a dataframe, which will display the corresponding index labels rather than just a raw array. The syntax for this uses [`getdataframe`](@ref) as follows:

```julia
getdataframe(m, :ComponentName=>:Variable) # request one variable from one component
getdataframe(m, :ComponentName=>(:Variable1, :Variable2)) # request multiple variables from the same component
getdataframe(m, :Component1=>:Var1, :Component2=>:Var2) # request variables from different components

```

Try doing this for the `income` variable of the `socioeconomic` component using:
```
getdataframe(m, :socioeconomic=>:income) # request one variable from one component
```

### Step 4. Access Results: Plots and Graphs

After running the FUND model, you may also explore the results using plots and graphs. 

Mimi provides support for plotting using [VegaLite](https://github.com/vega/vega-lite) and [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) within the Mimi Explorer UI, and the [LightGraphs](https://github.com/JuliaGraphs/LightGraphs.jl) and [MetaGraphs](https://github.com/JuliaGraphs/MetaGraphs.jl) for the [`plot_comp_graph`](@ref) function.

#### Explore

If you wish to explore the results graphically, use the explorer UI, described [here](http://anthofflab.berkeley.edu/Mimi.jl/stable/userguide/#Plotting-and-the-Explorer-UI-1) in Section 5 of the Mimi User Guide.

To explore all variables and parameters of FUND in a dynamic UI app window, use the [`explore`](@ref) function called with the model as the required first argument, and the optional argument of the `title`  The menu on the left hand side will list each element in a label formatted as `component: variable/parameter`.
```
explore(m, title = "My Window")
```
Alternatively, in order to view just one parameter or variable, call the function [`explore`](@ref) as below to return a plot object and automatically display the plot in a viewer, assuming [`explore`](@ref) is the last command executed.  This call will return the type `VegaLite.VLSpec`, which you may interact with using the API described in the [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) documentation.  For example, [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) plots can be saved as [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics), [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), [PDF](https://en.wikipedia.org/wiki/PDF) and [EPS](https://en.wikipedia.org/wiki/Encapsulated_PostScript) files. You may save a plot using the `save` function. Note that saving an interactive plot in a non-interactive file format, such as .pdf or .svg will result in a warning `WARN Can not resolve event source: window`, but the plot will be saved as a static image. If you wish to preserve interactive capabilities, you may save it using the .vegalite file extension. If you then open this file in Jupyter lab, the interactive aspects will be preserved.

```julia
using VegaLite
run(m)
p = explore(m, component1, parameter1)
save("MyFilePath.svg", p)
```
More specifically for our tutorial use of FUND, try:

```julia
using VegaLite
p = explore(m, :socioeconomic, :income)
save("MyFilePath.svg", p)
```

#### Component Graph

In order to view a DAG representing the component ordering and relationships, use the [`plot_comp_graph`](@ref) function to view a plot and optionally save it to a file. This function returns a plot object displayed in the viewer and showing a graph with components as nodes and component connections as edges.

```julia
plot_comp_graph(m, "MyFilePath.png")
```
### Step 4. Tutorial 2

Next, feel free to move on to the second tutorial, which will go into depth on how to **modify** an existing model such as FUND!
