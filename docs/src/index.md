# Welcome to Mimi

## Overview

Mimi is a [Julia](http://julialang.org) package that provides a component model for [integrated assessment models](https://en.wikipedia.org/wiki/Integrated_assessment_modelling), as described in detail on the [Mimi Framework Homepage](https://www.mimiframework.org).

The documentation is organized into the following four sections, roughly adhering to the [Diátaxis documentation framework](https://diataxis.fr) guidelines. For insights into the goals of each of these documentation categories, please refer to the Diátaxis website.

1. Tutorials
2. How-to Guides
3. Technical Reference
4. Explanations

**IMPORTANT: If at any point julia-related issues with workflows, environments, and/or package versioning become frustrating, please do not hesitate to reach out via the [forum](https://forum.mimiframework.org).  This can be a hurdle to learn at first, but taking a moment to get it right early will save you **a lot** of time down the road.  We are more than happy to help you, and are getting together some standardized resources in the meantime.**

## Getting started

We aim to assist users of all different experience levels, starting with first-time users. If this is your first time using Mimi, we recommend you begin with the Tutorials. In addition, looking through the code at the links below to various existing models based on Mimi can be instructive. 

The **first step** for any user includes installation of julia and Mimi, as well as optionally adding the Mimi Registry. See [Tutorial 1: Install Mimi](@ref) for instructions on these tasks.

As we work to enhance and improve Mimi we will release new versions of the package. To make sure you always have the latest version of Mimi installed, we recommend that on occasion you run the `update` command at the julia Pkg REPL. This will update *all* installed packages to their latest version (not just the Mimi package). To *only* update the Mimi package you may run the following, although we recommend you do a comprehensive update each time as indicated above. See [Tutorial 1: Install Mimi](@ref) for more!

```julia
pkg> update Mimi
```

Finally, when in doubt, ask your question on the [Mimi Framework forum](https://forum.mimiframework.org) or post an [Issue](https://github.com/mimiframework/Mimi.jl/issues) to the Github repository, the latter being especially pertinent if you have a specific request for the development team.   Don't be shy about either option, we would much prefer to be inundated with lots of questions and help people out than people give up on Mimi!

## Models using Mimi

* [MimiBRICK.jl](https://github.com/raddleverse/MimiBRICK.jl)
* [MimiCIAM.jl](https://github.com/anthofflab/mimi-ciam.jl)
* [MimiDICE2010.jl](https://github.com/anthofflab/MimiDICE2010.jl)
* [MimiDICE2013.jl](https://github.com/anthofflab/MimiDICE2013.jl)
* [MimiDICE2016.jl](https://github.com/AlexandrePavlov/MimiDICE2016.jl) (version R not R2)
* [MimiDICE2016R2.jl](https://github.com/anthofflab/MimiDICE2016R2.jl)
* [MimiFAIR.jl](https://github.com/anthofflab/mimi-fair.jl/)
* [MimiFAIR13.jl](https://github.com/FrankErrickson/MimiFAIR13.jl)
* [MimiFAIRv1\_6\_2.jl](https://github.com/FrankErrickson/MimiFAIRv1_6_2.jl)
* [MimiFAIRv2.jl](https://github.com/FrankErrickson/MimiFAIRv2.jl)
* [MimiFUND.jl](https://github.com/fund-model/MimiFUND.jl)
* [MimiGIVE.jl](https://github.com/rffscghg/MimiGIVE.jl)
* [MimiHECTOR.jl](https://github.com/anthofflab/mimi-hector.jl)
* [MimiIWG.jl](https://github.com/rffscghg/MimiIWG.jl)
* [MimiMAGICC.jl](https://github.com/anthofflab/mimi-magicc.jl)
* [MimiMooreEtAlAgricultureImpacts.jl](https://github.com/rffscghg/MimiMooreEtAlAgricultureImpacts.jl)
* [Mimi\_NAS\_pH.jl](https://github.com/FrankErrickson/Mimi_NAS_pH.jl)
* [mimi_NICE](https://github.com/fdennig/mimi_NICE)
* [MimiPAGE2009.jl](https://github.com/anthofflab/MimiPAGE2009.jl/)
* [MimiPAGE2020.jl](https://github.com/openmodels/MimiPAGE2020.jl)
* [MimiRFFSPs.jl](https://github.com/rffscghg/MimiRFFSPs.jl)
* [MimiRICE2010.jl](https://github.com/anthofflab/MimiRICE2010.jl)
* [Mimi-SNEASY.jl](https://github.com/anthofflab/mimi-sneasy.jl)
* [MimiSSPs.jl](https://github.com/anthofflab/MimiSSPs.jl)
* [AWASH](http://awashmodel.org/)
* [PAGE-ICE](https://github.com/openmodels/PAGE-ICE)
* [RICE+AIR](https://github.com/Environment-Research/AIR)
