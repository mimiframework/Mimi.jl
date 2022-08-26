# How-to Guide 9: Port to New Parameter API
### ... phasing out `set_param!` for all `update_param!`

In the most recent feature release, Mimi presents a new, encouraged API for working with parameters that will hopefully be (1) simpler (2) clearer and (3) avoid unexpected behavior created by too much "magic" under the hood, per user requests.

The following will first summarize the new, encouraged API and then take the next section to walk through the suggested ways to move from the older API, which includes [`set_param!`](@ref), to the new API, which phases out [`set_param!`](@ref).  This release **should not be breaking** meaning that moving from the older to newer API may be done on your own time, although we would encourage taking the time to do so.  Per usual, use the forum to ask any questions you may have, we will monitor closely to help work through corner cases etc.   

## The New API

Here we briefly summarize the new, encouraged parameter API.  We encourage users to follow-up by reading [How-to Guide 5: Work with Parameters and Variables](@ref)'s "Parameters" section for a detailed description of this new API, since the below is only a summary for brevity and to avoid duplication.  We also note a related change to the [`@defsim`](@ref) Monte Carlo Simulation macro.  

### Parameters

Component parameters in Mimi obtain values either (1) from a variable calculated by another component and passed through an internal connection or (2) from an externally set value stored in a model parameter.  For the latter case, model parameters can be unshared, such that they can only connect to one component/parameter pair and must be accessed by specifying both the component and component's parameter name, or shared, such that they can connect to multiple component/parameter pairs and have a unique name they can be referenced with. 

In the next few subsections we will present the API for setting, connecting, and updating parameters as presented by different potential use cases. The API consists of only a few primary functions:

- [`update_param!`](@ref)
- [`add_shared_param!`](@ref)
- [`disconnect_param!`](@ref)
- [`connect_param!`](@ref)

along with the useful functions for batch setting:
- [`update_params!`](@ref)
- [`update_leftover_params!`](@ref)

### Monte Carlo Simulations

We have introduced new syntax to the monte carlo simulation definition macro [`@defsim`](@ref) to handle both shared and unshared parameters.

Previously, one would always assign a random variable to a model parameter with syntax like:
```julia
rv(myrv) = Normal(0,1)
myparameter = myrv
# or the shortcut:
myparameter = Normal(0,1)
```
Now, this syntax will only work if `myparameter` is a shared model parameter and thus accessible with that name.  If the parameter is an unshared model parameter, use dot syntax like
```julia
rv(myrv) = Normal(0,1)
mycomponent.myparameter = myrv
# or the shortcut:
mycomponent.myparameter = Normal(0,1)
```

## Porting to the New API

On a high level, calls to [`set_param!`](@ref) always related to **shared** model parameters, so it very likely that almost all of your current parameters are shared model parameters.  The exception is parameters that are set by `default = ...` arguments in their [`@defcomp`](@ref) and then never reset, these will automatically be **unshared** model parameters.  

The changes you will want to make consist of (1) deciding which parameters you actually want to be connected to shared model parameters vs those you want to be connected to unshared model parameters (probably the majority) and (2) updating your code accordingly. You also may need to make related updates to [`@defsim`](@ref) Monte Carlo simulation definitions.

**This section is not exhaustive, especially since [`set_param!`](@ref) has quite a few different methods for different permutations of arguments, so please don't hesitate to get in touch with questions about your specific use cases!**

### `set_param!` and `update_param!`

*The Mimi Change*

