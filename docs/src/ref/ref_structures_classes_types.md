# Reference Guide: Core Types

## Type Hierarchy

Mimi uses plain Julia structs and abstract types to define its core data structures. An abstract type hierarchy enables dispatch across related types. For example, `ModelDef <: AbstractCompositeComponentDef <: AbstractComponentDef <: AbstractNamedObj`. Methods can be written with arguments typed `x::AbstractComponentDef` to operate on leaf components, composites, and model definitions alike.

## User-facing Types

1. `Model`: Contains a `ModelDef`, and after the `build()` function is called, a `ModelInstance` that can be run. The API for `Model` delegates many calls to either its top-level `ModelDef` or `ModelInstance`, while providing additional functionality including running a Monte Carlo simulation.

2. `ComponentReference`
 
[TODO]

3. `VariableReference`

[TODO]

## Core Types

Several core types are defined in `types/core.jl`. Some of the important structs include:

1. `ComponentId`

    To identify components, `@defcomp` creates a variable with the name of
    the component whose value is an instance of this type. The definition is:

    ```julia
    struct ComponentId
        module_obj::Union{Nothing, Module}
        comp_name::Symbol
    end
    ```

2. `ComponentPath`

    A `ComponentPath` identifies the path from one or more composites to any component, using an `NTuple` of symbols. Since component names are unique at the composite level, the sequence of names through a component hierarchy uniquely identifies a component in that hierarchy.

    ```julia
    struct ComponentPath
        names::NTuple{N, Symbol} where N
    end
    ```