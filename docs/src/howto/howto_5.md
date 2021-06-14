# How-to Guide 5: Work with Parameters and Variables

## Parameters

Component parameters in Mimi obtain values either (1) from a variable calculated by another component and passed through an internal connection or (2) from an externally set value stored in a model parameter.  For the latter case, model parameters can be unshared, such that they can only connect to one component/parameter pair and must be accessed by specifying both the component and component's parameter name, or shared, such that they can connect to mulitple component/parameter pairs and have a unique name they can be referenced with. 

In the next few subsections we will present the API for setting, connecting, and updating parameters as presented by different potential use cases. The API consistes of only a few primary functions:

- [`update_param!`](@ref)
- [`add_shared_param!`](@ref)
- [`disconnect_param!`](@ref)
- [`connect_param!`](@ref)

along with the useful functions for batch setting:
- [`update_params!`](@ref)
- [`update_leftover_params!`](@ref)

### Parameters when Creating a Model

Take the example case of a user starting out building a two-component toy model.
```julia
@defcomp A begin
    p1 = Parameter(default = 2)
    p2 = Parameter(index = [time])

    v1 = Variable()

    function run_timestep(p, v, d, t)
        v.v1 = p.p1
    end
end

@defcomp B begin
    p3 = Parameter()
    p4 = Parameter(index = [time])
    p5 = Parameter()

    v2 = Variable()
    function run_timestep(p, v, d, t)
        v.v2 = p.p3
    end
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, A)
add_comp!(m, B)
```
After the calls to [`add_comp!`](@ref), all four parameters are connected to a respective unshared model parameter.  These unshared model parameters for `A`'s, `p2`, `B`'s `p3` and `p4` hold sentinel values of `nothing`, while that connected to `A`'s `p1` holds the value 2 as designated by the call to the `default` argument.

At this point, you cannot `run(m)`, you will encounter:
```julia
run(m)
ERROR: Cannot build model; the following parameters still have values of nothing 
and need to be updated or set:
  p2
  p3
  p4
  p5
```
Per the above, we need to update these parameters so that they are connected to a non-`nothing` value.  We have three cases here, (1) we want to update the value of an unshared parameter from `nothing` to a value, (2) we want to add a shared parameter and connect one or, more commonly, several component parameters to it, or (3) we want to connect a parameter to another component's variable.

**Case 1:** In the first case, we simply call [`update_param!`](@ref) ie.
```julia
update_param!(m, :B, :p3, 5)
```
The dimensions and datatype of the `value` set above will need to match those designated for the component's parameter, or corresponding appropriate error messages will be thrown. 

**Case 2:** In the second case, we will explicitly create and add a shared model parameter with [`add_shared_param!`](@ref) and then connect the parameters with [`connect_param!`](@ref) ie.
```julia
add_shared_param!(m, :shared_param, [1,2,3,4,5,6], dims = [:time])
connect_param!(m, :A, :p2, :shared_param)
connect_param!(m, :B, :p4, :shared_param)
```
The shared model parameter can have any name, including the same name as one of the component parameters, without any namespace collision with those, although for clarity we suggest using a unique name.  

Importantly, [`add_shared_param!`](@ref) has two optional keyword arguments, `dims` and `data_type`, which mirror specifications you gave in your [`@defcomp`](@ref) parameter definition and might be needed. Again we include error messages to alert you of this.  Specifically:

- **dims::Vector{Symbol}:** If your shared model parameter will be connected to parameters with dimensions, like one defined in [`@defcomp`](@ref) with `p = Parameter(index = [time])`, you'll need to specify dimensions with `add_shared_param!(m, :model_param_name, value; dims = [time])`.  
- **data_type::DataType:** If your shared model parameter will be connected to parameters with dimensions, like one defined in [`@defcomp`](@ref) with `p = Parameter{Int64}()`, you *may* need to specify dimensions with `add_shared_param!(m, :model_param_name, value; data_type = Int64)` although we will try to interpret this under the hood for you.

Appropriate error messages will instruct you to designate these if you forget to do so, and also recognize related problems with connections to parameters.


**Case 3.:** In the third case we want to connect `B`'s `p5` to `A`'s `v1`, and we can do so with:
```julia
connect_param!(m, :B, :p5, :A, :v1)
```

Now all your parameters are properly connected and you may run your model.
```
run(m)
```

### Parameters when Modifying a Model

Now say we have been given our model `m` above and we want to make some changes. Below we use some explicit examples that  together should cover quite a few general cases.  If something is not covered here that would be a useful case for us to explicitly explain, **don't hesitate to reach out**. We have also aimed to include useful warnings and error messages to point you in the right direction.

To **update a parameter connected to an unshared model parameter**, use the same [`update_param!`](@ref) function as above:
```julia
update_param!(m, :A, :p1, 5)
```
Trying this call when `A`'s parameter `p1` is connected to a shared parameter will error, and instruct you on the steps to use to either update the shared model parameter, or disconnect `A`'s `p1` from that shared model parameter and then proceed, both as explained below.

To **update parameters connected to a shared model parameter**, use [`update_param!`](@ref)  with different arguments, specifying the shared model parameter name:
```julia
update_param!(m, :shared_param, 5)
```

To **connect a parameter to another component's variable**, the below will disconnect any existing connections from `B`'s `p3` ([`disconnect_param!`](@ref) under the hood) and make the internal parameter connection to `A`'s `v1`: 
```julia
connect_param!(m, :B, :p3, :A, :v1)
```
Symmetrically, a subsequent call to [`update_param!`](@ref) would remove the internal connection and connect instead to an unshared model parameter as was done in the original `m`:
```julia
update_param!(m, :B, :p3, 10)
```

