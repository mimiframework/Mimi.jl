# Frequently asked questions

```@meta
DocTestSeup = quote
    using Mimi
    using Distributions
end
```
## What's up with the name?

The name is probably an acronym for "Modular Integrated Modeling Interface", but we are not sure. What is certain is that it came up during a dinner that [Bob](http://www.bobkopp.net/), [David](http://www.david-anthoff.com/) and [Sol](http://www.solomonhsiang.com/) had in 2015. David thinks that Bob invented the name, Bob doesn't remember and Sol thinks the waiter might have come up with it (although we can almost certainly rule that option out). It certainly is better than the previous name "IAMF". We now use "Mimi" purely as a name of the package, not as an acronym.

## How do I use a multivariate distribution for a parameter within a component?

You might want to use a multivariate distribution to capture the
covariance between estimated coefficient parameters.  For example, an estimated
polynomial can be represented as a multivariate Normal distribution,
with a variance-covariance matrix.  To use this, define the parameter
in the component with a vector type, like here:

```jldoctest faq1; output = false
@defcomp MyComp begin
    cubiccoeff::Vector{Float64} = Parameter()
end

# output
```

Then construct a model and set the parameter with a multivariate
distribution:

```jldoctest faq1; output = false

# construct a model and add the component
m = Model()
set_dimension!(m, :time, collect(2015:5:2110))
add_comp!(m, MyComp)

# First line: linear, quadratic, cubic
# Lines 2-4: covariance matrix
cubicparams = [
    [-3.233303      1.911123    -0.1018884];
    [ 1.9678593    -0.57211657   0.04413228];
    [-0.57211657    0.17500949  -0.01388863];
    [ 0.04413228   -0.01388863   0.00111965]
]

set_param!(m, :MyComp, :cubiccoeff, MvNormal(cubicparams[1,:], cubicparams[2:4,:]))

# output
```

Note that we could also load the data fom a file with:

```julia
cubicparams = readdlm("../data/cubicparams.csv", ',')
```
where `../data/cubicparams.csv` would be a parameter definition file that looks something like this:
```julia 
# Example estimated polynomial parameter
# First line: linear, quadratic, cubic
# Lines 2-4: covariance matrix
-3.233303,1.911123,-.1018884
1.9678593,-.57211657,.04413228
-.57211657,.17500949,-.01388863
.04413228,-.01388863,.00111965
```

## How do I use component references?

Component references allow you to write cleaner model code when connecting components.  The `add_comp!` function returns a reference to the component that you just added:

```jldoctest faq2; output = false
# create a component
@defcomp MyComp begin
    # empty
end

# construct a model and add the component
m = Model()
set_dimension!(m, :time, collect(2015:5:2110))
add_comp!(m, MyComp)

# output
Mimi.ComponentReference(1-component Mimi.Model:
  MyComp::Main.MyComp
, :MyComp)
```

If you want to get a reference to a component after the `add_comp!` call has been made, you can construct the reference as:
```jldoctest faq2; output = false
mycomponent = Mimi.ComponentReference(m, :MyComp)

# output 
Mimi.ComponentReference(1-component Mimi.Model:
  MyComp::Main.MyComp
, :MyComp)
```

You can use this component reference in place of the `set_param!` and `connect_param!` calls.

## References in place of `set_param!`

The line `set_param!(model, :MyComponent, :myparameter, myvalue)` can be written as `mycomponent[:myparameter] = myvalue`, where `mycomponent` is a component reference.

## References in place of `connect_param!`

The line `connect_param!(model, :MyComponent, :myparameter, :YourComponent, :yourparameter)` can be written as `mycomponent[:myparameter] = yourcomponent[:yourparameter]`, where `mycomponent` and `yourcomponent` are component references.

```@meta
DocTestSetup = nothing
```