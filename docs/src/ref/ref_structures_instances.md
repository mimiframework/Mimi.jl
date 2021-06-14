# Reference Guide: Structures - Instances

## Models and Components

```
# ComponentInstance
comp_name::Symbol
comp_id::ComponentID
comp_path::ComponentPath (from top (model) down)
first::Int
last::Int
```
```
# LeafComponentInstance <: ComponentInstance
variables::ComponentInstanceVariables
parameters::ComponentInstanceParameters
init::Union{Nothing, Function}
run_timestep::Union{Nothing, Function}
```
```
# CompositeComponentInstance <: ComponentInstance
comps_dict::OrderedDict{Symbol, ComponentInstance}
parameters::NamedTuple
variables::NamedTuple
```
```
# ModelInstance <: CompositeComponentInstance
md::ModelDef
```

## Datum

```
# ComponentInstanceParameters (only exist in leaf component instances)
nt::NamedTuple{Tuple{Symbol}, Tuple{Type}}    # Type is either ScalarModelParameter (for scalar parameters) or TimestepArray (for array parameters)
comp_paths::Vector{ComponentPath}
```
Note: In the `ComponentInstanceParameters`, the values stored in the named tuple point to the actual variable arrays in the other components for things that are internally connected, or to the actual value stored in the mi.md.model_params dictionary if it's a model parameter.
```
# ComponentInstanceVariables (only exist in leaf component instances)
nt::NamedTuple{Tuple{Symbol}, Tuple{Type}}  # Type is either ScalarModelParameter (for scalar variables) or TimestepArray (for array variables)
comp_paths::Vector{ComponentPath}
```