# Installation Guide

This guide will briefly explain how to install julia and Mimi.

## Installing julia

Mimi requires the programming language [julia](http://julialang.org/) to run. You can download the current release from the julia [download page](http://julialang.org/downloads/). You should download and install the command line version from that page.

## Installing Mimi

Once julia is installed, start julia and you should see a julia command prompt. To install the Mimi package, issue the following command from the Pkg REPL mode, which is entered by typing `]` and exited with a single backspace:

```julia
pkg> add Mimi
```
You only have to run this command once on your machine.

As Mimi gets improved we will release new versions of the package. To make sure you always have the latest version of Mimi installed, you can run the following command at the julia Pkg REPL:

```julia
pkg> update()
```
This will update *all* installed packages to their latest version (not just the Mimi package).

## Using Mimi

When you start a new julia command prompt, Mimi is not yet loaded into that julia session. To load Mimi, issue the following command:
```julia
julia> using Mimi
```
You will have to run this command every time you want to use Mimi in julia. You would typically also add `using Mimi` to the top of any julia code file that for example defines Mimi components.

## Editor support

There are various editors around that have julia support:

- [IJulia](https://github.com/JuliaLang/IJulia.jl) adds julia support to the [jupyter](http://jupyter.org/) (formerly IPython) notebook system.
- [Juno](http://junolab.org/) adds julia specific features to the [Atom](https://atom.io/) editor. It currently is the closest to a fully featured julia IDE.
- [Sublime](https://www.sublimetext.com/), [VS Code](https://code.visualstudio.com/), [Emacs](https://www.gnu.org/software/emacs/) and many other editors all have julia extensions that add various levels of support for the julia language.

## Getting started

The best way to get started with Mimi is to work through the **Tutorials**. 

The [Mimi](https://github.com/mimiframework/Mimi.jl) github repository also has links to various models that are based on Mimi, and looking through their code can be instructive.

Finally, when in doubt, ask your question in the [Mimi Framework forum](https://forum.mimiframework.org) or post an [Issue](https://github.com/mimiframework/Mimi.jl/issues) to the Github repository if you have a specific request for the development team.   Don't be shy about either option, we would much prefer to be inundated with lots of questions and help people out than people give up on Mimi!
