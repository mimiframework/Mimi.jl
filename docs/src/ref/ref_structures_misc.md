# Reference Guide: Structures - Misc

This document, **along with "Structures: Definitions and Structures: Instances**, describes some of the core data structures used to implement in Mimi 1.0.

## Composites

Prior versions of Mimi supported only "flat" models, i.e., with one level of components. The current version supports mulitple layers of components, with some components being "final" or leaf components, and others being "composite" components which themselves contain other leaf or composite components. This approach allows for a cleaner organization of complex models, and allows the construction of building blocks that can be re-used in multiple models.

To the degree possible, composite components are designed to operate the same as leaf components, though there are necessarily differences:

1. Leaf components are defined using the macro `@defcomp`, while composites are defined using `@defcomposite`. Each macro supports syntax and semantics specific to the type of component. See below for more details on these macros.

1. Leaf composites support user-defined `run_timestep()` functions, whereas composites have a built-in `run_timestep()` function that iterates over its subcomponents and calls their `run_timestep()` function. The `init()` function is handled analogously.

## Classes.jl

Most of the core data structures are defined using the `Classes.jl` package, which was developed for Mimi, but separated out as a generally useful julia package. The main features of `Classes` are:

1. Classes can subclass other classes, thereby inheriting the same list of fields as a starting point, which can then be extended with further fields.

1. A type hierarchy is defined automatically that allows classes and subclasses to be referenced with a single type. In short, if you define a class `Foo`, an abstract type called `AbstractFoo` is defined, along with the concrete class `Foo`. If you subclass `Foo` (say with the class `Bar`), then `AbstractBar` will be a subtype of `AbstractFoo`, allowing methods to be defined that operate on both the superclass and subclass. See the Classes.jl documentation for further details.

For example, in Mimi, `ModelDef` is a subclass of `CompositeComponentDef`, which in turn is a subclass of `ComponentDef`. Thus, methods can be written with arguments typed `x::ComponentDef` to operate on leaf components only, or `x::AbstractCompositeComponentDef` to operate on composites and `ModelDef`, or as `x::AbstractComponentDef` to operate on all three concrete types.

## Core types

Several core types are defined in `types/core.jl`, including the two primary abstract types, `MimiStruct` and `MimiClass`. 

All structs and classes in Mimi are derived from these abstract types, which allows us to identify Mimi-defined items when writing `show()` methods. Important structs and classes include:

1. `ComponentId`

    To identify components, `@defcomp` creates a variable with the name of
    the component whose value is an instance of this type. The definition is:

    ```julia
    struct ComponentId <: MimiStruct
        module_obj::Union{Nothing, Module}
        comp_name::Symbol
    end
    ```

2. `ComponentPath`

    A `ComponentPath` identifies the path from one or more composites to any component, using an `NTuple` of symbols. Since component names are unique at the composite level, the sequence of names through a component hierarchy uniquely identifies a component in that hierarchy.

    ```julia
    struct ComponentPath <: MimiStruct
        names::NTuple{N, Symbol} where N
    end
    ```