# Model result file format

To facilitate post-processing, model results will be saved to files in either JSON formats, as detailed below. To save results, the following methods can be used.

For individual model runs, results can be saved to a single file, or added to an existing file. For Monte Carlo simulations, a single JSON file will hold the subset 
of results specified by the user, for each trial. This may become
unwieldy, but we support gzipped JSON, which helps a bit: if a filename ends in 
`.gz`, it will automatically be zipped on writing and gzipped on reading.

```julia
saveresults(m::Model, pathname::String)

saveresults(m::Model, pathname::String, append=true)

saveresults(mcs:MonteCarloSimulation, pathname::String)
```

## JSON file format

The JSON file format is basically a set of nested dictionaries, with a few lists at the innermost levels. We assign names to these levels for clarity of exposition in this documentation, but these names do not exist in the actual files.

We specify `dicttype=DataStructures.OrderedDict` when reading and writing JSON files to ensure that insertion order is maintained.

### Scenario dict
The top level of the JSON file is a dictionary keyed by scenario name (for non-MCS results) or trial number (basically a numeric scenario name) for MCS results.

### Index-Variable-Parameter (IVP) dict
The value of the top-level dictionary is a dictionary whose keys are types of model inputs and results, which is currently one of `"Index"`, `"Variable"`, or `"Parameter"` of these dictionaries vary by the type of object stored, as shown below.

#### Index dict

An index dict is keyed by index name (e.g., `"time"`, `"region"`) with values being lists of index values. For example the `"time"` index might look like this:

  `"time" : [2010, 2011, 2012, 2013, ..., 2099, 2100]`
  
These are converted to `Index` objects upon reading.

#### Variable dict

Variable dicts are keyed by a string of the form `"$component_name:$variable_name"` (tuple keys are not supported in JSON). Values are single numerical values for scalar parameters, or for vector and matrix values, a list of lists of the form `[[dimensions...], [values...]]` where `dimensions`. Examples:

```julia
{
 # Scalar
 "foo" : 42,

 # one dimension
 "bar" : [["region"], [4.1, 7.2, 3.6, 9.4, 5.5, 7.6, ...],

 # two dimensions are stored as arrays of arrays
 "baz" : [
   ["time", "region"], 
   [[4.1, 7.2, 3.6, ...], # values by region for first timestep
    [3.5, 6.3, 5.6, ...], # values by region for 2nd timestep
    ...]
  ]
}
```
  
#### Parameter dict

Parameter dicts are keyed by "external" names (symbols), with values represented in the same format as shown above for Variable dicts.


