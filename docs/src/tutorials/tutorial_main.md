# Introduction

The following set of tutorials aim to fulfill the needs of [Mimi](https://github.com/anthofflab/Mimi.jl) users of various experience levels, starting with first-time users.  Before engaging with these tutorials, it is recommended that users read the [documentation](http://anthofflab.berkeley.edu/Mimi.jl/latest/), including the [User Guide](http://anthofflab.berkeley.edu/Mimi.jl/latest/userguide.html), and refer back to this documentation as reference throughout the tutorials.  It will also be helpful to be somewhat comfortable with the basics of the [Julia](https://julialang.org/) language, though expertise is not required.

If at any point during these tutorials you find a bug, or have a clarifying question or suggestion, do not hesitate to reach out via Github Issues on or our designated [Mimi.jl/dev](https://gitter.im/anthofflab/Mimi.jl/dev) gitter chat room.  We welcome feedback so that we can make sure they are as useful as possible.

# Terminology

The following terminology is used throughout the documentation. The documentation of docstrings in the [reference](http://anthofflab.berkeley.edu/Mimi.jl/latest/reference.html) should also be useful for looking up portions of the Mimi API.

**API or Application Programming Interface:**  The public classes, methods, and function provided by `Mimi` to facilitate construction of custom scripts and work with existing models.  A list displaying the exported Mimi public API can be found [here](http://anthofflab.berkeley.edu/Mimi.jl/dev/reference/).

# Available Tutorials

1. Tutorial 1 Run an Existing Model: Tutorial 1 steps through the tasks to download, run, and view the results of a registered model such as [FUND](http://www.fund-model.org).  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.

2. Tutorial 2 Modify an Existing Model: Tutorial 2 immediately follows Tutorial 1 above, and shows users how to modify an existing model such as [DICE](https://github.com/anthofflab/mimi-dice-2010.jl).

3.  Tutorial 3 Create a Model: Tutorial 3 takes users a step further from using registered models, and instructs them on creating their own models from scratch.

4.  Tutorial 4 Monte Carlo Simulation Support: Tutorial 4 takes users through exploring Mimi's Monte Carlo Simulation support, using both the internal 2-Region Model and [FUND](http://www.fund-model.org) working examples.  

# Requirements and Initial Setup

Employing these tutorials will require the use of [Julia v1.0.0](https://julialang.org/downloads/) or higher as well as [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) or higher. You will also need to use [Github](https://github.com) and thus download [Git](https://git-scm.com/downloads).

To use the following tutorials, follow the steps below.

1. Download Git [here](https://git-scm.com/downloads).

2. Download the latest version of Julia [here](https://julialang.org/downloads/), making sure that your downloaded version is v1.0.0 or later.

3. Open a Julia REPL, and enter `]` to enter the [Pkg REPL](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) and then type `add Mimi` to install the latest tagged version of Mimi, which must be version 0.6.0 or later.

```
]add Mimi
```

We also recommend that you frequently update your packages and requirements using `]up`
```
]up
```

Once you have followed these steps, you are ready to begin the tutorials!
