# Composite Components

## Overview

This document describes the core data structures used to implement in Mimi 1.0.

Prior versions of Mimi supported only "flat" models, i.e., with one level of components. The current version supports mulitple layers of components, with some components being "final" or leaf components, and others being "composite" components which themselves contain other leaf or composite components. This approach allows for a cleaner organization of complex models, and allows the construction of building blocks that can be re-used in multiple models.

To the degree possible, composite components are designed to operate the same as leaf components, though there are necessarily differences:

1. Leaf components are defined using the macro `@defcomp`, while composites are defined using `@defcomposite`. Each macro supports syntax and semantics specific to the type of component. See below for more details on these macros.

1. Leaf composites support user-defined `run_timestep()` functions, whereas composites have a built-in `run_timestep()` function that iterates over its subcomponents and calls their `run_timestep()` function. The `init()` function is handled analogously.

### Classes.jl

Most of the core data structures are defined using the `Classes.jl` package, which was developed for Mimi, but separated out as a generally useful julia package. The main features of `Classes` are:

1. Classes can subclass other classes, thereby inheriting the same list of fields as a starting point, which can then be extended with further fields.

1. A type hierarchy is defined automatically that allows classes and subclasses to be referenced with a single type. In short, if you define a class `Foo`, an abstract type called `AbstractFoo` is defined, along with the concrete class `Foo`. If you subclass `Foo` (say with the class `Bar`), then `AbstractBar` will be a subtype of `AbstractFoo`, allowing methods to be defined that operate on both the superclass and subclass. See the Classes.jl documentation for further details.

For example, in Mimi, `ModelDef` is a subclass of `CompositeComponentDef`, which in turn is a subclass of `ComponentDef`. Thus, methods can be written with arguments typed `x::ComponentDef` to operate on leaf components only, or `x::AbstractCompositeComponentDef` to operate on composites and `ModelDef`, or as `x::AbstractComponentDef` to operate on all three concrete types.

## Core types

These are defined in `types/core.jl`.

1. `MimiStruct` and `MimiClass`

All structs and classes in Mimi are derived from these abstract types, which allows us to identify Mimi-defined items when writing `show()` methods.

1. `ComponentId`

    To identify components, `@defcomp` creates a variable with the name of
    the component whose value is an instance of this type. The definition is:

    ```julia
    struct ComponentId <: MimiStruct
        module_obj::Union{Nothing, Module}
        comp_name::Symbol
    end
    ```

1. `ComponentPath`

    A `ComponentPath` identifies the path from one or more composites to any component, using an `NTuple` of symbols. Since component names are unique at the composite level, the sequence of names through a component hierarchy uniquely identifies a component in that hierarchy.

    ```julia
    struct ComponentPath <: MimiStruct
        names::NTuple{N, Symbol} where N
    end
    ```

## Model Definition

Models are composed of two separate structures, which we refer to as the "definition" side and the "instance" or "instantiated" side. The definition side is operated on by the user via the `@defcomp` and `@defcomposite` macros, and the public API.

The instantiated model can be thought of as a "compiled" version of the model definition, with its data structures oriented toward run-time efficiency. It is constructed by Mimi in the `build()` function, which is called by the `run()` function.

The public API sets a flag whenever the user modifies the model definition, and the instance is rebuilt before it is run if the model definition has changed. Otherwise, the model instance is re-run.

The model definition is constructed from the following elements.

### Leaf components

1. `DatumDef`

    This is a superclass holding elements common to `VariableDef` and `ParameterDef`, including the `ComponentPath` to the component in which the datum is defined, the data type, and dimension definitions. `DatumDef` subclasses are stored only in leaf components.

1. `VariableDef <: DatumDef`

    This class adds no new fields. It exists to differentiate variables from parameters.

1. `ParameterDef <: DatumDef`

    This class adds only a "default value" field to the `DatumDef`. Note that functions defined to operate on the `AbstractDatumDef` type work for both variable and parameter definitions.

1. `ComponentDef`

Instances of `ComponentDef` are defined using `@defcomp`. Their internal `namespace`
dictionary can hold both `VariableDef` and `ParameterDef` instances.

### Composite components

Composite components provide a single component-like interface to an arbitrarily complex set
of components (both leaf and composite components).

1. `DatumReference`

    This abstract class serves as a superclass for `ParameterDefReference`, and
    `VariableDefReference`.

1. `ParameterDefReference`, and `VariableDefReference`

    These are used in composite components to store references to `ParameterDef` and `VariableDef` instances defined in leaf components. (They are conceptually like symbolic links in a
    file system.) Whereas a `VariableDef` or `ParameterDef` can appear in a leaf
    component, references to these may appear in any number of composite components.

    "Importing" a parameter or variable from a sub-component defines a reference to that
    datum in a leaf component. Note that if a composite imports a datum from another
    composite, a reference to the leaf datum is stored in each case. That is, we don't
    store references to references.

1. `CompositeComponentDef <: ComponentDef`

    Instances of `CompositeComponentDef` are defined using `@defcomposite`. Their internal `namespace` dictionary can hold instances of `ComponentDef`, `CompositeComponentDef`, `VariableDefReference` and `ParameterDefReference`.
    Composite components also record internal parameter connections.

1. `ModelDef <: CompositeComponentDef`

    A `ModelDef` is a top-level composite that also stores external parameters and a list
    of external parameter connections.

### Parameter Connections

Parameters hold values defined exogneously to the model ("external" parameters) or to the
component ("internal" parameters).

1. `InternalParameterConnection`

Internal parameters are defined by connecting a parameter in one component to a variable
in another component. This struct holds the names and `ComponentPath`s of the parameter
and variable, and other information such as the "backup" data source. At build time,
internal parameter connections result in direct references from the parameter to the
storage allocated for the variable.

1. `ExternalParameterConnection`

Values that are exogenous to the model are defined in external parameters whose values are
assigned using the public API function `set_param!()`, or by setting default values in
`@defcomp` or `@defcomposite`, in which case, the default values are assigned via an
internal call to `set_param!()`.

External connections are stored in the `ModelDef`, along with the actual `ModelParameter`s,
which may be scalar values or arrays, as described below.

1. `ModelParameter`

This is an abstract type that is the supertype of both `ScalarModelParameter{T}` and
`ArrayModelParameter{T}`. These two parameterized types are used to store values set
for external model parameters.

## Instantiated Models



1. `ComponentInstanceData`

This is the supertype for variables and parameters in component instances.

```julia
@class ComponentInstanceData{NT <: NamedTuple} <: MimiClass begin
    nt::NT
    comp_paths::Vector{ComponentPath}   # records the origin of each datum
end
```

1. `ComponentInstanceParameters`

1. `ComponentInstanceVariables`

1. `ComponentInstance`

1. `LeafComponentInstance <: ComponentInstance`

1. `CompositeComponentInstance <: ComponentInstance`

    The `run_timestep()` method of a `ComponentInstance` simply calls the `run_timestep()`
    method of each of its sub-components in dependency order.

1. `ModelInstance <: CompositeComponentInstance`


## User-facing Classes

1. `Model`

The `Model` class contains the `ModelDef`, and after the `build()` function is called, a `ModelInstance` that can be run. The API for `Model` delegates many calls to either its top-level `ModeDef` or `ModelInstance`, while providing additional functionality including running a Monte Carlo simulation.

1. `ComponentReference`

1. `VariableReference`
