# Model components

## @defcomp
The macro ```@defcomp``` defines model components. Some changes are in store:

1. Code simplification using the ```@capture``` macro from MacroTools.jl.

1. Remove the explicit definition of indices via ```regions = Index()``` since regions can be defined on first usage. In any case, indices must be defined (with actual values) at the model level, so ensuring this is the more relevant validity check.

1. In the current implementation, a custom type is generated for each component to facilitate dispatch to that component's ```run_timestep()``` method. This will be replaced with dispatch via ```Val{compname}```, avoiding the custom class, and allowing all components to be instances of an explicit ```Component``` type.

1. We will support the specification of default distributions for model parameters that can be overridden using ```@defsim```. (Syntax TBD.)

## Connecting components
1. Connections among components are currently performed in the order defined. 
  * It would be preferable to create a graph of dependencies and order the components automatically.
  * This will requiring some syntax to indicate whether a component requires the value from another component (or itself) from the current timestep ```t```, or the prior one, ```(t-1)```.

1. ...

