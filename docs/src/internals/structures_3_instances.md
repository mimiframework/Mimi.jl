# Instances

## Models and Components

```
# ComponentInstance
comp_name::Symbol
comp_id::ComponentID
comp_path::ComponentPath (from top (model) down)
first::Int
last::Int

# LeafComponentInstance <: ComponentInstance
variables::ComponentInstanceVariables
parameters::ComponentInstanceParameters
init::Union{Nothing, Function}
run_timestep::Union{Nothing, Function}

# CompositeComponentInstance <: ComponentInstance
comps_dict::OrderedDict{Symbol, ComponentInstance}
parameters::NamedTuple
variables::NamedTuple

# ModelInstance <: CompositeComponentInstance
md::ModelDef
```

## Datum

```
# ComponentInstanceParameters (only exist in leaf component instances)
nt::NamedTuple{Tuple{Symbol}, Tuple{Type}}    # Type is either ScalarModelParameter (for scalar parameters) or TimestepArray (for array parameters)
comp_paths::Vector{ComponentPath}

# ComponentInstanceVariables (only exist in leaf component instances)
nt::NamedTuple{Tuple{Symbol}, Tuple{Type}}  # Type is either ScalarModelParameter (for scalar variables) or TimestepArray (for array variables)
comp_paths::Vector{ComponentPath}
```
Note: in the `ComponentInstanceParameters`, the values stored in the named tuple point to the actual variable arrays in the other components for things that are internally connected, or to the actual value stored in the mi.md.external_params dictionary if it's an external parameter. (So I'm not sure what the component paths are there for, because the component path seems to always reference the current component, even if the parameter data tehcnically originates from a different component.)

## User-facing Classes

1. `Model`

The `Model` class contains the `ModelDef`, and after the `build()` function is called, a `ModelInstance` that can be run. The API for `Model` delegates many calls to either its top-level `ModeDef` or `ModelInstance`, while providing additional functionality including running a Monte Carlo simulation.

1. `ComponentReference`

1. `VariableReference`
