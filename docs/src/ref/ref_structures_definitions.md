# Reference Guide: Structures - Definitions

## Model Definition

Models are composed of two separate structures, which we refer to as the "definition" side and the "instance" or "instantiated" side. The definition side is operated on by the user via the [`@defcomp`](@ref) and [`@defcomposite`](@ref) macros, and the public API ([`add_comp!`](@ref), [`update_param!`](@ref), [`connect_param!`](@ref), etc.).

The instantiated model can be thought of as a "compiled" version of the model definition, with its data structures oriented toward run-time efficiency. It is constructed by Mimi in the `build()` function, which is called by the `run()` function.

The public API sets a flag whenever the user modifies the model definition, and the instance is rebuilt before it is run if the model definition has changed. Otherwise, the model instance is re-run.

The model definition is constructed from the following elements.

## Leaf components

Leaf components are defined using the `@defcomp` macro which generates a component definition of the type `ComponentDef` which has the following fields:
```
# ComponentDef
parent::Any
name::Symbol
comp_id::Union{Nothing, ComponentId}   
comp_path::Union{Nothing, ComponentPath}
dim_dict::OrderedDict{Symbol, Union{Nothing, Dimension}}
namespace::OrderedDict{Symbol, Any}       
first::Union{Nothing, Int}
last::Union{Nothing, Int}
is_uniform::Bool
```
The namespace of a leaf component can hold `ParameterDef`s and `VariableDef`s, both which are subclasses of `DatumDef` (see below for more details on these types).

## Composite components

Composite components are defined using the [`@defcomposite`](@ref) macro which generates a composite component definition of the type `CompositeComponentDef` which has the following fields, in addition to the fields of a `ComponentDef`:
```
# CompositeComponentDef <: ComponentDef 
internal_param_conns::Vector{InternalParameterConnection}   
backups::Vector{Symbol}
```
The namespace of a composite component can hold `CompositeParameterDef`s and`CompositeVariableDef`s, as well as `AbstractComponentDef`s (which can be other leaf or composite component definitions).

## Datum definitions

Note: we use "datum" to refer collectively to parameters and variables. Parameters are values that are fed into a component, and variables are values calculated by a component's `run_timestep` function.

Datum are defined with the [`@defcomp`](@ref) and [`@defcomposite`](@ref) macros, and have the following fields:
```
# DatumDef
name::Symbol
comp_path::Union{Nothing, ComponentPath}
datatype::DataType
dim_names::Vector{Symbol}
description::String
unit::String
```
The only difference between a ParameterDef and a VariableDef is that parameters can have default values.
```
# ParameterDef <: DatumDef
default::Any

# VariableDef <: DatumDef
# (This class adds no new fields. It exists to differentiate variables from parameters.)
```

`CompositeParameterDef`s and `CompositeVariableDef`s are defined in the `@defcomposite` macro, and point to datum from their subcomponents. (Remember, composite components do not have `run_timestep` functions, so no values are actually calculated in a composite component.) Thus, `CompositeParameterDef`s and `CompositeVariableDef`s inherit all the fields from `ParameterDef`s and `VariableDef`s, and have an additional field to record which subcomponent(s)' datum they reference.
```
# CompositeParameterDef <: ParameterDef
refs::Vector{UnnamedReference}

# CompositeVariableDef <: VariableDef
ref::UnnamedReference
```
Note: a `CompositeParameterDef` can reference multiple subcomponents' parameters, but a `CompositeVariableDef` can only reference a variable from one subcomponent.

The reference(s) stored in `CompositeParameterDef`s and `CompositeVariableDef`s are of type `UnnamedReference`, which has the following fields:
```
# UnnamedReference
comp_name::Symbol   # name of the referenced subcomponent
datum_name::Symbol  # name of the parameter or variable in the subcomponent's namespace
```

## ModelDef

A `ModelDef` is a top-level composite that also stores model parameters and a list of model parameter connections. It contains the following additional fields:
```
# ModelDef <: CompositeComponentDef
external_param_conns::Vector{ExternalParameterConnection}
model_params::Dict{Symbol, ModelParameter}
number_type::DataType
dirty::Bool
```
Note: a ModelDef's namespace will only hold `AbstractComponentDef`s. 

## Parameter Connections

`InternalParameterConnection`
Internal parameters are defined by connecting a parameter in one component to a variable
in another component. This struct holds the names and `ComponentPath`s of the parameter
and variable, and other information such as the "backup" data source. At build time,
internal parameter connections result in direct references from the parameter to the
storage allocated for the variable.

`ExternalParameterConnection`
Values that are exogenous to the model are defined in model parameters whose values are
assigned using the public API function [`update_param!()`](@ref), or by setting default values in
[`@defcomp`](@ref) or [`@defcomposite`](@ref), in which case, the default values are assigned via an
internal call to [`update_param!()`](@ref).

External connections are stored in the `ModelDef`, along with the actual `ModelParameter`s,
which may be scalar values or arrays, as described below.

```
# AbstractConnection

# InternalParameterConnection <: AbstractConnection
src_comp_path::ComponentPath      
src_var_name::Symbol
dst_comp_path::ComponentPath
dst_par_name::Symbol
ignoreunits::Bool
backup::Union{Symbol, Nothing} # a Symbol identifying the model param providing backup data, or nothing
backup_offset::Union{Int, Nothing}

# ExternalParameterConnection  <: AbstractConnection
comp_path::ComponentPath
param_name::Symbol      # name of the parameter in the component
model_param_name::Symbol  # name of the parameter stored in the model's model_params
```

## Model parameters 

`ModelParameter`
This is an abstract type that is the supertype of both `ScalarModelParameter{T}` and
`ArrayModelParameter{T}`. These two parameterized types are used to store values set
for model parameters.
