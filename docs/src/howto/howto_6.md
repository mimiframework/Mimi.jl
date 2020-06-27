# How-to Guide 6: Port from (>=) Mimi v0.5.0 to Mimi v1.0.0

The release of Mimi v1.0.0 is a breaking release, necessitating the adaptation of existing models' syntax and structure in order for those models to run on this new version.  We have worked hard to keep these changes clear and as minimal as possible. 

This guide provides an overview of the steps required to get most models using the v0.9.5 API working with v1.0.0.  It is **not** a comprehensive review of all changes and new functionalities, but a guide to the minimum steps required to port old models between versions.  For complete information on the new version and its additional functionalities, see the full documentation.

To port your model, we recommend you update to **Mimi v0.10.0**, which is identical to Mimi v1.0.0 **except** that it includes deprecation warnings for most breaking changes, instead of errors. This means that models written using Mimi v0.9.5 will, in most cases, run successfully under Mimi v0.10.0 and things that will cause errors in v1.0.0 will throw deprecation warnings. your changes. These can guide Thus a good workflow would be:

1) Update your environment to use Mimi v0.10.0 with 
```julia
pkg> add Mimi#v0.10.0
```
2) Read through this guide to get a sense for what has changed
3) Run your code and incrementally update it, using the deprecation warnings as guides for what to change and the instructions in this guide as explanations, until no warnings are thrown and you have changed anything relevant to your code that is explained in this gude.
5) Update to Mimi v1.0.0 with the following code, which will update Mimi to it's latest version, v1.0.0
```julia
pkg> free Mimi
```
6) Run your model! Things should run smoothly now. If not double check the guide, and feel free to reach out on the forum with any questions. Also, if you are curious about the reasons behind a change, just ask!

This guide is organized into a few main sections, each descripting an independent set of changes that can be undertaken in any order desired. 

- Syntax Within the @defcomp Macro
- The set_param! Function
- The replace_comp! Function
- Different-length Components
- Marginal Models
- Simulation Syntax
- Composite Components (optional)

## Syntax Within the @defcomp Macro

#### Type-parameterization for Parameters

*The Mimi Change:* 
To be consistent with julia syntax, Mimi now uses bracketing syntax to type-parameterize `Parameter`s inside the `@defcomp` macro instead of double-colon syntax. h

*The User Change:* 
Where you previously indicated that the parameter `a` should be an `Int` with 
```julia
@defcomp my_comp begin
    a::Int = Parameter()
    function run_timestep(p, v, d, t)
    end
end
```
you should now use
```julia
@defcomp my_comp begin
    a = Parameter{Int}()
    function run_timestep(p, v, d, t)
    end
end
```

#### Integer Indexing

*The Mimi Change:* 
For safety, Mimi no longer allows indexing into `Parameter`s or `Varaible`s with the `run_timestep` function of the `@defcomp` macro with integers. Instead, this functionality is supported with two new types: `TimestepIndex` and `TimestepValue`. Complete details on indexing options can be found in How-to Guide 4: Work with Timesteps, Parameters, and Variables, but below we will describe the minimum steps to get your models working.

*The User Change:* 
Where you previously used integers to index into a `Parameter` or `Variable`, you should now use the `TimestepIndex` type.  For example, the code
```julia
function run_timestep(p, v, d, t)
    v.my_var[t] = p.my_param[10]
end
```
should now read
```julia
function run_timestep(p, v, d, t)
    v.my_var[t] = p.my_param[TimestepIndex(10)]
end
```
Also, if you previously used logic to determine which integer index pertained to a specific year, and then used that integer for indexing, you should now use the `TimestepValue` type. For example, if you previously knew that the index 2 referred to the year 2012, and added that value to a parameter with
```julia
function run_timestep(p, v, d, t)
    v.my_var[t] = p.my_param[t] + p.my_other_param[2]
end
```
you should now use
```julia
function run_timestep(p, v, d, t)
    v.my_var[t] = p.my_param[t] + p.my_other_param[TimestepValue(2012)]
end
```

