# Changes

## 1. Code reorganization

### Types

All Mimi types are now defined in `Mimi/src/core/types.jl`.

We now have these "structural definition" types:

  * `ModelDef`
  * `ComponentDef`
  * `DatumDef` (used for both variable and parameter definitions)

and these "instantiated model" types:

  * `ModelInstance`
  * `ComponentInstance`
  * `ComponentInstanceVariables`
  * `ComponentInstanceParameters`


#### `Model` object
The "user-facing" `Model` no longer directly holds other model information: it now holds a `ModelDef` and, once the model is built, a `ModelInstance` and delegates all function calls to one or the other of these, as appropriate.

With this change, all previous "direct" access of data in `Model` have been replaced with a functional API, which facilitates redirection. That is, all occurrences of `m.` (where `m::Model`) have been replaced with function calls on `m`, which are then delegated.

To simplify coding the delegated calls, a new macro, `@modelegate` allows you to write, e.g., 

```
@modelegate external_parameter_connections(m::Model) => mi
```

which translates to:

```
external_parameter_connections(m::Model) = external_parameter_connections(m.mi)
```

The right-hand side can also be `=> md` to indicate delegation to the `ModelDef` rather than to the `ModelInstance`.


#### Connections

The types `InternalParameterConnection` and `ExternalParameterConnection` are now both subtypes of the abstract type `Connection`.

I'd like to consider merging the two connection types since the only functional differences are that `ExternalParameterConnections` have fewer fields and are stored in a separate list in the model.


#### ComponentInstanceData

`ComponentInstanceVariables` and `ComponentInstanceParameters` are parameterized types that are subtypes of `ComponentInstanceData`. The names and types of the variables or parameters are encoded into the type information; the struct proper contains only the parameter or variable values.


## 2. Changes to `@defcomp`

### Macro simplification

The `@defcomp` macro has been substantially simplified by relying on MacroTools.jl and by avoiding the construction of expressions using the "lower" syntactic form (i.e., the LISP-like form with `expr.head` and `expr.args`). The macro now operates by producing a fairly simple sequence of function calls.

### Dot-overloading

The `run_timestep` function has been moved inside the `@defcomp` macro. It is now named simply `run` (at least in the macro; a function called `run_timestep` is still generated) and takes four arguments: parameters, variables, dimensions, and time.

```
    function run(p, v, d, t::Int)
       ...
    end
```

With the `run` function inside the `@defcomp` macro, we are able to modify the code to translate references like `p.gdp` and assignments like `v.foo = 3` to use new `@generated` functions `getproperty` and `setproperty`, which compile down to direct array access operations on the `values` field of parameter and variable instances.

### Component naming

In the previous version of Mimi, components were named by a pair of symbols indicating the module the component was defined in, and the name of the component. Each component was also a newly generated custom type.

In the new version, component definitions are represented by the same (i.e., not generated) type, `ComponentDef`. The `@defcomp` macro creates a global variable with the name provided to `@defcomp` which holds a new type of object, `ComponentId`, which holds the symbol names of the module and component. Now, instead of referring to a component as, say, `(:Mimi, :grosseconomy)`, you refer to it by its associated global constant, e.g., `Mimi.grosseconomy`. Note that models can be defined in their own module to avoid namespace collisions.

## 3. New macro `@defmodel`

The `@defmodel` macro provides simplified syntax for model creation, eliminating many redundant parameters. For example, you can write:

```
@defmodel my_model begin

    index[time] = 2015:5:2110

    component(grosseconomy)
    component(emissions)

    # Set parameters for the grosseconomy component
    grosseconomy.l = [(1. + 0.015)^t *6404 for t in 1:20]
    grosseconomy.tfp = [(1 + 0.065)^t * 3.57 for t in 1:20]
    grosseconomy.s = ones(20).* 0.22
    grosseconomy.depk = 0.1
    grosseconomy.k0 = 130.0
    grosseconomy.share = 0.3

    # Set parameters for the emissions component
    emissions.sigma = [(1. - 0.05)^t *0.58 for t in 1:20]

    # Connect pararameters (source_variable => destination_parameter)
    grosseconomy.YGROSS => emissions.YGROSS
end
```

which produces these function calls:

```
quote
    my_model = Model()
    set_dimension!(my_model, :time, 2015:5:2110)
    addcomponent(my_model, Main.grosseconomy, :grosseconomy)
    addcomponent(my_model, Main.emissions, :emissions)
    set_parameter!(my_model, :grosseconomy, :l, [(1.0 + 0.015) ^ t * 6404 for t = 1:20])
    set_parameter!(my_model, :grosseconomy, :tfp, [(1 + 0.065) ^ t * 3.57 for t = 1:20])
    set_parameter!(my_model, :grosseconomy, :s, ones(20) * 0.22)
    set_parameter!(my_model, :grosseconomy, :depk, 0.1)
    set_parameter!(my_model, :grosseconomy, :k0, 130.0)
    set_parameter!(my_model, :grosseconomy, :share, 0.3)
    set_parameter!(my_model, :emissions, :sigma, [(1.0 - 0.05) ^ t * 0.58 for t = 1:20])
    connect_parameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)
    add_connector_comps(my_model)
end
```

## 4. Pre-compilation and built-in components

To get `__precompile__()` to work required moving the creation of "helper" components to an `__init__()` method in Mimi.jl, which is run automatically after Mimi loads. It defines the two "built-in" components, from `adder.jl` and `connector.jl` in the `components` subdirectory.


