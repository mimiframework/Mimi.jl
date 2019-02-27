# Introduction

The following tutorials target [Mimi](https://github.com/anthofflab/Mimi.jl) users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the [Welcome to Mimi](@ref) documentation, including the [User Guide](@ref), and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the [Julia](https://julialang.org/) language, though expertise is not required.

If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our [Mimi Framework forum](https://forum.mimiframework.org).  We welcome your feedback.

## Terminology

The following terminology is used throughout the documentation.

**Application Programming Interface (API):**  The public classes, methods, and functions provided by `Mimi` to facilitate construction of custom scripts and work with existing models. Function documentation provided in "docstrings" in the [Reference](@ref) define the Mimi API in more detail.

## Available Tutorials

1. **Run an Existing Model**

   [Tutorial 1: Run an Existing Model](@ref) steps through the tasks to download, run, and view the results of a registered model such as [FUND](http://www.fund-model.org).  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.

2. **Modify an Existing Model**

    _While the instructions in this tutorial are informative, the code examples are based on Mimi DICE-2010 which is not currently publically available, so the use is currently limited.  This issue will be resolved soon._

   [Tutorial 2: Modify an Existing Model](@ref) builds on Tutorial 1, showing how to modify an existing model such as [DICE](https://github.com/anthofflab/mimi-dice-2010.jl).

3. **Create a Model**

   [Tutorial 3: Create a Model](@ref) takes a step beyond using registered models, explaining how to create a model from scratch.

4. **Monte Carlo Simulation**

   [Tutorial 4: Monte Carlo Simulation (MCS) Support](@ref) explores Mimi's Monte Carlo Simulation support, using both the simple 2-Region tutorial model and [FUND](http://www.fund-model.org) examples.


## Requirements and Initial Setup

These tutorials require [Julia v1.0.0](https://julialang.org/downloads/) and [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl), or later. You will also need to use [Github](https://github.com) and thus download [Git](https://git-scm.com/downloads).

To use the following tutorials, follow the steps below.

1. Download Git [here](https://git-scm.com/downloads).

2. Download the latest version of Julia [here](https://julialang.org/downloads/), making sure that your downloaded version is v1.0.0 or later.

3. Open a Julia REPL, and enter `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode, and then type `add Mimi` to install the latest tagged version of Mimi, which must be version 0.6.0 or later.

```
pkg> add Mimi
```

We also recommend that you frequently update your packages and requirements using the `update` command, which can be abbreviated `up`:
```
pkg> up
```

You are now ready to begin the tutorials!
