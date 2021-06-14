![](https://github.com/mimiframework/Mimi.jl/workflows/Run%20CI%20on%20master/badge.svg)
![](https://github.com/mimiframework/Mimi.jl/workflows/Run%20model%20tests/badge.svg)
[![codecov](https://codecov.io/gh/mimiframework/Mimi.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mimiframework/Mimi.jl)
[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://www.mimiframework.org/Mimi.jl/stable)

# Mimi - Integrated Assessment Modeling Framework

Mimi is a [Julia](http://julialang.org) package that provides a component model for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling), as described in detail on the [Mimi Framework Homepage](https://www.mimiframework.org). The [Documentation](https://www.mimiframework.org/Mimi.jl/stable/) includes information on the installation and use of this package, step-by-step tutorials, how-to guides, and techincal reference. The development team closely monitors the [Mimi Framework forum](https://forum.mimiframework.org) and we suggest this as a starting place for any questions users may have.

## NEWS

6/14/2021

We recently tagged and released a feature relese revamping the API surrounding parameters, please see https://www.mimiframework.org/Mimi.jl/dev/howto/howto_5/ and https://www.mimiframework.org/Mimi.jl/dev/howto/howto_9/.

5/3/2021

We have written up a repository and accompanying notebook [here](https://github.com/anthofflab/MimiFUND-MimiFAIR-Flat.jl/blob/main/MimiFUND-MimiFAIR-Flat.ipynb) to demonstrate the steps to couple together two models, specifically in this case replacng (most of) the [FUND model](https://github.com/fund-model/MimiFUND.jl)'s climate module with the [FAIR model](https://github.com/anthofflab/MimiFAIR.jl).

7/15/2020

We officially tagged and released Mimi v1.0.0, which has some new features, documentation, and quite a bit of internals work as well.  Since this is a major version change, there are some breaking changes that may require you to update your code.  We have done the updates for the existing models in the Mimi registry (FUND, DICE, etc.), and will release new major versions of those today as well, so if you are using the latest version of Mimi and the latest version of the packages, all should run smoothly.

**Please view the how to guide here: https://www.mimiframework.org/Mimi.jl/stable/howto/howto_7/ for a run-down of how you should update your own code.**

In addition please do not hesitate to ask any questions on the forum, we are working hard to keep this transition smooth.

## Contributions and Questions

You can interact with the Mimi development team via issues and pull requests here on github, and in the [Mimi Framework forum](https://forum.mimiframework.org). Contributions to Mimi are also most welcome, and
please get in touch with [David Anthoff](http://www.david-anthoff.com) if you want to be involved in any way with this effort.

## Acknowledgements

This work is partially supported by the National Science Foundation through the Network for Sustainable Climate Risk Management ([SCRiM](http://scrimhub.org/)) under NSF cooperative agreement GEO-1240507.
