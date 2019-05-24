using IterTools
import IteratorInterfaceExtensions
import TableTraits
using Random
using ProgressMeter
using Serialization

function print_nonempty(name, vector)
    if length(vector) > 0
        println("  $name:")
        for obj in vector
            println("    ", obj)
        end
    end
end

function Base.show(io::IO, sim::Simulation{T}) where T <: AbstractSimulationData
    println("Simulation{$T}")
    
    println("  trials: $(sim.trials)")
    println("  current_trial: $(sim.current_trial)")
    
    sim.current_trial > 0 && println("  current_data: $(sim.current_data)")
    
    println("  rvdict:")
    for (key, value) in sim.rvdict
        println("    $key: $(typeof(value))")
    end

    print_nonempty("translist", sim.translist)
    print_nonempty("savelist",  sim.savelist)
    println("  nt_type: $(sim.nt_type)")
    println("  $(length(sim.models)) models")
    println("  $(length(sim.results)) results dicts")

    Base.show(io, sim.data)  # note: data::T
end

function Base.show(obj::T) where T <: AbstractSimulationData
    nothing
end

# Store results for a single parameter
function _store_param_results(m::Model, datum_key::Tuple{Symbol, Symbol}, trialnum::Int, results::Dict{Tuple, DataFrame})
    @debug "\nStoring trial results for $datum_key"

    (comp_name, datum_name) = datum_key
    dims = dim_names(m, comp_name, datum_name)
            
    if length(dims) == 0        # scalar value
        value = m[comp_name, datum_name]
        # println("Scalar: $value")

        if haskey(results, datum_key)
            results_df = results[datum_key]
        else
            results_df = DataFrame([typeof(value), Int], [datum_name, :trialnum], 0)
            results[datum_key] = results_df
        end

        push!(results_df, [value, trialnum])
        # println("results_df: $results_df")

    else
        trial_df = getdataframe(m, comp_name, datum_name)
        trial_df[:trialnum] = trialnum
        # println("size of trial_df: $(size(trial_df))")

        if haskey(results, datum_key)
            results_df = results[datum_key]
            # println("Appending trial_df $(size(trial_df)) to results_df $(size(results_df))")
            append!(results_df, trial_df)
        else
            # println("Setting results[$datum_key] = trial_df $(size(trial_df))")
            results[datum_key] = trial_df
        end
    end
end

function _store_trial_results(sim::Simulation{T}, trialnum::Int) where T <: AbstractSimulationData
    savelist = sim.savelist

    for (m, results) in zip(sim.models, sim.results)
        for datum_key in savelist
            _store_param_results(m, datum_key, trialnum, results)
        end
    end
end

"""
    save_trial_results(sim::Simulation, output_dir::String)

Save the stored simulation results to files in the directory `output_dir`
"""
function save_trial_results(sim::Simulation{T}, output_dir::AbstractString) where T <: AbstractSimulationData
    multiple_results = (length(sim.results) > 1)

    mkpath(output_dir, mode=0o750)
    
    for (i, results) in enumerate(sim.results)
        if multiple_results
            sub_dir = joinpath(output_dir, "model_$i")
            mkpath(sub_dir, mode=0o750)
        else
            sub_dir = output_dir 
        end

        for datum_key in sim.savelist
            (comp_name, datum_name) = datum_key
            filename = joinpath(sub_dir, "$datum_name.csv")
            save(filename, results[datum_key])
        end
    end
end

function save_trial_inputs(sim::Simulation, filename::String)
    mkpath(dirname(filename), mode=0o750)   # ensure that the specified path exists
    save(filename, sim)
    return nothing
end

