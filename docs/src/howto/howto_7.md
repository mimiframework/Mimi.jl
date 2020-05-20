# How-to Guide 7: Port to Mimi v1.0.0

The release of Mimi v1.0.0 is a breaking release, necessitating the adaptation of existing models' syntax and structure in order for those models to run on this new version.  This guide provides an overview of the steps required to get most models using the v0.9.4 API working with v1.0.0.  It is **not** a comprehensive review of all changes and new functionalities, but a guide to the minimum steps required to port old models between versions.  For complete information on the new version and its functionalities, see the full documentation.

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

- Delete getindex (with square bracket shortcut) for getting values from a simulatio instance; use getdataframe instead
- rename some functions without camelCase

## Composite components 

This should also have it's own comprehensive guide, but should get a brief description here.