A call to [`set_param!`](@ref) is equivalent to the the now suggested combination of calls to [`add_shared_param!`](@ref) and [`connect_param!`](@ref).  For example:
```julia
set_param!(m, comp_name, param_name, model_param_name, value)
```
is equivalent to 
```julia
add_shared_param!(m, model_param_name, value)
connect_param!(m, comp_name, param_name, model_param_name)
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

A call to [`update_param!`](@ref) retains the same functionality, such that
```julia
update_param!(m, model_param_name, value)
```
will update a shared model parameter with name `model_param_name` to `value`, thus updating all component/parameter pairs externally connected to this shared model parameter.  In addition, we now present a new [`update_param!`](@ref):
```julia
update_param!(m, comp_name, param_name, value)
```
which will update the unshared model parameter externally connected to `comp_name`'s `param_name` to `value`. If `comp_name`'s `param_name` is connected to a shared model parameter, this call will error and present specific suggestions for either updating the shared model parameter or explicitly disconnecting your desired parameter before proceeding.

Finally, [`add_shared_param!`](@ref) has two optional keyword arguments, `dims` and `data_type`, which mirror specifications you gave in your [`@defcomp`](@ref) parameter definition and might be needed. Again we include error messages to alert you of this.  Specifically:

- **dims::Vector{Symbol}:** If your shared model parameter will be connected to parameters with dimensions, like one defined in [`@defcomp`](@ref) with `p = Parameter(index = [time])`, you'll need to specify dimensions with `add_shared_param!(m, :model_param_name, value; dims = [time])`.  
- **data_type::DataType:** If your shared model parameter will be connected to parameters with dimensions, like one defined in [`@defcomp`](@ref) with `p = Parameter{Int64}()`, you *may* need to specify dimensions with `add_shared_param!(m, :model_param_name, value; data_type = Int64)` although we will try to interpret this under the hood for you.

Appropriate error messages will instruct you to designate these if you forget to do so, and also recognize related problems with connections to parameters.


*The User Change*

Taking a look at your code, if you see a call to [`set_param!`](@ref), first decide if this is a case where you want to create a shared model parameter that can be connected to several component/parameter pairs. In many cases you will see a call to [`set_param!`](@ref) with four arguments:
```julia
set_param!(m, comp_name, param_name, value)
```
and the desired behavior is that this component/parameter pair be connected to an unshared model parameter.  To do this, change [`set_param!`](@ref) to [`update_param!`](@ref) with the same arguments:
```julia
update_param!(m, comp_name, param_name, value)
```
This will simply update the value of the unshared model parameter specific to `comp_name` and `param_name`, which will be the sentinal value `nothing` if it has not been touched since `add_comp!`. Recall that now you do not have a model parameter accessible using just `param_name`, your unshared model parameter has a hidden and under-the-hood unique name to prevent collisions, but you will only be able to access the model parameter value with a combination of `comp_name` and `param_name`. Updating this parameter in the future thus uses the same syntax:
```julia
update_param!(m, comp_name, param_name, new_value)
```

Now, suppose you actually do want to create a shared model parameter.  In this case, you may see a call to [`set_param!`](@ref) like:
```julia
set_param!(m, param_name, value)
```
and you may want to keep this as the creation of and connection to a shared model parameter.  In this case, you will use a combination of calls:
```julia
add_shared_param!(m, param_name, value)
connect_param!(m, comp_name_1, param_name, param_name)
connect_param!(m, comp_name_2, param_name, param_name)
```
where the call to [`connect_param!`](@ref) must be made once for each component/parameter pair you want to connect to the shared model parameter, which previously was done under the hood by searching for all component's with a parameter with the name `param_name`. Note that in this new syntax, it's actually preferable not to use the same `param_name` for your shared model parameter.  

To keep your scripts understandable, we would actually recommend using a different parameter name, like follows.  You can also connect parameters to this shared model parameter that do not share its name. **In essense Mimi will not make assumptions that component's with the same parameter name should get the same value**, you must be explicit:
```julia
add_shared_param!(m, model_param_name, value)
connect_param!(m, comp_name_1, param_name_1, model_param_name)
connect_param!(m, comp_name_2, param_name_2, model_param_name)
```
Now you have a shared model parameter accessible with `model_param_name` and updating this parameter in the future can thus use the three argument [`update_param!`](@ref) syntax:
```julia
update_param!(m, model_param_name, new_value)
```

### `update_params!`

*The Mimi Change*

Previously, one could batch update a set of parameters using a `Dict` and the function [`update_params!`](@ref), which you passed a model `m` and a dictionary `parameters` with entries `k => v` where the key `k` was a Symbol matching the name of a shared model parameter and `v` the desired value.  This will still work for shared model parameters, but we have added a new type of entry `k => v` where `k` is a Tuple of `(component_name, parameter_name)`. 

The signature for this function is:
```julia
update_params!(m::Model, parameters::Dict)
```
For each (k, v) pair in the provided `parameters` dictionary, [`update_params!`](@ref) is called to update the model parameter identified by the key to value v. For updating unshared parameters, each key k must be a Tuple matching the name of a component in `m` and the name of an parameter in that component. For updating shared parameters, each key `k` must be a Symbol (or convert to a Symbol) matching the name of a shared model parameter that already exists in the model.

For example, given a model `m` with a shared model parameter `model_param_name` connected to several component parameters, and two unshared model parameters `p1` and `p2` in a component `A`:
```julia
# update shared model parameters and unshared model parameters separately
shared_dict = Dict(:model_param_name => 1)
unshared_dict = Dict((:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, shared_dict)
update_params!(m, unshared_dict)

# update both at the same time
dict = Dict(:model_param_name => 1, (:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, dict)
```

*The User Change*

Current calls to [`update_params!`](@ref) will still work as long as the keys are shared model parameters, if they no longer exist in your model as shared model parameters you'll need to make the key a Tuple like above. 

### `update_leftover_params!`

*The Mimi Change*

Previously, one could batch set all unset parameters in a model using a `Dict` and the function [`set_leftover_params!`](@ref), which you passed a model `m` and a dictionary `parameters` with entries `k => v` where the key `k` was a Symbol or String matching the name of a shared model parameter and `v` the desired value.  This will still work, and will always create a new shared model parameter for each key.

We have added a new function [`update_leftover_params!`](@ref) that does the same high-level operation, but updates the values of the already created unshared model parameters for each provided key entry `k => v`, where `k` is a Tuple of Strings or Symbols `(component_name, parameter_name)`. This avoids creation of undesired shared model parameters, and the connection of more than one component-parameter pair to the same shared model parameter without explicit direction from the user.

*The User Change*

We recommend moving to use of `update_leftover_params!` by changing your dictionary keys to be `(component_name, parameter_name)`.  If previous calls to `set_leftover_params!` created shared model parameters with multiple connected component-parameter pairs **and you want to maintain this behavior**, you should do this explicitly with the aforementioned combination of `add_shared_param!` and a series of calls to `connect_param!`.


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
Now, this syntax will only work if `myparameter` is a shared model parameter and thus accessible with that name.  If the parameter is an unshared model parameter, use dot syntax like
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

The easiest way to make this update is to run your existing code and look for warning and error messages which should give explicit descriptions of how to move forward to silence the warnings or resolve the errors.