# TBD: Modify lhs() to return an array of SampleStore{T} instances?
"""
    get_trial(sim::Simulation, trialnum::Int)

Return a NamedTuple with the data for next trial. Note that the `trialnum`
parameter is used only to support a 1-deep data cache that allows this
function to be called successively with the same `trialnum` to retrieve
the same NamedTuple. If `trialnum` does not match the current trial number,
the argument is ignored.
"""
function get_trial(sim::Simulation, trialnum::Int)
    if sim.current_trial == trialnum
        return sim.current_data
    end

    vals = [rand(rv.dist) for rv in values(sim.rvdict)]
    sim.current_data = sim.nt_type((vals...,))
    sim.current_trial = trialnum
    
    return sim.current_data
end

"""
    generate_trials!(sim::Simulation{T}, samples::Int; filename::Union{String, Nothing}=nothing)

Generate trials for the given Simulation instance using the defined `samplesize.
Call this before running the sim to pre-generate data to be used by all scenarios. 
Also saves inputs if a filename is given.
"""
function generate_trials!(sim::Simulation{T}, samplesize::Int;
                        filename::Union{String, Nothing}=nothing) where T <: AbstractSimulationData
    sample!(sim, samplesize)

    # TBD: If user asks for trial data to be saved, generate it up-front, or 
    # open a file that can be written to for each trialnum/scenario set?
    if filename != nothing
        save_trial_inputs(sim, filename)
    end
end

function sample!(sim::MonteCarloSimulation, samplesize::Int)
    sim.trials = samplesize
    rand!(sim)
end

"""
    Random.rand!(sim::Simulation{T})

Replace all RVs originally of type Distribution with SampleStores with 
values drawn from that original distribution.
"""
function Random.rand!(sim::Simulation{T}) where T <: AbstractSimulationData
    rvdict = sim.rvdict
    trials = sim.trials

    for rv in values(sim.rvdict)
        # use underlying distribution, if known
        orig_dist = (rv.dist isa SampleStore ? rv.dist.dist : rv.dist)
        dist = (orig_dist === nothing ? rv.dist : orig_dist)
        values = rand(dist, trials)
        rvdict[rv.name] = RandomVariable(rv.name, SampleStore(values, orig_dist))
    end
end

"""
    _copy_sim_params(sim::Simulation{T})

Copy the parameters that are perturbed so we can restore them after each trial. This
is necessary when we are applying distributions by adding or multiplying original values.
"""
function _copy_sim_params(sim::Simulation{T}) where T <: AbstractSimulationData
    param_vec = Vector{Dict{Symbol, ModelParameter}}(undef, length(sim.models))

    for (i, m) in enumerate(sim.models)
        md = modelinstance_def(m)
        param_vec[i] = Dict{Symbol, ModelParameter}(trans.paramname => deepcopy(external_param(md, trans.paramname)) for trans in sim.translist)
    end

    return param_vec
end

function _restore_sim_params!(sim::Simulation{T}, 
                              param_vec::Vector{Dict{Symbol, ModelParameter}}) where T <: AbstractSimulationData
    for (m, params) in zip(sim.models, param_vec)
        md = m.mi.md
        for trans in sim.translist
            name = trans.paramname
            param = params[name]
            _restore_param!(param, name, md, trans)
        end
    end

    return nothing
end

function _restore_param!(param::ScalarModelParameter{T}, name::Symbol, md::ModelDef, trans::TransformSpec) where T
    md_param = external_param(md, name)
    md_param.value = param.value
end

function _restore_param!(param::ArrayModelParameter{T}, name::Symbol, md::ModelDef, trans::TransformSpec) where T
    md_param = external_param(md, name)
    indices = _param_indices(param, md, trans)
    md_param.values[indices...] = param.values[indices...]
end

