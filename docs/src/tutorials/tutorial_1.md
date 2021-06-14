# Tutorial 1: Install Mimi

This tutorial describes how to set up your system by installing julia, Mimi, and the Mimi registry.

## Installing julia

Mimi requires the programming language [julia](http://julialang.org/) to run. You can download the current release from the julia [download page](http://julialang.org/downloads/). You should download and install the command line version from that page.

## Editor support

There are various editors around that have julia support, including the following:

- [IJulia](https://github.com/JuliaLang/IJulia.jl) adds julia support to the [jupyter](http://jupyter.org/) (formerly IPython) notebook system.
- [VS Code](https://code.visualstudio.com/) has an excellent julia extension
- other editors such as [Emacs](https://www.gnu.org/software/emacs/) and [Sublime](https://www.sublimetext.com/) have julia extensions that add various levels of support for the julia language.

## Installing Mimi

Once julia is installed, start julia and you should see a julia command prompt. Begin an interactive Julia session and enter the Package REPL, which is entered by typing `]` and exited with a single backspace:

```julia
julia> ]
```

Next you should run a command that updates your system with the latest information about available packages. It is particularly crucial that you run this command at this point if this is the first time you are using Julia on your system. To run this command, execute the following in the package REPL:

```julia
pkg> update
```

Now to install the Mimi package, issue the following command from the Pkg REPL mode:

```julia
pkg> add Mimi
```

You only have to run this command once on your machine.

As we work to enhance and improve Mimi we will release new versions of the package. To make sure you always have the latest version of Mimi installed, we recommend that on occasion you run the `update` command at the julia Pkg REPL. This will update *all* installed packages to their latest version (not just the Mimi package). To *only* update the Mimi package you may run the following, although we recommend you do a comprehensive update each time as indicated above.

```julia
pkg> update Mimi
```

## Using Mimi

When you start a new julia command prompt, Mimi is not yet loaded into that julia session. To load Mimi, issue the following command:
```jldoctest 
julia> using Mimi
```
You will have to run this command every time you want to use Mimi in julia. You would typically also add `using Mimi` to the top of any julia code file that employs the Mimi API.

## Mimi Registry

To access the models in the [MimiRegistry](https://github.com/mimiframework/Mimi.jl), you first need to connect your julia installation with the central Mimi registry of Mimi models. This central registry is like a catalogue of models that use Mimi that is maintained by the Mimi project. For more information about the Mimi Registry see [Explanations: Models as Packages](@ref), and note that for simplicity we aim to start phasing out use of a Mimi Registry for the General Registry as explained there. To add this registry, run the following command at the julia package REPL:

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You only need to run this command once on a computer. 

From there you will be add any of the registered packages, such as MimiDICE2010.jl by running the following command at the julia package REPL:

```julia
pkg> add MimiDICE2010
```

----
After taking the steps above you have prepared your system and are ready to run the next tutorials!
