[![Build Status](https://travis-ci.org/mimiframework/Mimi.jl.svg?branch=master)](https://travis-ci.org/mimiframework/Mimi.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/f915ntkc0etgvim9/branch/master?svg=true)](https://ci.appveyor.com/project/mimiframework/mimi-jl/branch/master)
[![Mimi](http://pkg.julialang.org/badges/Mimi_0.5.svg)](http://pkg.julialang.org/?pkg=Mimi)
[![Coverage Status](https://coveralls.io/repos/github/mimiframework/Mimi.jl/badge.svg?branch=master)](https://coveralls.io/github/mimiframework/Mimi.jl?branch=master)
[![codecov](https://codecov.io/gh/mimiframework/Mimi.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mimiframework/Mimi.jl)

[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://www.mimiframework.org/Mimi.jl/stable)
[![Latest documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://www.mimiframework.org/Mimi.jl/dev/)

# Mimi - Integrated Assessment Modeling Framework

A [Julia](http://julialang.org) package for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling). For more information, see the **[Documentation](https://www.mimiframework.org/Mimi.jl/stable/)**.

Please get in touch with [David Anthoff](http://www.david-anthoff.com) if you are interested in using this framework or want to be involved in any way with this effort.

## Overview

Mimi is a package that provides a component model for integrated assessment models.

Also see the [OptiMimi](http://github.com/jrising/OptiMimi.jl) package for optimizing parameters within Mimi models.

Porting to [Mimi 0.5.0](https://github.com/mimiframework/Mimi.jl/releases/tag/v0.5.1):  If you are adapting models to the [Mimi 0.5.0](https://github.com/mimiframework/Mimi.jl/releases/tag/v0.5.1) breaking release or later, please use the [Integration Guide](https://www.mimiframework.org/Mimi.jl/stable/integrationguide/) as guide to help port your models as easily as possible.

[Julia 1.0](https://julialang.org/blog/2018/08/one-point-zero): Mimi has now been ported to Julia 1.0.

## Installation

Mimi is an installable package. To install Mimi, use the following:

````
Pkg.add("Mimi")
````

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

* [MimiFUND.jl](https://github.com/fund-model/MimiFUND.jl) (currently in beta)
* [MimiDICE2010.jl](https://github.com/anthofflab/MimiDICE2010.jl) (currently in closed beta)
* [MimiDICE2013.jl](https://github.com/anthofflab/MimiDICE2013.jl) (currently in closed beta)
* [MimiRICE2010.jl](https://github.com/anthofflab/MimiRICE2010.jl)
* [Mimi-SNEASY.jl](https://github.com/anthofflab/mimi-sneasy.jl) (currently in closed beta)
* [Mimi-FAIR.jl](https://github.com/anthofflab/mimi-fair.jl) (currently in closed beta)
* [MimiPAGE2009.jl](https://github.com/anthofflab/MimiPAGE2009.jl) (currently in closed beta)
* [Mimi-MAGICC.jl](https://github.com/anthofflab/mimi-magicc.jl) (CH4 parts currently in closed beta)
* [Mimi-HECTOR.jl](https://github.com/anthofflab/mimi-hector.jl) (CH4 parts currently in closed beta)
* [Mimi-CIAM.jl](https://github.com/anthofflab/mimi-ciam.jl) (currently in closed beta)
* [Mimi-BRICK.jl](https://github.com/anthofflab/mimi-brick.jl) (currently in closed beta)

## Contributing

Contributions to Mimi are most welcome! You can interact with the Mimi development team via issues and pull requests here on github, and in the [Mimi Framework forum](https://forum.mimiframework.org).

## Acknowledgements

This work is partially supported by the National Science Foundation through the Network for Sustainable Climate Risk Management ([SCRiM](http://scrimhub.org/)) under NSF cooperative agreement GEO-1240507.
