# How-to Guide 1: Construct and Run a Model

This how-to guide pairs nicely with [Tutorial 4: Create a Model](@ref) and [Tutorial 6: Create a Model Including Composite Components](@ref), and serves as a higher-level version and refresher for those with some experience with Mimi.  If this is your first time constructing and running a Mimi model, we recommend you start with Tutorial 4 (and Tutorial 6 if you are interested in composite components), which will give you more detailed step-by step instructions.

## Defining Components

Any Mimi model is made up of at least one component, so before you construct a model, you need to create your components. 

Mimi provides two types of components, leaf components and composite components, which generally match intuitively with the classic computer science tree data structure. Note that many existing models are "flat models" with one layer of components, and thus only contain leaf components.

### Leaf Components

A leaf component can have any number of parameters and variables. Parameters are data values that will be provided to the component as input, and variables are values that the component will calculate in the `run_timestep` function when the model is run. The index of a parameter or variable determines the number of dimensions that parameter or variable has. They can be scalar values and have no index, such as parameter 'c' in the example below. They can be one-dimensional, such as the variable 'A' and the parameters 'd' and 'f' below. They can be two dimensional such as variable 'B' and parameter 'e' below. Note that any index other than 'time' must be declared at the top of the component, as shown by `regions = Index()` below.

The user must define a `run_timestep` function for each component. 

We define a leaf component in the following way:

```jldoctest; output = false
using Mimi

@defcomp MyComponentName begin
  regions = Index()

  A = Variable(index = [time])
  B = Variable(index = [time, regions])

  c = Parameter()
  d = Parameter(index = [time])
  e = Parameter(index = [time, regions])
  f = Parameter(index = [regions])

  function run_timestep(p, v, d, t)
    v.A[t] = p.c + p.d[t]
    for r in d.regions
      v.B[t, r] = p.f[r] * p.e[t, r]
    end
  end
end

# output

```

The `run_timestep` function is responsible for calculating values for each variable in that component.  Note that the component state (defined by the first three arguments) has fields for the Parameters, Variables, and Dimensions of the component you defined. You can access each parameter, variable, or dimension using dot notation as shown above.  The fourth argument is an `AbstractTimestep`, i.e., either a `FixedTimestep` or a `VariableTimestep`, which represents which timestep the model is at.

The API for using the fourth argument, represented as `t` in this explanation, is described in a following how-to guide How-to Guide 4: Work with Timesteps, Parameters, and Variables. 

To access the data in a parameter or to assign a value to a variable, you must use the appropriate index or indices (in this example, either the Timestep or region or both).

By default, all parameters and variables defined in the [`@defcomp`](@ref) will be allocated storage as scalars or Arrays of type `Float64.` For a description of other data type options, see How-to Guide 5: Work with Parameters and Variables 

### Composite Components

Composite components can contain any number of subcomponents, **which can be either leaf components or more composite components**. To the degree possible, composite components are designed to operate in the same way as leaf components, although there are a few necessary differences:

- Leaf components are defined using the macro [`@defcomp`](@ref), while Composite components are defined using [`@defcomposite`](@ref). Each macro supports syntax and semantics specific to the type of component.

- Leaf components support user-defined `run_timestep()` functions, whereas composites have a built-in `run_timestep()` function that iterates over its subcomponents and calls their `run_timestep()` function.

A composite component can have any number of parameters and variables, which point to one or more parameters or variables in the composite's subcomponents.  Data all eventually flows through to the leaf components, where calculations are made at runtime and then data is bubbled up into composite components as necessary.

Note that it is not imperative that you explicitly define parameters or variables in a composite component.  It may be desireable for specific use cases, such as ease of access for future connections, future model modification, connecting multiple subcomponent parameters or variables to one higher level component parameter or variable, or parameter conflict resolution (explained below). 

We define a composite component in the following way:

