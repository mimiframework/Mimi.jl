# Components directory

To allow for pre-compilation, the creation of "helper" components is delayed until
after Mimi is loaded, via the `__init__()` function in Mimi.jl.
All `jl` files in this directory are loaded by `__init__()`. Additions to this 
directory should be documented here.

*Note that components loaded by __init__() are loaded by the `Main` module, not the `Mimi`
module. So to place components defined here in `Mimi`, prefix the component names with 
`Mimi.`*

## Files

* `adder.jl` -- Defines `Mimi.adder`, which simply adds two parameters, `input` and `add` and stores the result in `output`.

* `multiplier.jl` -- Defines `Mimi.multiplier`, which simply multiplies two parameters, `input` and `multiply` and stores the result in `output`.

* `connector.jl` -- Defines a pair of components, `Mimi.ConnectorCompVector` and `Mimi.ConnectorCompMatrix`. These copy the
  value of parameter `input1`, if available, to the variable `output`, otherwise the value of parameter `input2` is used. It is an error if neither has a value.
