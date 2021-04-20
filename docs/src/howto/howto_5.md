# How-to Guide 5: Update the Time Dimension

A runnable model necessarily has a `time` dimension, originally set with the following call, but in some cases it may be desireable to alter this dimension by calling the following on a model which already has a time dimension set.
```
set_dimension!(m, :time, time_keys)
```
#### As a concrete example, one may wish to replace the FUND model's climate module with a different one, say FAIR, and make new conections between the two:

We will soon publish a notebook explaining all the steps for this coupling, but for now we focus on this as an example of resetting the time dimension.  The default FUND runs from 1950 to 3000 with 1 year timesteps, and FAIR runs from 1765 to 2500 with 1 year timesteps. Thus, our new model will run from 1765 to 2500 with 1 year timesteps, with FAIR running the whole time (acessing backup parameter values when FUND is not running) and then with FUND  kicking in in 1950 and running to 2500, connected appropriately to FAIR. 

We start with FUND
```
using Mimi
using MimiFUND
m = MimiFUND.get_model()
```
where `MimiFUND.get_model` includes the call `set_dimension!(m, time, 1950:3000)`.

#### Now we want to change the `time` dimension to be 1765 to 3000:

Before we do so, note some important rules and precautions. These are in place to avoid unexpected behavior, complications, or incorrect results caused by our under-the-hood assumptions, but if a use case arises where they are a problem please get in touch on the [forum](https://forum.mimiframework.org) and we can help you out.

- The new time dimension cannot start later than the original time dimension.  
- The new time dimension cannot end before the start of the original time dimension ie. it cannot completely exclude all times in the original time dimension
- The new time dimension must use the same timestep lengths as the original dimension.

It is possible that an existing model has special behavior that is explicitly tied to a year value.  If that is true, the user will need to account for that.

#### We now go ahead and change the `time` dimension to be 1765 to 2500: 
```
set_dimension!(m, :time, 1765:2500)
```
At this point the model `m` can be run, and will run from 1765 to 2500. That said, the components will only run in the subset of years 1950 to 2500.  All associated external parameters with a `time` dimension have been padded with `missing` values from 1765 to 1949, so that the values previously associated with 1950 to 2500 are still associated with those years.  To add a bit of detail, after the time dimension is reset the following holds:

- The model's `time` dimension values are updated, and it will run for each year in that dimension.
    ```
    julia> Mimi.time_labels(m)
    736-element Vector{Int64}: [1765, 1766, 1767,  …  2498, 2499, 2500]
    ```
- The components `time` dimension values are updated, but (1) the components maintain the `first` year as set by the original `time` dimension so the run period start year does not change and (2) they maintain their `last` year as set by the original `time` dimension, unless that year is now later than the model's last year, in which case it is trimmed back to the `time` dimensions last year.  Thus, the components will run for the same run period, or a shorter one if the new time dimension ends before the component used to.
    ```
    julia> component = m.md.namespace[:emissions] # get component def, ignore the messy syntax
    julia> component.first
    1950
    julia> component.last
    2500
    julia> component.dim_dict[:time]
    [1765, 1766, 1767,  …  2498, 2499, 2500]
    ```
- All external parameters are trimmed and padded as needed so the model can still run, **and the values are still linked to their original years**.  More specifically, if the new time dimension ends earlier than the original one than the parameter values are trimmed back.  If the new time dimension starts earlier than the original, or ends later, the parameter values are padded with `missing`s at the front and/or back.
    ```
    julia> parameter_values = Mimi.external_params(m)[:currtaxn2o].values.data
    julia> size(parameter_values)
    (736, 16)
    julia> parameter_values[1:(1950-1765),:] # all missing
    julia> parameter_values[(1950-1764),:] # hold set values
    ```
#### The following options are now available for further modifcations if this end state is not desireable:

- If you want to update a component's run period, you may use the (nonexported) function `Mimi.set_first_last!(m, :ComponentName, first = new_first, last = new_last)` to specific when you want the component to run.
- You can update external parameters to, for example, have values in place of the assumed `missing`s using the `update_param!(m, :ParameterName, values)` function 
