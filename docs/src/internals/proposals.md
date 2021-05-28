# Not Implemented (Yet)

This section describes proposed API and file formats that haven't been developed yet.

## ModelRunner


There are several types of analyses that require an ensemble of model runs performed over a set of parameter values. These include traditional Monte Carlo simulation, in which random values are drawn from distributions and applied to model parameters, as well as global sensitivity analyses that use prescribed methods for defining trial data (e.g., Sobol sampling), and Markov Chain Monte Carlo, which computes new trial data based on prior model results.

The abstract type `ModelRunner` will be used to define a generic API for model runners, including support for parallelization of analyses on multiprocessors and cluster computing systems. The specific sampling and analysis methods required for each subtype of `ModelRunner` will be defined in the concrete subtype, e.g., `SimulationRunner`.

The generic process will look something like this:

```julia
m = ModelDef(...)
r = SimRunner(m)

# Optionally redefine random variables, overriding defaults
setrv!(r, :rvname1, Normal(10, 3))

# Optionally assign an alternative RV or distribution to a model parameter
setparam!(r, :comp1, :param1, :rvname1)
setparam!(r, :comp1, :param2, Uniform(0, 3))

# Adjust what should be saved per model run
@add_results(r, param10, param11[US])
@drop_results(r, param1, param1)

# Run trials 1-5000. Also can specify as a range (e.g., 5001:10000) 
# or vector of trial numbers.
run!(r, 5000)

# Save results to the indicated directory
write(r, dirname)
```

#### Saving ensemble results

Ensemble results will be stored in an object of type `EnsembleResult`, which is used by all subtypes of `ModelRunner`. By default, only model outputs tagged for output will be saved in the `EnsembleResult` instance. Parameters can be identified as "output" parameters in `@defsim`, and/or directly in a concrete subtype of `ModelRunner`, in which case default values set in `@defsim` can be overridden.

The method `write(r::ModelRunner, dirname::String)` will save model results to set of CSV files in the named directory. Initially, we will store the data in [tidy](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html) format in which variables are in columns and each row represents an observation. This format is verbose but flexible and commonly used by consumers of data such as plotting packages. Other formats can be generated if the need arises.

In the initial implementation, results will be saved as follows:

* Scalar model results will be written to `"$dirname/scalars.csv"`. The file will have a column holding the trial number, and one column labeled with each parameter name. Each row in the file will contain all scalar parameter values data for a single  model run. 
  * Example:

    | trialnum | foo | bar | baz | ... |
    | -------- | --- | --- | --- | --- |
    | 1        | 1.6 | 0.4 | 110 | ... |

  * Alternatively, we could flatten to 3 columns: 

    | trialnum | paramname | value |
    | -------- | --------- | ----- |
    | 1        | foo       | 1.6   |
    | 1        | bar       | 0.4   |
    | 1        | baz       | 110   |

* All model results with a single time dimension will be written to `"$dirname/timeseries.csv"`, with columns:

  | trialnum | year | foo   | bar  | baz  | ... |
  | -------- | ---- | ----- | ---- | ---- | --- |
  | 1        | 2010 | 100.6 | 41.6 | 9.1  | ... |
  | 1        | 2015 | 101.7 | 44.5 | 10.2 | ... |
  | 1        | 2020 | 102.8 | 50.1 | 12.4 | ... |
  | ...      | ...  | ...   | ...  | ...  | ... |
  | 2        | 2010 | 101.6 | 43.7 | 10.4 | ... |
  | 2        | 2015 | 102.4 | 60.1 | 21.3 | ... |
  | 2        | 2020 | 105.7 | 55.3 | 14.2 | ... |
  | ...      | ...  | ...   | ...  | ...  | ... |

  * As with scalar results, this might be flattened further to:

    | trialnum | paramname | year | value |
    | -------- | --------- | ---- | ----- |
    | 1        | foo       | 2010 | 100.6 |
    | 1        | foo       | 2015 | 101.7 |
    | 1        | foo       | 2020 | 102.8 |
    | ...      | ...       | ...  | ...   |
    | 2        | foo       | 2010 | 101.6 |
    | 2        | foo       | 2015 | 102.4 |
    | 2        | foo       | 2020 | 105.7 |
    | ...      | ...       | ...  | ...   |

  * Another alternative would be to store each timeseries result to its own CSV file, in which case the second (flattened) format would be used, minus the "paramname" column, which would be implicit from the filename. This would be more consistent with the matrix format below, since a timeseries result is just a matrix result with only one dimension.

* Matrix results will be saved to individual files named `"$dirname/$paramname.csv"`. Matrices will be flattened so that each dimension appears as a column. For example, a matrix with dimensions "time" and "region" will have columns "trialnum", 

  | trialnum | region | year | value |
  | -------- | ------ | ---- | ----- |
  | 1 | US | 2010 | 1.1 |
  | 1 | US | 2015 | 1.9 |
  | ...|
  | 1 | CHI | 2010 | 0.2 |
  | 1 | CHI | 2015 | 0.8 |
  | ...|
  
* Another option for saving ensemble outputs might include writing to any "sink" type that accepts named tuples.


## Model result file format

To facilitate post-processing, model results will be saved to files in either JSON formats, as detailed below. To save results, the following methods can be used.

For individual model runs, results can be saved to a single file, or added to an existing file. For SA simulations, a single JSON file will hold the subset 
of results specified by the user, for each trial. This may become
unwieldy, but we support gzipped JSON, which helps a bit: if a filename ends in 
`.gz`, it will automatically be zipped on writing and gzipped on reading.

```julia
saveresults(m::Model, pathname::String)

saveresults(m::Model, pathname::String, append=true)

saveresults(sim:Simulation, pathname::String)
```

#### JSON file format

The JSON file format is basically a set of nested dictionaries, with a few lists at the innermost levels. We assign names to these levels for clarity of exposition in this documentation, but these names do not exist in the actual files.

We specify `dicttype=DataStructures.OrderedDict` when reading and writing JSON files to ensure that insertion order is maintained.

#### Scenario dict
The top level of the JSON file is a dictionary keyed by scenario name (for non-SA results) or trial number (basically a numeric scenario name) for SA results.

#### Index-Variable-Parameter (IVP) dict
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

Parameter dicts are keyed by model parameter names (symbols), with values represented in the same format as shown above for Variable dicts.


