# Cross-model Connectors 

## Thoughts on matching indices across models that may have different timesteps, regional aggregations, etc.

The basic idea is to allow a keyword arg to connect_param!() to identify a connector 
component that performs the mapping between disparate dimension definitions.

We could provide a couple more "standard" connectors
* Time
    * Get most recent value from before the receiving model's current timestep
    * Get the sum of values between the receiving model's current and prior timestep
* Regions
    * Pass in a region map that defines transformations between two regional definitions
    * Operators can include
        * Weighted Avg:  new region value = avg(parameter[regions] .* weight[regions])
        * Weighted sum: new region value = sum(parameter[regions] .* weight[regions])
    * Weights can be the value of some parameter, e.g., population, area, GDP
    * Disaggregation can be handled similarly
        * new sub-region value = parameter[region] * weight[region]

We can create macro to define connector components that perform these dimension adjustments.
We would define a new macro that simplifies creation of a `@defcomp` of a given name 
that can be specified in connect_param! to perform the defined mapping.

To map across both time and regions, we could implement a pair of connector components
that might look like the following, which would be called for each timestep `t` in 
the receiving component:

```julia
# This component would run first, mapping emissions to the new time boundaries
@defcomp time_mapper begin
    src = Variable(index=[m1.time, m1.regions])
    dst = Parameter(index=[m2.time, m1.regions])   # uses src model's regions

    # Simple time adapter that just sums any values produced since the prior 
    # timestep, without performing any allocation or interpolation.
    function run_timestep(p, v, d, t)
        for r in d.regions
            values = [v.src[tsrc, r] for tsrc in m1.time if t - 1 < tsrc <= t]
            p.dst[t, r] = sum(values)
        end
    end
end

# This component would run next, mapping emissions to the new regional boundaries
@defcomp region_mapper begin
    # Source here would be the emissions_time_mapper component
    src  = Variable(index=[time, m1.regions])
    sgdp = Variable(index=[time, m1.regions])
    dst  = Parameter(index=[time, m2.regions])
    dgdp = Parameter(index=[time, m2.regions])

    function run_timestep(p, v, d, t)
        # Aggregate to region :OthNAmer by summing values of src over :Mex and :Can
        p.dst[t, :OthNAmer] = sum(v.src[t, [:Mex, :Can]])

        # Disaggregate :SAmer into :Bra and :OthSAmer by fraction of GDP
        p.dst[:Bra, t]      = v.src[t, :SAmer] * p.dgdp[t, :Bra]      / v.sgdp[t, :SAmer]
        p.dst[:OthSAmer, t] = v.src[t, :SAmer] * p.dgdp[t, :OthSAmer] / v.sgdp[t, :SAmer]
    end
end
```

Notes:

1. Specifying index values by symbol as we do currently is inadequate when these can 
   refer to different models. Probably need to support module specification, e.g., 
   `dice2010.time`.

1. When combining components with different time dimensions, we should run the
   model on the union of all time dimension definitions. For
   example, if model 1 is defined on 10-yr timesteps (2010, 2020, ...) and
   model 2 is defined on 4-yr timesteps (2010, 2014, 2018, ...), the combined
   time dimension for the models would be (2010, 2014, 2018, 2020, 2022, ... ).

   The main `run_timestep` would iterate over the combined time dimension, calling
   each component's `run_timestep` only for timesteps defined for that component.

1. If  `src` has 5-yr timesteps and `dst` has 10-yr timesteps, emissions in dst 
   time `tdst` would sum emissions from src time `tsrc` and `tsrc - 1`. 
   More generally, accumulating into `dst` in timestep `tdst` would sum values from
   `src` timesteps `tsrc` where  `tdst - 1 < tsrc <= tdst`. For dependencies on the 
   prior timestep, it would sum values where `dst[t-2] < tsrc <= dst[t-1]`.
   
1. Regional alignment may be combined with timestep alignment. In this case, time
   should be aligned first, since components are run on time boundaries. Then
   regional alignment can be handled based on time-aligned values.

1. In some cases, we will want to allocate values from a source model across multiple
   timesteps in the destination model. For example, if model `src` is defined on 10-yr
   timesteps (2010, 2020, 2030, ...) and model `dst` is defined on 5-yr timesteps,
   (2010, 2015, 2020, 2025, ...) we might allocate half of the 2010-2010 
   value from `src` in 2010-2020 to each of the `dst` periods 2010-2015 and 2015-2020.
   This allocation would be appropriate for flow parameters such as emissions. For stock 
   parameters, e.g., CO<sub>2</sub> concentration, we would want to interpolate between `src`
   timestep values.

   * This suggests a need for metadata on parameters indicating whether they are
     of the stock or flow variety.

   * The problem with this is that is requires knowing a future value to allocate or
     interpolate between a past value before the `dst` model's timestep `t`, and
     the subsequent value in occurring after `t`. This would require running the
     `dst` model one or more timesteps lagged.
