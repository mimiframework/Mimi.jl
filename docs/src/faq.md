# Frequently asked questions

## What's up with the name?

The name is probably an acronym for "Modular Integrated Modeling Interface", but we are not sure. What is certain is that it came up during a dinner that [Bob](http://www.bobkopp.net/), [David](http://www.david-anthoff.com/) and [Sol](http://www.solomonhsiang.com/) had in 2015. David thinks that Bob invented the name, Bob doesn't remember and Sol thinks the waiter might have come up with it (although we can almost certainly rule that option out). It certainly is better than the previous name "IAMF". We now use "Mimi" purely as a name of the package, not as an acronym.

## How do I use a multivariate distribution for a parameter within a component?

You might want to use a multivariate distribution to capture the
covariance between estimated coefficient parameters.  For example, an estimated
polynomial can be represented as a multivariate Normal distribution,
with a variance-covariance matrix.  To use this, define the parameter
in the component with a vector type, like here:
```
@defcomp example begin
    cubiccoeffs::Vector{Float64} = Parameter()
end
```

Then in the model construction, set the parameter with a multivariate
distribution (here the parameters are loaded from a CSV file):
```
cubicparams = readdlm("../data/cubicparams.csv", ',')
setparameter(m, :example, :cubiccoeff, MvNormal(squeeze(cubicparams[1,:], 1), cubicparams[2:4,:]))
```

Here, `../data/cubicparams.csv` is a parameter definition file that looks something like this:
```
# Example estimated polynomial parameter
# First line: linear, quadratic, cubic
# Lines 2-4: covariance matrix
-3.233303,1.911123,-.1018884
1.9678593,-.57211657,.04413228
-.57211657,.17500949,-.01388863
.04413228,-.01388863,.00111965
```

## How do I use component references?

Component references allow you to write cleaner model code when connecting components.  The `component` function returns a reference to the component that you just added:
```
mycomponent = addcomponent(model, MyComponent)
```

If you want to get a reference to a component after the `component` call has been made, you can construct the reference as:
```
mycomponent = ComponentReference(model, :MyComponent)
```

You can use this component reference in place of the `set_parameter!` and `connect_parameter` calls.

## References in place of `set_parameter!`

The line `set_parameter!(model, :MyComponent, :myparameter, myvalue)` can be written as `mycomponent[:myparameter] = myvalue`, where `mycomponent` is a component reference.

## References in place of `connect_parameter`

The line `connect_parameter(model, :MyComponent, :myparameter, :YourComponent, :yourparameter)` can be written as `mycomponent[:myparameter] = yourcomponent[:yourparameter]`, where `mycomponent` and `yourcomponent` are component references.