function _param_indices(param::ArrayModelParameter{T}, md::ModelDef, trans::TransformSpec) where T
    pdims = dim_names(param)   # returns [] for scalar parameters
    num_pdims = length(pdims)

    tdims  = trans.dims
    num_dims = length(tdims) 

    # special case for handling reshaped data where a single draw returns a matrix of values
    if num_dims == 0
        indices = repeat([Colon()], num_pdims)
        return indices
    end

    if num_pdims != num_dims
        pname = trans.paramname
        error("Dimension mismatch: external parameter :$pname has $num_pdims dimensions ($pdims); Sim has $num_dims")
    end

    indices = Vector()
    for (dim_name, dim_values) in zip(pdims, tdims)
        dim = dimension(md, dim_name)
        push!(indices, dim[dim_values])
    end

    # println("indices: $indices")
    return indices
end

function _perturb_param!(param::ScalarModelParameter{T}, md::ModelDef, trans::TransformSpec, rvalue::Number) where T
    op = trans.op

    if op == :(=)
        param.value = T(rvalue)

    elseif op == :(*=)
        param.value *= rvalue

    else
        param.value += rvalue
    end
end

function _perturb_param!(param::ArrayModelParameter{T}, md::ModelDef, 
                         trans::TransformSpec, rvalue::Union{Number, Array{<: Number, N}}) where {T, N}
    op = trans.op
    pvalue = value(param)
    indices = _param_indices(param, md, trans)

    if op == :(=)
        pvalue[indices...] = rvalue

    elseif op == :(*=)
        pvalue[indices...] *= rvalue

    else
        pvalue[indices...] += rvalue
    end
end

"""
    _perturb_params!(sim::Simulation{T}, trialnum::Int)

Modify the stochastic parameters for all models in `sim`, using the 
values drawn for trial `trialnum`.
"""
function _perturb_params!(sim::Simulation{T}, trialnum::Int) where T <: AbstractSimulationData
    if trialnum > sim.trials
        error("Attempted to run trial $trialnum, but only $(sim.trials) trials are defined")
    end

    trialdata = get_trial(sim, trialnum)

    for m in sim.models
        md = m.mi.md
        for trans in sim.translist        
            param = external_param(md, trans.paramname)
            rvalue = getfield(trialdata, trans.rvname)
            _perturb_param!(param, md, trans, rvalue)
        end
    end
    return nothing
end

function _reset_rvs!(sim::Simulation{T}) where T <: AbstractSimulationData
    for rv in values(sim.rvdict)
        if rv.dist isa SampleStore
            reset(rv.dist)
        end
    end
end

"""
    _reset_results!(sim::Simulation{T})

Reset all simulation results storage to a vector of empty dicts
"""
function _reset_results!(sim::Simulation{T}) where T <: AbstractSimulationData
    sim.results = [Dict{Tuple, DataFrame}() for m in sim.models]
end

# Append a string representation of the tuple args to the given directory name
function _compute_output_dir(orig_output_dir, tup)
    output_dir = (orig_output_dir === nothing) ? nothing : joinpath(orig_output_dir, join(map(string, tup), "_"))
    mkpath(output_dir, mode=0o750)
    return output_dir
end

