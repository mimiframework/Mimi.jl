# Composite Components

## Goals

In Mimi v0.4, we have two levels of model elements, (i) `Model` and (ii) `Component`. (For now, we ignore the distinction between model / component "definition" and "instance" types.) The primary goal of the `MetaComponent` construct is to extend this structure recursively to _N_ levels, by allowing a `MetaComponent` to contain other `MetaComponent`s as well as `LeafComponent`s, which cannot contain other components.

## Major elements
This suggests three types of elements:

1. `LeafComponent` -- equivalent to the Mimi v0.4 `Component` concept.

1. `MetaComponent` -- presents the same API as a `LeafComponent`, but the variables and parameters it exposes are the aggregated sets of variables and parameters exposed by its components, each of which can be a `MetaComponent` or `LeafComponent`. A `MetaComponent` creates no new storage for variables and parameters; it references the storage in its internal components. The `run_timestep` method of a `MetaComponent` simply calls the `run_timestep` method of each of its internal components in order. 

1. `Model` -- Like a `MetaComponent`, a model contains one or more instances of `MetaComponent` or `LeafComponent`. However, the API for a `Model` differs from that of a `MetaComponent`, thus they are separate classes. For example, you can run a Monte Carlo simulation on a `Model`, but not on a component (of either type).


## Implementation Notes

### Model

* A `Model` will be defined using the `@defmodel` macro.

* As with the currently defined (but not exported) `@defmodel`, component ordering will be determined automatically based on defined connections, with loops avoided by referencing timestep `[t-1]`. This simplifies the API for `addcomponent!`.

* We will add support for two optional functions defined inside `@defmodel`: `before_run` and `after_run`, which are called before and after (respectively) the model is run over all its timesteps.

* A `Model` will be implemented as a wrapper around a single top-level `MetaComponent` that handles the ordering and iteration over sub-components. (In an OOP language, `Model` would subclass `MetaComponent`.)


### MetaComponent

* Defined using `@defcomp` as with `LeafComponent`. It's "meta" nature is defined by including a new term:
    
    `subcomps = [sc1, sc2, sc3, ...]`, where the referenced sub-components (`sc1`, etc.) refer to previously defined `ComponentId`s.

* A `MetaComponent`'s `run_timestep` function is optional. The default function simply calls `run_timestep(subcomps::Vector)` to iterate over sub-components and calls `run_timestep` on each. If a `MetaComponent` defines its own `run_timestep` function, it should either call `run_timestep` on the vector of sub-components or perform a variant of this function itself.

## Questions

* Currently, `run()` calls `_run_components(mi, clock, firsts, lasts, comp_clocks)` with flat lists of firsts, lasts, and comp_clocks. How to handle this with recursive component structure?

  * Aggregate from the bottom up building `_firsts` and `_lasts` in each `MetaComponent` holding the values for its sub-component.

  * Also store the `MetaComponent`'s own summary `first` and `last` which are just `min(firsts)` and `max(lasts)`, respectively.

* What about `clocks`? The main question is _Which function advances the clock?_

  * Currently, the `ModelInstance` advances the global clock, and each `ComponentInstance` advances its own clock.
  * Simplest to treat the same as `firsts` and `lasts`: build a list of clocks for each `MetaComponentInstance` that is passed down when iterating over sub-components. Each component advances it's own clock after processing its children. 


### Other stuff

* This is a good opportunity to reconsider the treatment of external parameters. The main question is about naming these and whether they need to be globally unique or merely unique within a (meta) component.

* It turns out that generic functions and dynamic dispatch are not optimal for all design cases. Specifically:
  * The case of iterating over a vector of heterogenous objects and calling a function on each is handled poorly with dynamic dispatch. In Mimi, we generate unique functions for these and store them in a pointer, OOP style, so we can call them directly without the cost of dynamic dispatch. This, too, could be handled in a more automated fashion via an OOP macro.

* The lack of inheritance requires code duplication in the cases where multiple types share the same structure or a portion thereof. An OOP macro could handle this by generating the duplicate structure in two types that share the same abstract type, allowing a single point of modification for the shared elements.
  * This could be handled with composition, i.e., defined shared type and have an instance of it in each of the types that share this structure. The extra layer should disappear after compilation.
