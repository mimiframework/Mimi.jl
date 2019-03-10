# Welcome to Mimi

## Overview

Mimi is a package that provides a component model for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling).

## Installation

Mimi is an installable package. To install Mimi, use the following:

```julia
Pkg.add("Mimi")
```

For more complete setup instructions, follow the [Installation Guide](@ref).


## Mimi Registry

Several models currently use the Mimi framework, as listed in the section below.  For convenience, several models are registered in the [MimiRegistry](https://github.com/anthofflab/Mimi.jl), and operate as julia packages. To use this feature, you first need to connect your julia installation with the central Mimi registry of Mimi models. This central registry is like a catalogue of models that use Mimi that is maintained by the Mimi project. To add this registry, run the following command at the julia package REPL: 

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You only need to run this command once on a computer. 

From there you may add any of the registered packages, such as MimiRICE2010.jl by running the following command at the julia package REPL:

```julia
pkg> add MimiRICE2010
```

## Models using Mimi

* [FUND.jl](https://github.com/davidanthoff/fund.jl) (currently in beta)
* [Mimi-DICE-2010.jl](https://github.com/anthofflab/mimi-dice-2010.jl) (currently in closed beta)
* [Mimi-DICE-2013.jl](https://github.com/anthofflab/mimi-dice-2013.jl) (currently in closed beta)
* [Mimi-RICE.jl](https://github.com/anthofflab/mimi-rice-2010.jl)
* [Mimi-SNEASY.jl](https://github.com/anthofflab/mimi-sneasy.jl) (currently in closed beta)
* [Mimi-FAIR.jl](https://github.com/anthofflab/mimi-fair.jl/) (currently in closed beta)
* [Mimi-PAGE.jl](https://github.com/anthofflab/mimi-page.jl/) (currently in closed beta)
* [Mimi-MAGICC.jl](https://github.com/anthofflab/mimi-magicc.jl) (CH4 parts currently in closed beta)
* [Mimi-HECTOR.jl](https://github.com/anthofflab/mimi-hector.jl) (CH4 parts currently in closed beta)
* [Mimi-CIAM.jl](https://github.com/anthofflab/mimi-ciam.jl) (currently in closed beta)
* [Mimi-BRICK.jl](https://github.com/anthofflab/mimi-brick.jl) (currently in closed beta)
