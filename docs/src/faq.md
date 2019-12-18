# Frequently asked questions

## What's up with the name?

The name is probably an acronym for "Modular Integrated Modeling Interface", but we are not sure. What is certain is that it came up during a dinner that [Bob](http://www.bobkopp.net/), [David](http://www.david-anthoff.com/) and [Sol](http://www.solomonhsiang.com/) had in 2015. David thinks that Bob invented the name, Bob doesn't remember and Sol thinks the waiter might have come up with it (although we can almost certainly rule that option out). It certainly is better than the previous name "IAMF". We now use "Mimi" purely as a name of the package, not as an acronym.

## How do I use component references?

Component references allow you to write cleaner model code when connecting components.  The `add_comp!` function returns a reference to the component that you just added:

```jldoctest faq1; output = false
using Mimi

# create a component
@defcomp MyComp begin
    # empty
end

# construct a model and add the component
m = Model()
set_dimension!(m, :time, collect(2015:5:2110))
add_comp!(m, MyComp)
typeof(MyComp) # note the type is a Mimi Component Definition

# output

Mimi.ComponentDef
```

If you want to get a reference to a component after the `add_comp!` call has been made, you can construct the reference as:

```jldoctest faq1; output = false
mycomponent = Mimi.ComponentReference(m, :MyComp)
typeof(mycomponent) # note the type is a Mimi Component Reference

# output

Mimi.ComponentReference
```

You can use this component reference in place of the `set_param!` and `connect_param!` calls.

## References in place of `set_param!`

The line `set_param!(model, :MyComponent, :myparameter, myvalue)` can be written as `mycomponent[:myparameter] = myvalue`, where `mycomponent` is a component reference.

## References in place of `connect_param!`

The line `connect_param!(model, :MyComponent, :myparameter, :YourComponent, :yourparameter)` can be written as `mycomponent[:myparameter] = yourcomponent[:yourparameter]`, where `mycomponent` and `yourcomponent` are component references.
