[![Build Status](https://travis-ci.org/anthofflab/Mimi.jl.svg?branch=master)](https://travis-ci.org/anthofflab/Mimi.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/ibbj9nfjxdybe0yn/branch/master?svg=true)](https://ci.appveyor.com/project/davidanthoff/mimi-jl/branch/master)
[![Mimi](http://pkg.julialang.org/badges/Mimi_0.5.svg)](http://pkg.julialang.org/?pkg=Mimi)
[![Coverage Status](https://coveralls.io/repos/github/anthofflab/Mimi.jl/badge.svg?branch=master)](https://coveralls.io/github/anthofflab/Mimi.jl?branch=master)
[![codecov](https://codecov.io/gh/anthofflab/Mimi.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/anthofflab/Mimi.jl)

[![Join the chat at https://gitter.im/anthofflab/Mimi.jl](https://badges.gitter.im/anthofflab/Mimi.jl.svg)](https://gitter.im/anthofflab/Mimi.jl?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](http://anthofflab.berkeley.edu/Mimi.jl/stable)
[![Latest documentation](https://img.shields.io/badge/docs-latest-blue.svg)](http://anthofflab.berkeley.edu/Mimi.jl/dev/)

# Mimi - Integrated Assessment Modeling Framework

A [Julia](http://julialang.org) package for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling). For more information, see the **[Documentation](http://anthofflab.berkeley.edu/Mimi.jl/dev/)**.

Please get in touch with [David Anthoff](http://www.david-anthoff.com) if you are interested in using this framework or want to be involved in any way with this effort.

## Overview

Mimi is a package that provides a component model for integrated assessment models.

Also see the [OptiMimi](http://github.com/jrising/OptiMimi.jl) package for optimizing parameters within Mimi models.

Porting to [Mimi 0.5.0](https://github.com/anthofflab/Mimi.jl/releases/tag/v0.5.1):  If you are adapting models to the[Mimi 0.5.0](https://github.com/anthofflab/Mimi.jl/releases/tag/v0.5.1) breaking release or later, please use the [Integration Guide](http://anthofflab.berkeley.edu/Mimi.jl/dev/integrationguide.html) as guide to help port your models as easily as possible.

[Julia 1.0](https://julialang.org/blog/2018/08/one-point-zero): Mimi has not yet been ported to Julia 1.0, and thus is not compatible with Julia 1.0 (or [Julia v0.7](https://docs.julialang.org/en/v0.7.0/NEWS/) which provides deprecation warnings for Julia 1.0).  The next release of Mimi will provide this compatibility.

## Installation

Mimi is an installable package. To install Mimi, use the following:

````
Pkg.add("Mimi")
````

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

## Contributing

Contributions to Mimi are most welcome! You can interact with the Mimi development team via issues and pull requests here on github, and in the [Mimi.jl/dev](https://gitter.im/anthofflab/Mimi.jl/dev) gitter chat room.

## Acknowledgements

This work is partially supported by the National Science Foundation through the Network for Sustainable Climate Risk Management ([SCRiM](http://scrimhub.org/)) under NSF cooperative agreement GEO-1240507.
