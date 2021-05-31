# Advanced How-to Guide: Using Datum References

While it is not encouraged in the customary use of Mimi, some scenarios may make using references to datum desireable for code brevity and understandability.

## Component References

Component references allow you to write cleaner model code when connecting components.  The [`add_comp!`](@ref) function returns a reference to the component that you just added:

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

If you want to get a reference to a component after the [`add_comp!`](@ref) call has been made, you can construct the reference as:

```jldoctest faq1; output = false
mycomponent = Mimi.ComponentReference(m, :MyComp)
typeof(mycomponent) # note the type is a Mimi Component Reference

# output

Mimi.ComponentReference
```

You can use this component reference in place of the [`update_param!`](@ref) and [`connect_param!`](@ref) calls:

#### References in place of `update_param!`

The line `update_param!(model, :MyComponent, :myparameter, myvalue)` can be written as `mycomponent[:myparameter] = myvalue`, where `mycomponent` is a component reference.

#### References in place of `connect_param!`

The line `connect_param!(model, :MyComponent, :myparameter, :YourComponent, :yourparameter)` can be written as `mycomponent[:myparameter] = yourcomponent[:yourparameter]`, where `mycomponent` and `yourcomponent` are component references.
