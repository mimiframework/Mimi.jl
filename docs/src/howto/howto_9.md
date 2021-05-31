# How-to Guide 9: Port to New Parameter API
## ... phasing out `set_param!` for all `update_param!`

In the most recent feature release, Mimi has moved towards a new API for working with parameters that will hopefully be (1) simpler (2) clearer and (3) avoid unexpected behavior created by too much "magic" under the hood, per user requests.

The following will first summarize the new, encouraged API and then take the next section to walk through the suggested ways to move from the older API, which includes `set_param!`, to the new API, which phases out `set_param!`.  This release **should not be breaking** meaning that moving from the older to newer API may be done on your own time, although we would encourage taking the time to do so.  Per usual, use the forum to ask any questions you may have, we will monitor closely to help work through corner cases etc.   

## Summary of the New API (See How-to Guide 5 for Details)

Here we briefly summarize the new, encouraged parameter API.  We encourage users to follow-up by reading How-to Guide 5's "Parameters" section for a detailed description of this new API, since the below is a summary for brevity and to avoid duplication.  Below a short section will also note a related change to the `@defsim` Monte Carlo Simulation macro.  

### Parameters

Component parameters in Mimi obtain values either (1) from a variable calculated by another component and passed through an internal connection or (2) from an externally set value stored in a model parameter.  For the latter case, model parameters can be unshared, such that they can only connect to one component/parameter pair and must be accessed by specifying both the component and component's parameter name, or shared, such that they can connect to mulitple component/parameter pairs and have a unique name they can be referenced with. 

In the next few subsections we will present the API for setting, connecting, and updating parameters as presented by different potential use cases. The API consistes of only a few primary functions:

- [`update_param!`](@ref)
- [`add_shared_param!`](@ref)
- [`disconnect_param!`](@ref)
- [`connect_param!`](@ref)

along with the useful functions for batch setting:
- [`update_params!`](@ref)
- `update_leftover_params!`

### Monte Carlo Simulations

We have introduced new syntax to the monte carlo simulation definition macro `@defsim` to handle both shared and unshared parameters. This is presented below:
Previously, one would always assign a random variable to a model parameter with syntax like:
```julia
myparameter = Normal(0,1)
# or
rv(myrv) = Normal(0,1)
myparameter = myrv
```
Now, this syntax will only work if `myparameter` is a shared model parameter and thus accesible with that name.  If the parameter is an unshared model parameter, use dot syntax like
```julia
mycomponent.myparameter = Normal(0,1)
# or
rv(myrv) = Normal(0,1)
mycomponent.myparameter = myrv
```

## Porting to the new API

On a high level, calls to `set_param!` always related to **shared** model parameters, so it very likely that almost all of your current parameters are shared model parameters.  The exception is parameters that are set by `default = ...` arguments in their `@defcomp` and then never reset, these will automatically be **unshared** model parameters.  

The changes you will want to make consist of (1) deciding which parameters you actually want to be connected to shared model parameters vs those you want to be connected to unshared model parameters (probably the majority) and (2) updating your code accordingly. You will also need to make related updates to `@defsim` monte carlo simulation definitions.

** This section is not exhaustive, especially since `set_param!` has quite a few different methods for different permutations of arguments, so please don't hesitate to get in touch with questions about your specific use cases!**

### `set_param!` and `update_param`

*The Mimi Change*

An old API call to `set_param!` is equivalent to a combination of calls to `add_shared_param!` and `connect_param!`.  For example,
```julia
set_param!(m, comp_name, param_name, model_param_name, value)
```
is equivalent to 
```julia
add_shared_param!(m, shared_param_name, value)
connect_param!(m, comp_name, param_name, shared_param_name)
```
and similarly a call to 
```julia
set_param!(m, comp_name, param_name, value)
```
is equivalent to
```julia
add_shared_param!(m, model_param_name, value) # shared parameter gets the same name as the component parameter
connect_param!(m, comp_name, param_name, param_name) # once per component with a parameter named `param_name`
```

An old API call to `update_param!` has the same function as previously:
```julia
update_param!(m, shared_param_name, value)
```
will update a shared model parameter with name `shared_param_name` to `value`, thus updating all component/parameter pairs externally connected to this shared model parameter, while our new call that previously was not in the API
```julia
update_param!(m, comp_name, param_name, value)
```
will update the unshared model parameter externally connected to `comp_name`'s `param_name` to `value`.

*The User Change*