#### is_timestep and is_time

*The Mimi Change:* 
For simplicity and consistency with the change above, Mimi no longer supports the `is_timestep` or `is_time` functions and has replaced this functionality with comparison operators combined with the afformentioned `TimestepValue` and `TimestepIndex` types.

*The User Change:* 
Any instance of the `is_timestep` function should be replaced with simple comparison with a `TimestepIndex` object ie. replace the logic `if is_timestep(t, 10) ...` with `if t == TimestepIndex(10) ...`.

Any instance of the `is_time` function should be repalced with simple comparison with a `TimestepValue` object ie. replace the logic `if is_time(t, 2010) ...` with `if t == TimestepValue(2010) ...`.

## The set_param! Function (TODO CORA)

*The Mimi Change:* 
- explain new function (now has five arguments)
- explain the shortcuts
- explain when it errors

*The User Change:* 

## The replace_comp! Function

*The Mimi Change:* 
For simplicity, the `replace_comp!` function has been replaced with a method augmenting the julia Base `replace!` function.

*The User Change:* 
Where you previously used
```julia
replace_comp!(m, new, old)
```
to replace the `old` component with `new`, they should now use
```julia
replace!(m, old => new)
```

## Different-length Components (TODO CORA)

*The Mimi Change:* 
 - either the functionality will be gone, or implemented differently

*The User Change:* 

## Marginal Models

*The Mimi Change:* 
For clarity, the previously named `marginal` attribute of a Mimi `MarginalModel` has been renamed to `modified`.  Hence a `MarginalModel` is now described as a Mimi `Model` whose results are obtained by subtracting results of one `base` Model from those of another `marginal` Model that has a difference of `delta` with the signature:

*The User Change:* 
Any previous access to the `marginal` attribute of a `MarginalModel`, `mm` below, should be changed from 
```julia
model = mm.marginal
```
to
```julia
model = mm.modified
```
## Simulation Syntax

#### Results Access

*The Mimi Change:* 
For clarity of return types, Mimi no longer supports use of square brackets (a shortcut for julia Base `getindex`) to access the results of a Monte Carlo analysis, which are stored in the `SimulationInstance`.  Instead, access to resulst is supported with the `getdataframe` function, which will return the results in the same type and format as the square bracket method used to return.

*The User Change:* 
Results previously obtained with 
```julia
results = si[:grosseconomy, :K]
```
should now be obtained with 
```julia
results = getdataframe(si, :grosseconomy, :K)
```
#### Simulation Definition Modification Functions

*The Mimi Change:* 
For consistency with julia syntax rules, the small set of unexported functions available to modify an existing `SimulationDefinition` have been renamed, moving from a camel case format to an underscore-based format as follows.

*The User Change:* 
Replace your functions as follows.

- `deleteRV!` --> `delete_RV!`
- `addRV!` --> `add_RV!`
- `replaceRV!` --> `replace_RV!`
- `deleteTransform!` --> `delete_transform!`
- `addTransform!` --> `add_transform!`
- `deleteSave!` --> `delete_save!`
- `addSave!` --> `add_save!`

## Composite Components (optional)

*The Mimi Change:* 
The biggest functionality **addition** of Mimi v1.0.0 is the inclusion of composite components.  Prior versions of Mimi supported only "flat" models, i.e., with one level of components. This new version supports mulitple layers of components, with some components being "final" or leaf components, and others being "composite" components which themselves contain other leaf or composite components. This approach allows for a cleaner organization of complex models, and allows the construction of building blocks that can be re-used in multiple models.

*The User Change:* 
All previous models are considered "flat" models, i.e. they have only one level of components, and do **not** need to be converted into multiple layer models to run. Thus this addition does not mean users need to alter their models, but we encourage you to check out the other documentation on composite components to learn how you can enhance your current models and built better onces in the future!
