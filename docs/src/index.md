# Welcome to Mimi

## Overview

Mimi is a package that provides a component model for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling).

## Installation

Mimi is an installable package which requires the programming language [julia](http://julialang.org/) to run. To install Mimi, first enter Pkg REPL mode by typing `]`, and then use the following script. You may then exit Pkg REPL mode with a single backpace.

```julia
pkg> add Mimi
```
For more complete setup instructions, follow the [Installation Guide](@ref).


## Mimi Registry

Several models currently use the Mimi framework, as listed in the section below.  For convenience, several models are registered in the [MimiRegistry](https://github.com/mimiframework/Mimi.jl), and operate as julia packages. To use this feature, you first need to connect your julia installation with the central Mimi registry of Mimi models. This central registry is like a catalogue of models that use Mimi that is maintained by the Mimi project. To add this registry, run the following command at the julia package REPL: 

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You only need to run this command once on a computer. 

From there you may add any of the registered packages, such as MimiRICE2010.jl by running the following command at the julia package REPL:

```julia
pkg> add MimiRICE2010
```

## Models using Mimi

* [MimiFUND.jl](https://github.com/fund-model/MimiFUND.jl) (currently in beta)
* [MimiDICE2010.jl](https://github.com/anthofflab/MimiDICE2010.jl)
* [MimiDICE2013.jl](https://github.com/anthofflab/MimiDICE2013.jl)
* [MimiRICE2010.jl](https://github.com/anthofflab/MimiRICE2010.jl)
* [Mimi-SNEASY.jl](https://github.com/anthofflab/mimi-sneasy.jl) (currently in closed beta)
* [Mimi-FAIR.jl](https://github.com/anthofflab/mimi-fair.jl) (currently in closed beta)
* [MimiPAGE2009.jl](https://github.com/anthofflab/MimiPAGE2009.jl) (currently in closed beta)
* [Mimi-MAGICC.jl](https://github.com/anthofflab/mimi-magicc.jl) (CH4 parts currently in closed beta)
* [Mimi-HECTOR.jl](https://github.com/anthofflab/mimi-hector.jl) (CH4 parts currently in closed beta)
* [Mimi-CIAM.jl](https://github.com/anthofflab/mimi-ciam.jl) (currently in closed beta)
* [Mimi-BRICK.jl](https://github.com/anthofflab/mimi-brick.jl) (currently in closed beta)
* [AWASH](http://awashmodel.org/)
* [PAGE-ICE](https://github.com/openmodels/PAGE-ICE)