"""
    run_sim(sim::Simulation{T}; 
            trials::Union{Nothing, Int, Vector{Int}, AbstractRange{Int}}=nothing,
            models_to_run::Int=length(sim.models),
            ntimesteps::Int=typemax(Int), 
            output_dir::Union{Nothing, AbstractString}=nothing, 
            pre_trial_func::Union{Nothing, Function}=nothing, 
            post_trial_func::Union{Nothing, Function}=nothing,
            scenario_func::Union{Nothing, Function}=nothing,
            scenario_placement::ScenarioLoopPlacement=OUTER,
            scenario_args=nothing)

Optionally run the first indicated `trials`, which indicates the number of trials to run
starting from the first one. The first `models_to_run` associated models are run 
for `ntimesteps`, if specified, else to the maximum defined time period. Note that trial
data are applied to all the associated models even when running only a portion of them.   
    
If `pre_trial_func` or `post_trial_func` are defined, the designated functions are called 
just before or after (respectively) running a trial. The functions must have the signature:

    fn(sim::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the simulation loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

If provided, `scenario_args` must be a `Vector{Pair}`, where each `Pair` is a symbol and a 
`Vector` of arbitrary values that will be meaningful to `scenario_func`, which must have
the signature:

    scenario_func(sim::Simulation, tup::Tuple)

By default, the scenario loop encloses the simulation loop, but the scenario loop can be
placed inside the simulation loop by specifying `scenario_placement=INNER`. When `INNER` 
is specified, the `scenario_func` is called after any `pre_trial_func` but before the model
is run.
"""
function run_sim(sim::Simulation{T}; 
                 trials::Union{Nothing, Int, Vector{Int}, AbstractRange{Int}}=nothing,
                 models_to_run::Int=length(sim.models),     # run all models by default
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing) where T <: AbstractSimulationData

    if (scenario_func === nothing) != (scenario_args === nothing)
        error("run_sim: scenario_func and scenario_arg must both be nothing or both set to non-nothing values")
    end

    for m in sim.models
        if ! is_built(m)
            build(m)
        end
    end
    
    # TBD: address confusion over whether trials is a list of trialnums or just the number of trials

    # Machinery to handle trials cases
    if trials === nothing
        # If trials is not set, assume it is 1:sim.trials.  
        trials = 1:sim.trials
    else

        # Handle Int
        if typeof(trials) <: Int
            trials = 1:trials
        end

        # If the user input a trials arg, we must reset sim.trials to length(trials),
        # otherwise sim.trials is already set from generate_trials
        sim.trials = length(trials)
    end

    # Save the original dir since we modify the output_dir to store scenario results
    orig_output_dir = output_dir

    # booleans vars to simplify the repeated tests in the loop below
    has_output_dir     = (orig_output_dir !== nothing)
    has_scenario_func  = (scenario_func !== nothing)
    has_outer_scenario = (has_scenario_func && scenario_placement == OUTER)
    has_inner_scenario = (has_scenario_func && scenario_placement == INNER)

    if has_scenario_func
        scen_names  = [arg.first  for arg in scenario_args]
        scen_values = [arg.second for arg in scenario_args]

        # precompute all combinations of scenario arguments so we can run
        # a single loop regardless of the number of scenario arguments.
        arg_tuples = Iterators.product(scen_values...)

        if has_outer_scenario
            arg_tuples_outer = arg_tuples
            arg_tuples_inner = (nothing,)   # allows one iteration when no scenario loop specified
        else
            arg_tuples_outer = (nothing,)   # as above
            arg_tuples_inner = arg_tuples
        end
    else
        arg_tuples = arg_tuples_outer = arg_tuples_inner = (nothing,)
    end
    
    # Set up progress bar
    nscenarios = length(arg_tuples)
    ntrials = length(trials)
    total_runs = nscenarios * ntrials
    counter = 1
    p = Progress(total_runs, counter, "Running $ntrials trials for $nscenarios scenarios...")

    for outer_tup in arg_tuples_outer
        if has_outer_scenario
            @debug "Calling outer scenario_func with $outer_tup"
            scenario_func(sim, outer_tup)

            # we'll store the results of each in a subdir composed of tuple values
            output_dir = _compute_output_dir(orig_output_dir, outer_tup)
        end
                
        # Save the params to be perturbed so we can reset them after each trial
        original_values = _copy_sim_params(sim)        
        
        # Reset internal index to 1 for all stored parameters to reuse the data
        _reset_rvs!(sim)

        for (i, trialnum) in enumerate(trials)
            @debug "Running trial $trialnum"

            for inner_tup in arg_tuples_inner
                tup = has_inner_scenario ? inner_tup : outer_tup

                _perturb_params!(sim, trialnum)

                if pre_trial_func !== nothing
                    @debug "Calling pre_trial_func($trialnum, $tup)"
                    pre_trial_func(sim, trialnum, ntimesteps, tup)
                end               

                if has_inner_scenario
                    @debug "Calling inner scenario_func with $inner_tup"
                    scenario_func(sim, inner_tup)

                    output_dir = _compute_output_dir(orig_output_dir, inner_tup)
                end

                for m in sim.models[1:models_to_run]    # note that list of models may be changed in scenario_func
                    @debug "Running model"
                    run(m, ntimesteps=ntimesteps)
                end
                
                if post_trial_func !== nothing
                    @debug "Calling post_trial_func($trialnum, $tup)"
                    post_trial_func(sim, trialnum, ntimesteps, tup)
                end

                _store_trial_results(sim, trialnum)
                _restore_sim_params!(sim, original_values)

                counter += 1
                ProgressMeter.update!(p, counter)                
            end

            if has_inner_scenario && has_output_dir
                save_trial_results(sim, output_dir)
                _reset_results!(sim)
            end
        end

        if ! has_inner_scenario && has_output_dir
            save_trial_results(sim, output_dir)
            _reset_results!(sim)
        end
    end
