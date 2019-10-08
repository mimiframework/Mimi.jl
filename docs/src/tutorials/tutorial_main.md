# Introduction

The following tutorials target [Mimi](https://github.com/mimiframework/Mimi.jl) users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the [Welcome to Mimi](@ref) documentation, including the [User Guide](@ref), and refer back to those documents as needed to follow the tutorials.  It will also be helpful to be comfortable with the basics of the [Julia](https://julialang.org/) language, though expertise is not required.

If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our [Mimi Framework forum](https://forum.mimiframework.org).  We welcome your feedback.

## Terminology

The following terminology is used throughout the documentation.

**Application Programming Interface (API):**  The public classes, methods, and functions provided by `Mimi` to facilitate construction of custom scripts and work with existing models. Function documentation provided in "docstrings" in the [Reference](@ref) define the Mimi API in more detail.

## Available Tutorials

1. **Run an Existing Model**

   [Tutorial 1: Run an Existing Model](@ref) steps through the tasks to download, run, and view the results of a registered model such as [FUND](http://www.fund-model.org).  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.

2. **Modify an Existing Model**

   [Tutorial 2: Modify an Existing Model](@ref) builds on Tutorial 1, showing how to modify an existing model such as [DICE](https://github.com/anthofflab/mimi-dice-2010.jl).

3. **Create a Model**

   [Tutorial 3: Create a Model](@ref) takes a step beyond using registered models, explaining how to create a model from scratch.

4. **Sensitivity Analysis**

   [Tutorial 4: Sensitivity Analysis (SA) Support](@ref) explores Mimi's Sensitivity Analysis support, using both the simple 2-Region tutorial model and [FUND](http://www.fund-model.org) examples.


_Additional AERE Workshop Tutorials: The Mimi developement team recently participated in the 2019 Association of Environmental and Resource Economists (AERE) summer conference during the pre-conference workshop on Advances in Integrated Assessment Models. This included both a presentation and a hands-on session demonstrating various use cases for Mimi. The Github repository [here](https://github.com/davidanthoff/teaching-2019-aere-workshop) contains a) all slides from the workshop and b) all the code from the hands on sessions, which may be of interest to Mimi users. Importantly note that the linked code represents as a snapshot of Mimi at the time of the workshop, and **will not** be updated to reflect new changes._

## Requirements and Initial Setup

These tutorials require [Julia v1.1.0](https://julialang.org/downloads/) and [Mimi v0.9.4](https://github.com/mimiframework/Mimi.jl), or later. 

To use the following tutorials, follow the steps below.

1. Download the latest version of Julia [here](https://julialang.org/downloads/), making sure that your downloaded version is v1.1.0 or later.

2. Open a Julia REPL, and enter `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) mode, and then type `add Mimi` to install the latest tagged version of Mimi, which must be version 0.9.4 or later.

```
pkg> add Mimi
```

4. To access the models in the [MimiRegistry](https://github.com/mimiframework/Mimi.jl), you first need to connect your julia installation with the central Mimi registry of Mimi models. This central registry is like a catalogue of models that use Mimi that is maintained by the Mimi project. To add this registry, run the following command at the julia package REPL:

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You only need to run this command once on a computer. 

From there you will be add any of the registered packages, such as MimiDICE2010.jl by running the following command at the julia package REPL:

```julia
pkg> add MimiDICE2010
```

5. We also recommend that you frequently update your packages and requirements using the `update` command, which can be abbreviated `up`:
```
pkg> up
```

You are now ready to begin the tutorials!