To **move from an external connection to a shared model parameter to an external connection to an unshared model parameter** use [`disconnect_param!`](@ref) followed by [`update_param!`](@ref) :
```julia
disconnect_param!(m, :A, :p2)
update_param!(m, :A, :p2, [101, 102, 103, 104, 105, 106])
```
noting that this last call could also be a [`connect_param!`](@ref) to another parameter or variable etc., `A`'s `p2` is now free to be reset in any way you want.

### Other Details

#### Units

In some cases you may have a model that specifies the units of parameters:
```julia
@defcomp A begin
    p1 = Parameter(unit = "\$")
    function run_timestep(p, v, d, t)
    end
end

@defcomp B begin
    p2 = Parameter(unit = "thousands of \$")
    function run_timestep(p, v, d, t)
    end
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, A)
add_comp!(m, B)
```
If you want to connect `p1` and `p2` to the same shared model parameter, you will encounter an error because the units do not match:
```julia
add_shared_param!(m, :shared_param, 100)
connect_param!(m, :A, :p1, :shared_param) # no error here
connect_param!(m, :B, :p2, :shared_param)

ERROR: Units of compdef:p2 (thousands of $) do not match the following other 
parameters connected to the same shared model parameter shared_param.  To override 
this error and connect anyways, set the `ignoreunits` flag to true: 
`connect_param!(m, comp_def, param_name, model_param_name; ignoreunits = true)`. 
MISMATCHES OCCUR WITH: [A:p1 with units $]  
```
As you see in the error message, if you want to override this error, you can use the `ignoreunits` flag:
```julia
connect_param!(m, :B, :p2, :shared_param, ignoreunits=true)
```
#### Batch Update all Unset Parameters with a Dictionary

When building up a model, you may end up with several parameters that have not been explicitly updated that you want to batch update with pre-computer and saved values (ie. in a `csv` file). Before this update, the values still hold the a unusable sentinal value of `nothing` from intialization. A model with such parameters is not runnable.

The [`update_leftover_params!`](@ref) call takes a model and dictionary and updates the values of each the sentinal `nothing` model parameters by searching for their corresponding `(component_name, parameter_name)` pair in the provided dictionary with entries `k => v`, where `k` is a Tuple of Strings or Symbols `(component_name, parameter_name)`.  The signature for this function is
```
update_leftover_params!(m::Model, parameters::Dict)
```
For example, given a model `m` with with component `A`'s parameters `p1` and `p2` which have not been updated from `nothing`, along with component `B`'s parameter `p1` that has not been updated.  In this case the following will update those parameters and make the model runnable:
```
parameters = Dict((:A, :p1) => 1, (:A, :p2) => :foo, (:B, :p1) => 100)
update_leftover_params!(m, parameeters)
```
Note that your dictionary `parameters` **must include all leftover parameters that need to be set**, not just a subset of them, or it will error when it cannot find a desired key.

#### Batch Update Specified Parameters with a Dictionary

You can batch update a defined set of parameters using a `Dict` and the function [`update_params!`](@ref).  You can do so for any set of unshared or shared model parameters.  The signature for this function is:
```julia
update_params!(m::Model, parameters::Dict)
```
For each (k, v) pair in the provided `parameters` dictionary, [`update_param!`](@ref) is called to update the model parameter identified by the key to value v. For updating unshared parameters, each key k must be a Tuple matching the name of a component in `m` and the name of an parameter in that component. For updating shared parameters, each key k must be a symbol or convert to a symbol  matching the name of a shared model parameter that already exists in the model.

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

#### Anonymous Parameter Indices

As mentioned above, a parameter can have no index (a scalar), or one or multiple of the model's indexes. A parameter can also have an index specified in the following ways:

```julia
@defcomp MyComponent begin
  p1 = Parameter(index=[4]) # an array of length 4
  p2 = Parameter{Array{Float64, 2}}() # a two dimensional array of unspecified length
end
```

In both of these cases, the parameter's values are stored of as an array (p1 is one dimensional, and p2 is two dimensional). But with respect to the model, they are considered "scalar" parameters, simply because they do not use any of the model's indices (namely 'time', or 'regions').

#### Using NamedArrays for Setting Parameters

When a user sets a parameter, Mimi checks that the size and dimensions match what it expects for that component. If the user provides a NamedArray for the values, Mimi will further check that the names of the dimensions match the expected dimensions for that parameter, and that the labels match the model's index values for those dimensions. Examples of this can be found in "test/test_parameter_labels.jl".

## Variables

[TODO]

## DataType specification of Parameters and Variables 

By default, the Parameters and Variables defined by a user will be allocated storage arrays of type `Float64` when a model is constructed. This default "number_type" can be overriden when a model is created, with the following syntax:
```julia
m = Model(Int64)    # creates a model with default number type Int64
```
But you can also specify individual Parameters or Variables to have different data types with the following syntax in a [`@defcomp`](@ref) macro:
```julia
@defcomp example begin
  p1 = Parameter{Bool}()                         # ScalarModelParameter that is a Bool
  p2 = Parameter{Bool}(index = [regions])        # ArrayModelParameter with one dimension whose eltype is Bool
  p3 = Parameter{Matrix{Int64}}()                # ScalarModelParameter that is a Matrix of Integers
  p4 = Parameter{Int64}(index = [time, regions]) # ArrayModelParameter with two dimensions whose eltype is Int64
end
```
If there are "index"s listed in the Parameter definition, then it will be an `ArrayModelParameter` whose `eltype` is the type specified in the curly brackets. If there are no "index"s listed, then the type specified in the curly brackets is the actual type of the parameter value, and it will be represent by Mimi as a `ScalarModelParameter`.

If you use this functionality and then `connect_param!` these Parameters to model parameters, you may need to 
use the `data_type` keyword argument to specifiy the desired `DataType` of your connected parameter.
