# How-to Guide 5: Work with Dimensions

## Updating the Time Dimension

This section provides some specific details on updating an already set `time` dimension of a model. 

A runnable model necessarily has a `time` dimension, originally set with the following call, but in some cases it may be desireable to alter this dimension.
```
set_dimension!(m, :time, time_keys)
```
As a concrete example, one may wish to replace the FUND model's climate module with a different one, say FAIR, and make new conections between the two.  Since the default FUND runs from 1950 to 3000 with 1 year timesteps, and FAIR runs from 1765 to 2500 with 1 year timesteps, our new model will run from 1765 to 2500 with 1 year timesteps, with FAIR running the whole time and FUND only kicking in in 1950 and running to 2500. 

We start with FUND
```
using Mimi
using MimiFUND
m = MimiFUND.get_model()
```
where `MimiFUND.get_model` includes the call `set_dimension!(m, time, 1950:3000)`.

Now we want to change the `time` dimension to be 1765:3000. Before we do so, note some important rules and precautions. These are in place to avoid unexpected behavior, complications, or incorrect resuts caused by our under-the-hood assumptions:

- The new time dimension start later than the original time dimension.  The complexities and importance of initialization values and steps make it impossible to safely updating the time dimension in this way.
- The new time dimension cannot end before the start of the original time dimension ie. it cannot completely exclude all times in the original time dimension
- The timesteps must match.
- It is possible that an existing model has special behavior that is explicitly tied to a year value.  If that is true, the user will need to account for that.

We now go ahead and change the `time` dimension to be 1765:2500. 
```
set_dimension!(m, :tmie, 1765:2500)
```
At this point the model `m` can be run, and will run from it's `first` year of 1765 to it's `last` year of 2500. That said, the components are all associated with FUND, which started in 1950 and ended in 3000, so they will only run in the subset of years 1950 to 2500.  These components have a `first` of 1950 and a `last` of 2500, and all associated external parameters have been padded with `missing` values from 1765 to 1949, so that the value previously associated with 1950 **is still associated with that year**.  To summarize, after the time dimension is reset 

- The model's `time` dimension labels are updated, as is the `first` and `last` run years for the model.
- The component's in the model maintain the `first` and `last` years they held before the `time` dimension is reset, and will still run in those years.
- All external parameters are trimmed if the new time dimension ends earlier than the original one, and padded with `missing`s at the front if the new time dimension starts earlier than the original, and at the end if the new time dimension ends later than the original.

In most cases, the above will create the expected, correct behavior, however the following options are available for further modifcations:

- If you want to update a component's run period, you may use the (nonexported) function `Mimi.set_first_last!(m, :ComponentName, first = new_first, last = new_last)` to specific when you want the component to run.
- You can update external parameters to, for example, have values in place of the assumed `missing`s using the `update_param!(m, :ParameterName, values)` function 
