# Changes

## 1. Code reorganization

### Types

All Mimi types are now defined in `Mimi/src/core/types.jl`.

We now have these "structural definition" types:

  * `ModelDef`
  * `ComponentDef`
  * `VariableDef`
  * `ParameterDef`

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

The `@defcomp` macro has been substantially simplified by relying on MacroTools.jl and by avoiding the construction of expressions using the "lower" syntactic form. The macro now operates by producing a fairly simple sequence of function calls.

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

In the new version, component definitions are represented by the same (i.e., not generated) type, `ComponentDef`. The `@defcomp` macro creates a global variable with the name provided to `@defcomp` which holds a new type of object, `ComponentId`, which holds the symbol names of the module and component. Now, instead of referring to a component as, say, `(:Mimi, :grosseconomy)`, you refer to it by its associated global constant, e.g., `Mimi.grosseconomy`.
 **This change requires that models be defined in their own package to avoid namespace collisions.**

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
    grosseconomy.k0 = 130.
    grosseconomy.share = 0.3

    # Set parameters for the emissions component
    emissions.sigma = [(1. - 0.05)^t *0.58 for t in 1:20]

    # Connect pararamters
    emissions.YGROSS => grosseconomy.YGROSS
end
```

which produces these function calls:

**THIS IS NO LONGER CORRECT -- UPDATE IT!**

```
quote
    my_model = Model()
    setindex(my_model, :time, 2015:5:2110)
    addcomponent(my_model, :Main, :grosseconomy)
    addcomponent(my_model, :Main, :emissions)
    setparameter(my_model, :grosseconomy, :l, [(1.0 + 0.015) ^ t * 6404 for t = 1:20])
    setparameter(my_model, :grosseconomy, :tfp, [(1 + 0.065) ^ t * 3.57 for t = 1:20])
    setparameter(my_model, :grosseconomy, :s, ones(20) .* 0.22)
    setparameter(my_model, :grosseconomy, :depk, 0.1)
    setparameter(my_model, :grosseconomy, :k0, 130.0)
    setparameter(my_model, :grosseconomy, :share, 0.3)
    setparameter(my_model, :emissions, :sigma, [(1.0 - 0.05) ^ t * 0.58 for t = 1:20])
    connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)
end
```

## 4. Code cleanup

#### Naming conventions

Regardless of programming language, a consistent naming scheme provides several benefits:

* Function names are more predictable.

* Names can be shortened, yet still meaningful, by using consistent abbreviations, e.g., `conn` for connection, `comp` for component, `var` for variable, `param` for parameter.

* Code is more legible when formal parameters always mean the same thing across functions.

* Less "invention" is required when naming variables and functions.

The julia convention of naming variables without word separation (e.g., `getdimensioninfo`) makes it harder to parse variable names compared to the underscore or CamelCase conventions used in many other languages `get_dimension_info` or `getDimensionInfo`.

To simplify naming, I propose the following rules:

 1. Avoid naming functions starting with `get` since most functions get *something*. It's thus redundant and uniniformative. For example, it's pretty obvious that `parameter_names(m::Model, comp_name::Symbol)` should get parameter names from the given component and model. 
 
 2. Exceptions to rule 1 include naming pairs of get/set functions like `getproperty` and `setproperty`, or whenever the name isn't clear without "get".

 3. Use underscores to separate words for names exceeding 2 words or 12 characters. These limits are arbitrary (and we might choose other ones), but a rule like this makes the code more predictable and legible. (Note that eliminating the "get" prefix means less need for underscores.)

 I have also modified names that were unclear or poorly matched:

 * In connections, `source` and `target` have become `src` and `dst` ("target" wasn't clear)

* In Timestep types and related uses, `offset` and `start` (both are used) have become `start_year`, and `final` 
  has become `end_year`. "Offset" wasn't clear; and `start` / `final` were mis-matched noun / adjective.)


#### Readabiiity

* Put spaces around all operators: write `if a == b`, not `if a==b`

* Define local variables to hold values used repeatedly. Use a short, meaningful name rather a single letter.


#### Move toward functional programming

The "coin of the realm" in julia is functional programming with multiple-dispatch. Defining accessor functions for data types (rather than directly accessing fields) provides a useful layer of indirection that improves code maintainability.

* If you directly access fields of a type all throughout the code, changing internal representations becomes much more costly in terms of effort. If all accesses to the field are mediated by a functional interface, only one function needs to change.

* With functional interfaces, it is very easy to delegate function calls to instances held within an object. This can't be done easily when directly accesssing a type's field.

* Functional APIs were implemented throughout the code while sorting the functionality coded in the `Model` type into the types `ModelDel` and `ModelInstance`.


### Simplification of idioms

#### `if` conditions

There were several cases of `if` expressions like:

```
if ! (foo == bar) ...
```

that were simplified to:

```
if foo != bar ...
```

#### String interpolation

Several cases like:

```
error(string("Some text ", var1, " other text"))
```

were simplified to interpolate variables, e.g.,

```
error("Some text $var1 other text")
```

## 5. Pre-compilation

To get `__precompile__()` to work required moving the creation of "helper" components to an `__init__()` method in Mimi.jl, which is run automatically after Mimi loads.