First we will need to have defined some leaf components:
```julia 
@defcomp Leaf1 begin
    par_1_1 = Parameter(index=[time])      
    var_1_1 = Variable(index=[time])       
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Leaf2 begin
    par_2_1 = Parameter(index=[time])      
    par_2_2 = Parameter(index=[time])      
    var_2_1 = Variable(index=[time])      
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo * p.par_2_2[t]
    end
end
```
Now we construct a composite component `MyCompositeComponent` which holds the two subcomponents, `Leaf1` and `Leaf2`:
```julia
@defcomposite MyCompositeComponent begin
    Component(Leaf1)
    Component(Leaf2)

    foo1 = Parameter(Leaf1.foo)
    foo2 = Parameter(Leaf2.foo)

    var_2_1 = Variable(Leaf2.var_2_1)

    connect(Leaf2.par_2_1, Leaf1.var_1_1)
    connect(Leaf2.par_2_2, Leaf1.var_1_1)
end
```

The `connect` calls are responsible for making internal connections between any two components held by a composite component, similar to [`connect_param!`](@ref) described in the Model section below. 

As mentioned above, conflict resolution refers to cases where two subcomponents have identically named parameters, and thus the user needs to explicitly demonstrate that they are aware of this and create a new shared model parameter that will point to all subcomponent parameters with that name.  For example, given leaf components `A` and `B`: 

```julia
@defcomp Leaf1 begin
    p1 = Parameter()
    v1 = Variable(index=[time])
end

@defcomp Leaf2 begin
    p1 = Parameter()
end
```
The following will fail because you need to resolve the namespace collision of the `p1`'s:
```julia
@defcomposite MyCompositeComponent begin
    Component(Leaf1)
    Component(Leaf2)
end
```
Fix it with a call to `Parameter` as follows:
```julia
@defcomposite MyCompositeComponent begin
    Component(Leaf1)
    Component(Leaf2)
        
    p1 = Parameter(Leaf1.p1, Leaf2.p1)
end
```

## Constructing a Model

Continuing the analogy of a tree data structure, one may consider the Model to be the root, orchestrating the running of all components it contains.

The first step in constructing a model is to set the values for each index of the model. Below is an example for setting the 'time' and 'regions' indexes. The time index expects either a numerical range or an array of numbers.  If a single value is provided, say '100', then that index will be set from 1 to 100. Other indexes can have values of any type.

```jldoctest; output = false
using Mimi

m = Model()
set_dimension!(m, :time, 1850:2200)
set_dimension!(m, :regions, ["USA", "EU", "LATAM"])

# output

["USA", "EU", "LATAM"]
```

*A Note on Time Indexes:* It is important to note that the values used for the time index are the *start times* of the timesteps.  If the range or array of time values has a uniform timestep length, the model will run *through* the last year of the range with a last timestep period length consistent with the other timesteps.  If the time values are provided as an array with non-uniform timestep lengths, the model will run *through* the last year in the array with a last timestep period length *assumed to be one*. 

The next step is to add components to the model. This is done by the following syntax:

```julia 
add_comp!(m, ComponentA)
add_comp!(m, ComponentA, :GDP)
```

The first argument to [`add_comp!`](@ref) is the model, the second is the name of the ComponentId defined by [`@defcomp`](@ref). If an optional third symbol is provided (as in the second line above), this will be used as the name of the component in this model. This allows you to add multiple versions of the same component to a model, with different names.