Taking a look at your code, if you see a call to `set_param!`, first decide if this is a case where you want to create a shared model parameter that can be connected to several component/parameter pairs.  In many cases you will see a call to `set_param!` with four arguments:
```julia
set_param!(m, comp_name, param_name, value)
```
and the desired behavior is that this component/parameter pair be connected to an unshared model parameter.  To do this, change `set_param!` to `update_param!` with the same arguments:
```julia
update_param!(m, comp_name, param_name, value)
```
Recall that now you do not have a model parameter accessible using just `param_name`, your unshared model parameter has an under-the-hood unique name to prevent collisions, and you will only be able to access it with a combination of `comp_name` and `param_name`. Updating this parameter in the future can thus use the same syntax:
```julia
update_param!(m, comp_name, param_name, new_value)
```

Now, suppose you actually do want to create a shared model parameter.  In this case, you may see a call to `set_param!` like:
```julia
set_param!(m, param_name, value)
```
and you may want to keep this as the creation of and connection to a shared model parameter.  In this case, you will use a combination of calls:
```julia
add_shared_param!(m, param_name, value)
connect_param!(m, comp_name_1, param_name, param_name)
connect_param!(m, comp_name_2, param_name, param_name)
```
where the call to `connect_param!` must be made once for each component/parameter pair you want to connect to the shared model parameter, which previously was done under the hood by searching for all component's with a parameter with the name `param_name`. Note that in this new syntax, it's actually preferable not to use the same `param_name` for your shared model parameter.  To keep your scripts understandable, we would recommend using a different parameter name, like follows.  You can also connect parameters to this shared model parameter that do not share its name. **In essense Mimi will not make assumptions that component's with the same parameter name should get the same value**, you must be explicit:
```julia
add_shared_param!(m, shared_param_name, value)
connect_param!(m, comp_name_1, param_name_1, shared_param_name)
connect_param!(m, comp_name_2, param_name_2, shared_param_name)
```
Now you have a shared model parameter accessible with `shared_param_name` and updating this parameter in the future can thus use the three argument `update_param!` syntax:
```julia
update_param!(m, shared_param_name, new_value)
```

### `update_params!`

*The Mimi Change*

Previously, one could batch update a set of parameters using a `Dict` and the function [`update_params!`](@ref), which you passed a model `m` and a dictionary `parameters` with entries `k => v` where the key `k` was a Symbol matching the name of a shared model parameter and `v` the desired value.  This will still work for shared model parameters, but we have added a new type of entry `k => v` where `k` is a Tuple of `(component_name, parameter_name)`. 

The signature for this function is:
```julia
update_params!(m::Model, parameters::Dict)
```
For each (k, v) pair in the provided `parameters` dictionary, `update_param!` is called to update the model parameter identified by the key to value v. For updating unshared parameters, each key k must be a Tuple matching the name of a component in `m` and the name of an parameter in that component. For updating shared parameters, each key k must be a symbol or convert to a symbol  matching the name of a shared model parameter that already exists in the model.

For example, given a model `m` with a shared model parameter `shared_param` connected to several component parameters, and two unshared model parameters `p1` and `p2` in a component `A`:
```julia
# update shared model parameters and unshared model parameters seprately
shared_dict = Dict(:shared_param => 1)
unshared_dict = Dict((:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, shared_dict)
update_params!(m, unshared_dict)

# update both at the same time
dict = Dict(:shared_param => 1, (:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, dict)
```

*The User Change*

Current calls to `update_params!` will still work as long as the keys are shared model parameters, if they no longer exist in your model as shared model parameters you'll need to make the key a Tuple like above. 

### `update_leftover_params!`

[TODO]

### Monte Carlo Simulations with `@defsim`

*The Mimi Change*

Previously, one would always assign a random variable to a model parameter with syntax like:
```julia
myparameter = Normal(0,1)
```
or
```julia
rv(myrv) = Normal(0,1)
myparameter = myrv
```
Now, this syntax will only work if `myparameter` is a shared model parameter and thus accesible with that name.  If the parameter is an unshared model parameter, use dot syntax like
```
mycomponent.myparameter = Normal(0,1)
```
or
```julia
rv(myrv) = Normal(0,1)
mycomponent.myparameter = myrv
```

*The User Change*

In an attempt to make this transition smooth, if you use the former syntax with an unshared model parameter, such as one that is set with a `default`, we will throw a warning and try under the hood to resolve which unshared model parameter you are trying to refer to.  If we can figure it out without unsafe assumptions, we will warn about the assumption we are asking and proceed.  If we can't do so safely, we will error. If you encounter this error case, just get in touch and we will help you update your code since this release is not supposed to break code!

Thus, the easiest way to make this update is to run your existing code and look for warning and error messages which should give explicit descriptions of how to move forward to silence the warnings or resolve the errors.
