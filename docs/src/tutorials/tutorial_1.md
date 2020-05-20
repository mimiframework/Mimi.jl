# Tutorial 1: Install Mimi

This tutorial will briefly how to install julia and Mimi.

## Installing julia

Mimi requires the programming language [julia](http://julialang.org/) to run. You can download the current release from the julia [download page](http://julialang.org/downloads/). You should download and install the command line version from that page.

## Editor support

There are various editors around that have julia support:

- [IJulia](https://github.com/JuliaLang/IJulia.jl) adds julia support to the [jupyter](http://jupyter.org/) (formerly IPython) notebook system.
- [Juno](http://junolab.org/) adds julia specific features to the [Atom](https://atom.io/) editor. It currently is the closest to a fully featured julia IDE.
- [Sublime](https://www.sublimetext.com/), [VS Code](https://code.visualstudio.com/), [Emacs](https://www.gnu.org/software/emacs/) and many other editors all have julia extensions that add various levels of support for the julia language.

## Installing Mimi

Once julia is installed, start julia and you should see a julia command prompt. To install the Mimi package, issue the following command from the Pkg REPL mode, which is entered by typing `]` and exited with a single backspace:

```julia
pkg> add Mimi
```
You only have to run this command once on your machine.

As Mimi gets improved we will release new versions of the package. To make sure you always have the latest version of Mimi installed, you can run the following command at the julia Pkg REPL:

```julia
pkg> update
```
This will update *all* installed packages to their latest version (not just the Mimi package).

## Using Mimi

When you start a new julia command prompt, Mimi is not yet loaded into that julia session. To load Mimi, issue the following command:
```jldoctest 
julia> using Mimi
```
You will have to run this command every time you want to use Mimi in julia. You would typically also add `using Mimi` to the top of any julia code file that for example defines Mimi components.

## Mimi Registry

To access the models in the [MimiRegistry](https://github.com/mimiframework/Mimi.jl), you first need to connect your julia installation with the central Mimi registry of Mimi models. This central registry is like a catalogue of models that use Mimi that is maintained by the Mimi project. To add this registry, run the following command at the julia package REPL:


```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You only need to run this command once on a computer. 

From there you will be add any of the registered packages, such as MimiDICE2010.jl by running the following command at the julia package REPL:

```julia
pkg> add MimiDICE2010
```
