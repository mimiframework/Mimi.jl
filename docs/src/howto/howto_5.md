# How-to Guide 5: Update the Time Dimension

A runnable model necessarily has a `time` dimension, originally set with the following call, but in some cases it may be desireable to alter this dimension by calling the following on a model which already has a time dimension set.
```
set_dimension!(m, :time, time_keys)
```

----
#### For example, one may wish to replace the FUND model's climate module with a different one, such as FAIR:

For the purposes of this guide we focus on the first step of such modification. Since FUND runs yearly from 1950 to 3000 and FAIR yearly from 1765 to 2500, our modified model will need to run yearly from 1765 to 1950.

We start with FUND
```
using Mimi
using MimiFUND
m = MimiFUND.get_model()
```
where `MimiFUND.get_model` includes the call `set_dimension!(m, time, 1950:3000)`.

----
#### Now we need to change the `time` dimension to be 1765 to 2500:

Before we do so, note some important rules and precautions. These are in place to avoid unexpected behavior, complications, or incorrect results caused by our under-the-hood assumptions, but if a use case arises where these are prohibitive please get in touch on the [forum](https://forum.mimiframework.org) and we can help you out.

- The new time dimension cannot start later than the original time dimension.  
- The new time dimension cannot end before the start of the original time dimension ie. it cannot completely exclude all times in the original time dimension.
- The new time dimension must use the same timestep lengths as the original dimension.

----
#### We now go ahead and change the `time` dimension to be 1765 to 2500: 
```
set_dimension!(m, :time, 1765:2500)
```
At this point the model `m` can be run, and will run from 1765 to 2500 (Try running it and looking at `explore(m)` for parameters and variables with a `time` dimension!). In fact, we could start adding FAIR components to the model, which would automatically take on the entire model time dimension, ie.
```
add_comp!(m, FAIR_component) # will run from 1765 to 1950
```
**However**, the FUND components will only run in the subset of years 1950 to 2500, using the same parameter values each year was previously associated with, and containing placeholder `missing` values in the parameter value spots from 1765 to 1949. More specifically:

- The model's `time` dimension values are updated, and it will run for each year in the new 1765:1950 dimension.
    ```
    julia> Mimi.time_labels(m)
    736-element Vector{Int64}: [1765, 1766, 1767,  …  2498, 2499, 2500]
    ```
- The components `time` dimension values are updated, but (1) the components maintain the `first` year as set implicitly by the original `time` dimension (1950) so the run period start year does not change and (2) they maintain their `last` year as set implicitly by the original `time` dimension, unless that year is now later than the model's last year, in which case it is trimmed back to the `time` dimensions last year (2500).  Thus, the components will run for the same run period, or a shorter one if the new time dimension ends before the component used to (in this case 1950:2500).
    ```
    julia> component = m.md.namespace[:emissions] # get component def(ignore messy internals syntax)
    julia> component.dim_dict[:time]
    [1765, 1766, 1767,  …  2498, 2499, 2500]
    julia> component.first
    1950
    julia> component.last
    2500
    ```
- All external parameters are trimmed and padded as needed so the model can still run, **and the values are still linked to their original years**.  More specifically, if the new time dimension ends earlier than the original one than the parameter value vector/matrix is trimmed at the end.  If the new time dimension starts earlier than the original, or ends later, the parameter values are padded with `missing`s at the front and/or back respectively.
    ```
    julia> parameter_values = Mimi.external_params(m)[:currtaxn2o].values.data # get param values for use in next run (ignore messy internals syntax)
    julia> size(parameter_values)
    (736, 16)
    julia> parameter_values[1:(1950-1765),:] # all missing
    julia> parameter_values[(1950-1764),:] # hold set values
    ```
    
----
#### The following options are now available for further modifcations if this end state is not desireable:

- If you want to update a component's run period, you may use the function `Mimi.set_first_last!(m, :ComponentName, first = new_first, last = new_last)` to specify when you want the component to run.
- You can update external parameters to have values in place of the assumed `missing`s using the `update_param!(m, :ParameterName, values)` function 
