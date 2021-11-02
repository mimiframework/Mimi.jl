# Tutorials Introduction

The following tutorials target [Mimi](https://github.com/mimiframework/Mimi.jl) users of different experience levels, starting with first-time users.  Before engaging with these tutorials, we recommend that users read the introductory [Welcome to Mimi](@ref) page. It will also be helpful to be comfortable with the basics of the [Julia](https://julialang.org/) language, though expertise is not required.

If you find a bug in these tutorials, or have a clarifying question or suggestion, please reach out via Github Issues or our [Mimi Framework forum](https://forum.mimiframework.org).  We welcome your feedback.

## Available Tutorials

[Tutorial 1: Install Mimi](@ref) describes how to set up your system by installing julia, Mimi, and the Mimi registry.


[Tutorial 2: Run an Existing Model](@ref) steps through the tasks to download, run, and view the results of a registered model such as [FUND](http://www.fund-model.org).  It should be usable for all users, including first-time users, and is a good place to start when learning to use Mimi.


[Tutorial 3: Modify an Existing Model](@ref) builds on Tutorial 2, showing how to modify an existing model such as [DICE](https://github.com/anthofflab/mimi-dice-2010.jl).


[Tutorial 4: Create a Model](@ref) takes a step beyond using registered models, explaining how to create a model from scratch.


[Tutorial 5: Monte Carlo Simulations and Sensitivity Analysis Support](@ref) explores Mimi's Monte Carlo simulation and sensitivity analysis support, using both the simple multi-Region tutorial model and MimiDICE2010 examples.


[Tutorial 6: Create a Model Including Composite Components](@ref) expands on Tutorial 4 and explains how to create a model from scratch including the use of composite components.

[Tutorial 7: Couple Two Existing Models](@ref) demonstrates how to couple together two models, both configured as packages, specifically in this case replacing (most of) the [FUND model](https://github.com/fund-model/MimiFUND.jl)'s climate module with the [FAIR model](https://github.com/anthofflab/MimiFAIR.jl).


## Additional Tutorals

#### AERE Workshop Tutorials: 

The Mimi developement team recently participated in the 2019 Association of Environmental and Resource Economists (AERE) summer conference during the pre-conference workshop on Advances in Integrated Assessment Models. This included both a presentation and a hands-on session demonstrating various use cases for Mimi. The Github repository [here](https://github.com/davidanthoff/teaching-2019-aere-workshop) contains a) all slides from the workshop and b) all the code from the hands on sessions, which may be of interest to Mimi users. Importantly note that the linked code represents as a snapshot of Mimi at the time of the workshop, and **will not** be updated to reflect new changes.

#### Resources for the Future (RFF) Webinar

On February 10, 2021, Resources for the Future (RFF) held a [live webinar](https://www.rff.org/events/rff-live/the-social-cost-of-carbon-key-scientific-and-policy-considerations-for-the-biden-administration/) for over 1,000 participants described on rff.org as follows:

"Over the past four years, the [Social Cost of Carbon Initiative](https://www.rff.org/topics/scc/) at Resources for the Future (RFF) has been a key hub for SCC scholarship to implement the NAS recommendations. On February 10, 2021, RFF held a live webinar that highlighted the latest SCC-related research from RFF scholars and the [Climate Impact Lab](http://www.impactlab.org). The conversation also featured perspectives from decisionmakers using the SCC to inform policy and highlighted key considerations for the Biden administration’s near-term and final updates of the estimates."

This webinar highlighted Mimi as a "free, open-source computing platform allows users to access, run, and modify the social cost of carbon (SCC) models used by the federal Interagency Working Group to estimate the SCC", **and was paired with the [Social Cost of Carbon Computing Platform: Models from the Interagency Working Group](https://www.rff.org/publications/data-tools/social-cost-of-carbon-computing-platform-models-from-the-iwg/) post including an [embedded video](https://www.youtube.com/watch?v=C2rqpHk3Rek&feature=emb_logo) by Professor Anthoff.**

Links: 

[RFF Mimi Post (with link to Mimi Demo )](https://www.rff.org/publications/data-tools/social-cost-of-carbon-computing-platform-models-from-the-iwg/)

[Direct YouTube Link to Mimi Demo](https://www.youtube.com/watch?v=C2rqpHk3Rek&feature=emb_logo)