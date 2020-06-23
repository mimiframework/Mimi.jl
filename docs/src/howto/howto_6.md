# How-to Guide 6: Port to Mimi v1.0.0

The release of Mimi v1.0.0 is a breaking release, necessitating the adaptation of existing models' syntax and structure in order for those models to run on this new version.  This guide provides an overview of the steps required to get most models using the v0.9.5 API working with v1.0.0.  It is **not** a comprehensive review of all changes and new functionalities, but a guide to the minimum steps required to port old models between versions.  For complete information on the new version and its functionalities, see the full documentation.

To port your model, we recommend you update to **Mimi v0.10.0**, which is identical to Mimi v1.0.0 **except** that it includes deprecation warnings for (most) breaking changes, instead of errors. This means that models written using Mimi v0.9.5 will, in most cases, run successfully under Mimi v0.10.0 although things that will cause errors in v1.0.0 will throw deprecation warnings. Thus a good workflow would be:

1) update to Mimi v0.10.0
2) read through this guide to get a sense for what has changed
3) run your code and incrementally update it, using the deprecation warnings as guides and the instructions in this guide as explanations, until no warnings are thrown
4) double check for any of the cases in this guide
5) update to Mimi v1.0.0 and run your model!

This guide is organized into five main sections, each descripting an independent set of changes that can be undertaken in any order desired. 

1) Syntax within @defcomp
2) The set_param! function
3) Different-length components
4) Simulation syntax
5) Composite components (this should probably have it's own guide, but should get a brief mention here)

## Syntax within @defcomp

- Parameter data type specification
- no more integer indexing (use TimetsepIndex(2) or TimestepValue(1990) instead, available comparison functions, d.time returns AbstractTimesteps)

## The set_param! function

- explain new function (now has five arguments)
- explain the shortcuts
- explain when it errors

## Different-length components
(either the functionality will be gone, or implemented differently)

## Changes to simulation syntax

- Delete getindex (with square bracket shortcut) for getting values from a simulation instance; use getdataframe instead
- rename some functions without camelCase

## Integer indexing 
- cannot index with integers
- removed `is_time` and `is_timestep`

## Composite components 

This should also have it's own comprehensive guide, but should get a brief description here.