end

# Set models
""" 
	    set_models!(sim::Simulation{T}, models::Vector{Model})
	
	Set the `models` to be used by the `sim` Simulation. 
"""
function set_models!(sim::Simulation{T}, models::Vector{Model}) where T <: AbstractSimulationData
    sim.models = models
    _reset_results!(sim)    # sets results vector to same length
end

# Convenience methods for single model and MarginalModel
""" 
set_models!(sim::Simulation{T}, m::Model)
	
    Set the model `m` to be used by the `sim` Simulation.
"""
set_models!(sim::Simulation{T}, m::Model)  where T <: AbstractSimulationData = set_models!(sim, [m])

""" 
set_models!(sim::Simulation{T}, mm::MarginalModel)

    Set the models to be used by the `sim` Simulation to be `mm.base` and `mm.marginal`
	which make up the MarginalModel `mm`. 
"""
set_models!(sim::Simulation{T}, mm::MarginalModel) where T <: AbstractSimulationData = set_models!(sim, [mm.base, mm.marginal])

#
# Iterator functions for Simulation directly, and for use as an IterableTable.
#
function Base.iterate(sim::Simulation{T}) where T <: AbstractSimulationData
    _reset_rvs!(sim)
    trialnum = 1
    return get_trial(sim, trialnum), trialnum + 1
end

function Base.iterate(sim::Simulation{T}, trialnum) where T <: AbstractSimulationData
    if trialnum > sim.trials
        return nothing
    else
        return get_trial(sim, trialnum), trialnum + 1
    end
end

IteratorInterfaceExtensions.isiterable(sim::Simulation{T}) where T <: AbstractSimulationData = true
TableTraits.isiterabletable(sim::Simulation{T}) where T <: AbstractSimulationData = true

IteratorInterfaceExtensions.getiterator(sim::Simulation) = SimIterator{sim.nt_type}(sim)

column_names(sim::Simulation{T}) where T <: AbstractSimulationData = fieldnames(sim.nt_type)
column_types(sim::Simulation{T}) where T <: AbstractSimulationData = [eltype(fld) for fld in values(sim.rvdict)]

#
# Iteration support (which in turn supports the "save" method)
#
column_names(iter::SimIterator) = column_names(iter.sim)
column_types(iter::SimIterator) = error("Not implemented") # Used to be `IterableTables.column_types(iter.sim)`

function Base.iterate(iter::SimIterator)
    _reset_rvs!(iter.sim)
    idx = 1
    return get_trial(iter.sim, idx), idx + 1
end

function Base.iterate(iter::SimIterator, idx)
    if idx > iter.sim.trials
        return nothing
    else
        return get_trial(iter.sim, idx), idx + 1
    end
end

Base.length(iter::SimIterator) = iter.sim.trials

Base.eltype(::Type{SimIterator{NT, T}}) where {NT, T} = NT