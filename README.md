![](https://github.com/mimiframework/Mimi.jl/actions/workflows/jlpkgbutler-ci-master-workflow.yml/badge.svg)
![](https://github.com/mimiframework/Mimi.jl/actions/workflows/dependencytest-workflow.yml/badge.svg)
[![codecov](https://codecov.io/gh/mimiframework/Mimi.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mimiframework/Mimi.jl)
[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://www.mimiframework.org/Mimi.jl/stable)

# Mimi - Integrated Assessment Modeling Framework

Mimi is a [Julia](http://julialang.org) package that provides a component model for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling), as described in detail on the [Mimi Framework Homepage](https://www.mimiframework.org). The [Documentation](https://www.mimiframework.org/Mimi.jl/stable/) includes information on the installation and use of this package, step-by-step tutorials, how-to guides, and technical reference. The development team closely monitors the [Mimi Framework forum](https://forum.mimiframework.org) and we suggest this as a starting place for any questions users may have.

Also, note that if at any point julia-related issues with workflows, environments, and/or package versioning become frustrating, please do not hesitate to reach out via the [forum](https://forum.mimiframework.org).  This can be a hurdle to learn at first, but taking a moment to get it right early will save you **a lot** of time down the road.  We are more than happy to help you, and are getting together some standardized resources in the meantime.

## NEWS

11/27/2022

The newest model on our platform, [MimiGIVE](https://github.com/rffscghg/MimiGIVE.jl/tree/main/src) is a fully open source model featured in the recent Nature publication [Comprehensive evidence implies a higher social cost of CO2](https://www.nature.com/articles/s41586-022-05224-9) and recent [EPA work](https://www.epa.gov/environmental-economics/scghg).

11/1/2021

Check out the new [MimiSSPs.jl](https://github.com/anthofflab/MimiSSPs.jl) component, pulling in various SSP and RCP data sources into a component to streamline running Mimi models as forced by the SSPs and RCPs.

6/14/2021

We recently tagged and released a feature release revamping the API surrounding parameters, please see https://www.mimiframework.org/Mimi.jl/dev/howto/howto_5/ and https://www.mimiframework.org/Mimi.jl/dev/howto/howto_9/.

5/3/2021

We have written up a repository and accompanying notebook [here](https://github.com/anthofflab/MimiFUND-MimiFAIR-Flat.jl/blob/main/MimiFUND-MimiFAIR-Flat.ipynb) to demonstrate the steps to couple together two models, specifically in this case replacing (most of) the [FUND model](https://github.com/fund-model/MimiFUND.jl)'s climate module with the [FAIR model](https://github.com/anthofflab/MimiFAIR.jl).

7/15/2020

We officially tagged and released Mimi v1.0.0, which has some new features, documentation, and quite a bit of internals work as well.  Since this is a major version change, there are some breaking changes that may require you to update your code.  We have done the updates for the existing models in the Mimi registry (FUND, DICE, etc.), and will release new major versions of those today as well, so if you are using the latest version of Mimi and the latest version of the packages, all should run smoothly.

**Please view the how to guide here: https://www.mimiframework.org/Mimi.jl/stable/howto/howto_7/ for a run-down of how you should update your own code.**

In addition please do not hesitate to ask any questions on the forum, we are working hard to keep this transition smooth.

## Contributions and Questions

You can interact with the Mimi development team via issues and pull requests here on github, and in the [Mimi Framework forum](https://forum.mimiframework.org). Contributions to Mimi are also most welcome, and
please get in touch with [David Anthoff](http://www.david-anthoff.com) or [Lisa Rennels](https://www.lisarennels.com) if you want to be involved in any way with this effort.

## Acknowledgements

This work is partially supported by the National Science Foundation through the Network for Sustainable Climate Risk Management ([SCRiM](http://scrimhub.org/)) under NSF cooperative agreement GEO-1240507.
