# Tutorials Introduction

The following tutorials target [Mimi](https://github.com/mimiframework/Mimi.jl) users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users go to the beginning and read the introductory [Welcome to Mimi](@ref) documentation. It will also be helpful to be comfortable with the basics of the [Julia](https://julialang.org/) language, though expertise is not required.

If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our [Mimi Framework forum](https://forum.mimiframework.org).  We welcome your feedback.

## Terminology

The following terminology is used throughout the documentation.

**Application Programming Interface (API):**  The public classes, methods, and functions provided by `Mimi` to facilitate construction of custom scripts and work with existing models. Function documentation provided in "docstrings" in the Reference Guides which define the Mimi API in more detail.

## Available Tutorials

1. **Install Mimi**

   [Tutorial 1: Install Mimi](@ref) steps through the tasks to install julia, Mimi, and the Mimi registry. 

2. **Run an Existing Model**

   [Tutorial 2: Run an Existing Model](@ref) steps through the tasks to download, run, and view the results of a registered model such as [FUND](http://www.fund-model.org).  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.

3. **Modify an Existing Model**

   [Tutorial 3: Modify an Existing Model](@ref) builds on Tutorial 2, showing how to modify an existing model such as [DICE](https://github.com/anthofflab/mimi-dice-2010.jl).

4. **Create a Model**

   [Tutorial 4: Create a Model](@ref) takes a step beyond using registered models, explaining how to create a model from scratch.

5. **Create a Composite Model**

   [Tutorial 5: Create a Composite Model](@ref) takes a step beyond using registered models, explaining how to create a **composite** model from scratch.

6. **Sensitivity Analysis**

   [Tutorial 6: Sensitivity Analysis (SA) Support](@ref) explores Mimi's Sensitivity Analysis support, using both the simple multi-Region tutorial model and MimiDICE2010 examples.


_Additional AERE Workshop Tutorials: The Mimi developement team recently participated in the 2019 Association of Environmental and Resource Economists (AERE) summer conference during the pre-conference workshop on Advances in Integrated Assessment Models. This included both a presentation and a hands-on session demonstrating various use cases for Mimi. The Github repository [here](https://github.com/davidanthoff/teaching-2019-aere-workshop) contains a) all slides from the workshop and b) all the code from the hands on sessions, which may be of interest to Mimi users. Importantly note that the linked code represents as a snapshot of Mimi at the time of the workshop, and **will not** be updated to reflect new changes._
