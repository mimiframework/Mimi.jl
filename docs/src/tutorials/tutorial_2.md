# Tutorial 2: Run an Existing Model

This tutorial walks through the steps to download, run, and view the output of an existing model.  There are several existing models publically available on Github, and for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.4.0](https://julialang.org/downloads/) or higher
- [Mimi v0.10.0](https://github.com/mimiframework/Mimi.jl) or higher
- connection of your julia installation with the central Mimi registry of Mimi models

**If you have not yet prepared these, go back to the first tutorial to set up your system.**

Note that we have recently released Mimi v1.0.0, which is a breaking release and thus we cannot promise backwards compatibility with version lower than v1.0.0 although several of these tutorials may run properly with older versions. For assistance updating your own model to v1.0.0, or if you are curious about the primary changes made, see the How-to Guide on porting to Mimi v1.0.0. Mimi v0.10.0 is functionally dentical to Mimi v1.0.0, but includes deprecation warnings instead of errors to assist users in porting to v1.0.0.

#### Step 1. Download FUND

The first step in this process is downloading the FUND model, which is now made easy with the Mimi registry. Assuming you have already done the one-time run of the following command to connect your julia installation with the central Mimi registry of Mimi models, as instructed in the first tutorial,

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

you simply need to add the FUND model in the Pkg REPL with:

```julia
pkg> add MimiFUND
```

#### Step 2. Run FUND

The next step is to run FUND. If you wish to first get more acquainted with the model itself, take a look at the provided online [documentation](http://www.fund-model.org).

Now open a julia REPL and type the following command to load the MimiFUND package into the current environment:

```jldoctest tutorial2; output = false, filter = r".*"s
using MimiFUND

# output

```
Now we can access the public API of FUND, including the function `MimiFUND.get_model`. This function returns a copy of the default FUND model. Here we will first get the model, and then use the `run` function to run it.

```jldoctest tutorial2; output = false, filter = r".*"s
m = MimiFUND.get_model()
run(m)

# output

```

These steps should be relatively consistent across models, where a repository for `ModelX` should contain a primary file `ModelX.jl` which exports, at minimum, a function named something like `get_model` or `construct_model` which returns a version of the model, and can allow for model customization within the call.

In the MimiFUND package, the function `get_model` has the signature

```julia
get_model(; nsteps = default_nsteps, datadir = default_datadir, params = default_params)
```

Thus there are no required arguments, although the user can input `nsteps` to define the number of timesteps (years in this case) the model runs for, `datadir` to define the location of the input data, and `params`, a dictionary definining the parameters of the model.  For example, if you wish to run only the first 200 timesteps, you may use:

```jldoctest tutorial2; output = false, filter = r".*"s
using MimiFUND
m = MimiFUND.get_model(nsteps = 200)
run(m)

# output

```

#### Step 3. Access Results: Values
After the model has been run, you may access the results (the calculated variable values in each component) in a few different ways.

Start off by importing the Mimi package to your space with

```jldoctest tutorial2; output = false
using Mimi

# output

```

First of all, you may use the `getindex` syntax as follows:

```julia
m[:ComponentName, :VariableName] # returns the whole array of values
m[:ComponentName, :VariableName][100] # returns just the 100th value

```

Indexing into a model with the name of the component and variable will return an array with values from each timestep. You may index into this array to get one value (as in the second line, which returns just the 100th value). Note that if the requested variable is two-dimensional, then a 2-D array will be returned. For example, try taking a look at the `income` variable of the `socioeconomic` component of FUND using the code below:

```jldoctest tutorial2; output = false
m[:socioeconomic, :income]
m[:socioeconomic, :income][100]

# output

20980.834204000927
```

You may also get data in the form of a dataframe, which will display the corresponding index labels rather than just a raw array. The syntax for this uses [`getdataframe`](@ref) as follows:

```julia
getdataframe(m, :ComponentName=>:Variable) # request one variable from one component
getdataframe(m, :ComponentName=>(:Variable1, :Variable2)) # request multiple variables from the same component
getdataframe(m, :Component1=>:Var1, :Component2=>:Var2) # request variables from different components
```

Try doing this for the `income` variable of the `socioeconomic` component using:

```jldoctest tutorial2; output = false, filter = r".*"s
getdataframe(m, :socioeconomic=>:income) # request one variable from one component
getdataframe(m, :socioeconomic=>:income)[1:16,:] # results for all regions in first year (1950)

# output

```

#### Step 4. Access Results: Plots and Graphs

After running the FUND model, you may also explore the results using plots and graphs.

Mimi provides support for plotting using [VegaLite](https://github.com/vega/vega-lite) and [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) within the Mimi Explorer UI.

#### Explore

If you wish to explore the results graphically, use the explorer UI. This functionality is described in more detail in the second how-to guide, How-to Guide 2: View and Explore Model Results. For now, however, you don't need this level of detail and can simply follow the steps below.

To explore all variables and parameters of FUND in a dynamic UI app window, use the [`explore`](@ref) function called with the model as the required first argument.  The menu on the left hand side will list each element in a label formatted as `component: variable/parameter`.

```julia
explore(m)
```

Alternatively, in order to view just one parameter or variable, call the function [`explore`](@ref) as below to return a plot object and automatically display the plot in a viewer, assuming [`explore`](@ref) is the last command executed.  This call will return the type `VegaLite.VLSpec`, which you may interact with using the API described in the [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) documentation.  For example, [VegaLite.jl](https://github.com/fredo-dedup/VegaLite.jl) plots can be saved as [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics), [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), [PDF](https://en.wikipedia.org/wiki/PDF) and [EPS](https://en.wikipedia.org/wiki/Encapsulated_PostScript) files. You may save a plot using the `save` function. 

Note that saving an interactive plot in a non-interactive file format, such as .pdf or .svg will result in a warning `WARN Can not resolve event source: window`, but the plot will be saved as a static image. If you wish to preserve interactive capabilities, you may save it using the .vegalite file extension. If you then open this file in Jupyter lab, the interactive aspects will be preserved.

```julia
p = Mimi.plot(m, :mycomponent, :myvariable)
save("MyFilePath.svg", p)
```

More specifically for our tutorial use of FUND, try:

```julia
p = Mimi.plot(m, :socioeconomic, :income)
save("MyFilePath.svg", p)
```
----

You're done!  Now feel free to move on to the next tutorial, which will go into depth on how to **modify** an existing model such as FUND.
