# Reference Guide: Composite Components

Prior versions of Mimi supported only "flat" models, i.e., with one level of components. The current version supports mulitple layers of components, with some components being "final" or leaf components, and others being "composite" components which themselves contain other leaf or composite components. This approach allows for a cleaner organization of complex models, and allows the construction of building blocks that can be re-used in multiple models.

To the degree possible, composite components are designed to operate the same as leaf components, though there are necessarily differences:

1. Leaf components are defined using the macro [`@defcomp`](@ref), while composites are defined using [`@defcomposite`](@ref). Each macro supports syntax and semantics specific to the type of component.

2. Leaf components support user-defined `run_timestep()` functions, whereas composites have a built-in `run_timestep()` function that iterates over its subcomponents and calls their `run_timestep()` function. The `init()` function is handled analogously.

... [TODO]
