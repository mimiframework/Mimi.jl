# How-to Guide 5: Work with Dimensions

## Updating the Time Dimension

This section provides some specific details on updating an already set `time` dimension of a model. 

A runnable model necessarily has a `time` dimension, originally set with the following call, but in some cases it may be desireable to alter this dimension.
```
set_dimension!(m, :time, time_keys)
```
As a concrete example, one may wish to replace the FUND model's climate module with a different one, say FAIR, and make new conections between the two.  We will soon publish a notebook explaining all the steps for this coupling, but for now we focus on this as an example of resetting the time dimension.  The default FUND runs from 1950 to 3000 with 1 year timesteps, and FAIR runs from 1765 to 2500 with 1 year timesteps. Thus, our new model will run from 1765 to 2500 with 1 year timesteps, with FAIR running the whole time (acessing backup parameter values when FUND is not running) and then with FUND  kicking in in 1950 and running to 2500, connected appropriately to FAIR. 

We start with FUND
```
using Mimi
using MimiFUND
m = MimiFUND.get_model()
```
where `MimiFUND.get_model` includes the call `set_dimension!(m, time, 1950:3000)`.

Now we want to change the `time` dimension to be 1765 to 3000. Before we do so, note some important rules and precautions. These are in place to avoid unexpected behavior, complications, or incorrect results caused by our under-the-hood assumptions, but if a use case arises where they are a problem please get in touch on the [forum](https://forum.mimiframework.org) and we can help you out.

- The new time dimension cannot start later than the original time dimension.  
- The new time dimension cannot end before the start of the original time dimension ie. it cannot completely exclude all times in the original time dimension
- The new time dimension must use the same timestep lengths as the original dimension.

It is possible that an existing model has special behavior that is explicitly tied to a year value.  If that is true, the user will need to account for that.

We now go ahead and change the `time` dimension to be 1765 to 2500. 
```
set_dimension!(m, :time, 1765:2500)
```
At this point the model `m` can be run, and will run from 1765 to 2500. That said, the components will only run in the subset of years 1950 to 2500.  All associated external parameters with a `:time` dimension have been padded with `missing` values from 1765 to 1949, so that the value previously associated with 1950 is still associated with that year.  To add a bit of detail, after the time dimension is reset the following are true:

- The model's `time` dimension values are updated, and it will run for each year in that dimension.
- The components in the model maintain the `first` and `last` years they held before the `time` dimension was reset, and will maintain that run period.
- All external parameters are trimmed and padded as needed so the model can still run, **but the values are still linked to their original years**.  More specifically, if the new time dimension ends earlier than the original one then the `last` is trimmed back.  If the new time dimension starts earlier than the original, or ends later, the parameter values are padded with `missing`s at the front and/or back.

In most cases, the above will create the expected, correct behavior, however the following options are available for further modifcations:

- If you want to update a component's run period, you may use the (nonexported) function `Mimi.set_first_last!(m, :ComponentName, first = new_first, last = new_last)` to specific when you want the component to run.
- You can update external parameters to, for example, have values in place of the assumed `missing`s using the `update_param!(m, :ParameterName, values)` function 