The [`add_comp!`](@ref) function has two more optional keyword arguments, `first` and `last`, which can be used to indicate a fixed start and/or end time (year in this case) that the compnonent should run for (within the bounds of the model's time dimension).  For example, the following indicates that `ComponentA` should only run from 1900 to 2000.

```julia
add_comp!(m, ComponentA; first = 1900, last = 2000)
```

The next step is to set the values for all the parameters in the components. Parameters can either have their values assigned from external data, or they can internally connect to the values from variables in other components of the model. When assigned from external data, parameters are externally connected to a model parameter, which can be a shared model parameter with its own name and connected to more than one component-parameter pair, or an unshared model paarameter accessible only through the component-parameter pair names and connected solely to that parameter.

To make an external connection to an unshared model parameter, the syntax is as follows:

```julia
update_param!(m, :ComponentName, :ParameterName1, 0.8) # a scalar parameter
update_param!(m, :ComponentName, :ParameterName2, rand(351, 3)) # a two-dimensional parameter
```

To make an external connection to a shared model parameter, the syntax is as follows:

```julia
add_shared_param!(m, :ModelParameterName, 1.0) # add a shared model parameter to the model
connect_param!(m, :ComponentName, :ParameterName3, :ModelParameterName) # connect component parameter
connect_param!(m, :ComponentName, :ParameterName4, :ModelParameterName)
```

To make an internal connection, the syntax is as follows.  

```julia
connect_param!(m, :TargetComponent, :ParameterName, :SourceComponent, :VariableName)
connect_param!(m, :TargetComponent, :ParameterName, :SourceComponent, :VariableName)
```
or
```julia
connect_param!(m, :TargetComponent=>:ParameterName, :SourceComponent=>:VariableName)
connect_param!(m, :TargetComponent=>:ParameterName, :SourceComponent=>:VariableName)
```

If you wish to delete a component that has already been added, do the following:

```julia
delete!(m, :ComponentName)
```

This will delete the component from the model and remove any existing connections it had. Thus if a different component was previously connected to this component, you will need to connect its parameter(s) to something else.

## Running a Model

After all components have been added to your model and all parameters have been connected to either external values or internally to another component, then the model is ready to be run. Note: at each timestep, the model will run the components in the order you added them. So if one component is going to rely on the value of another component, then the user must add them to the model in the appropriate order.

```julia
run(m)
```

## Long Example

As a final, lengthier example, below we use the syntax in this tutorial to create and run a toy model with the following structure:

          top
        /     \
       A       B
     /  \     /  \
    1    2   3    4

```julia
@defcomp Comp1 begin
    par_1_1 = Parameter(index=[time])      # external input
    var_1_1 = Variable(index=[time])       # computed
    foo = Parameter()
    function run_timestep(p, v, d, t)
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Comp2 begin
    par_2_1 = Parameter(index=[time])      # connected to Comp1.var_1_1
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()
    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo * p.par_2_2[t]
    end
end

@defcomp Comp3 begin
    par_3_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_3_1 = Variable(index=[time])       # external output
    foo = Parameter(default=30)

    function run_timestep(p, v, d, t)
        # @info "Comp3 run_timestep"
        v.var_3_1[t] = p.par_3_1[t] * 2
    end
end

@defcomp Comp4 begin
    par_4_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_4_1 = Variable(index=[time])        # external output
    foo = Parameter(default=300)

    function run_timestep(p, v, d, t)
        # @info "Comp4 run_timestep"
        v.var_4_1[t] = p.par_4_1[t] * 2
    end
end

@defcomposite A begin
    Component(Comp1)
    Component(Comp2)

    foo1 = Parameter(Comp1.foo)
    foo2 = Parameter(Comp2.foo)

    var_2_1 = Variable(Comp2.var_2_1)

    connect(Comp2.par_2_1, Comp1.var_1_1)
    connect(Comp2.par_2_2, Comp1.var_1_1)
end

@defcomposite B begin
    Component(Comp3)
    Component(Comp4)

    foo3 = Parameter(Comp3.foo)
    foo4 = Parameter(Comp4.foo)

    var_3_1 = Variable(Comp3.var_3_1)
end

@defcomposite top begin
    Component(A)

    fooA1 = Parameter(A.foo1)
    fooA2 = Parameter(A.foo2)

    # TBD: component B isn't getting added to mi
    Component(B)
    foo3 = Parameter(B.foo3)
    foo4 = Parameter(B.foo4)

    var_3_1 = Variable(B.var_3_1)

    connect(B.par_3_1, A.var_2_1)
    connect(B.par_4_1, B.var_3_1)
end

m = Model()
set_dimension!(m, :time, 2005:2020)
add_comp!(m, top, nameof(top))
update_param!(m, :top, :fooA1, 1)
update_param!(m, :top, :fooA2, 2)
update_param!(m, :top, :foo3, 10)
update_param!(m, :top, :foo4, 20)
update_param!(m, :top, :par_1_1, collect(1:length(2005:2020)))
run(m)
```
Take a look at what you've created now using `explore(m)`, a peek into what you can learn in How To Guide 2!
