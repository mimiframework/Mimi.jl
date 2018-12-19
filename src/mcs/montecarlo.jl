using IterTools
using IterableTables
using TableTraits
using Random
using ProgressMeter

function Base.show(io::IO, mcs::MonteCarloSimulation)
    println("MonteCarloSimulation")
    
    println("  trials: $(mcs.trials)")
    println("  current_trial: $(mcs.current_trial)")
    
    mcs.current_trial > 0 && println("  current_data: $(mcs.current_data)")
    
    println("  rvdict:")
    for (key, value) in mcs.rvdict
        println("    $key: $(typeof(value))")
    end

    function print_nonempty(name, vector)
        if length(vector) > 0
            println("  $name:")
            for obj in vector
                println("    ", obj)
            end
        end
    end

    print_nonempty("translist", mcs.translist)
    print_nonempty("corrlist",  mcs.corrlist)
    print_nonempty("savelist",  mcs.savelist)

    println("  nt_type: $(mcs.nt_type)")
    println("  $(length(mcs.models)) models")
    println("  $(length(mcs.results)) results dicts")
end

# Store results for a single parameter
function _store_param_results(m::Model, datum_key::Tuple{Symbol, Symbol}, trialnum::Int, results::Dict{Tuple, DataFrame})
    @debug "\nStoring trial results for $datum_key"

    (comp_name, datum_name) = datum_key
    dims = dimensions(m, comp_name, datum_name)
            
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

function _store_trial_results(mcs::MonteCarloSimulation, trialnum::Int)
    savelist = mcs.savelist

    for (m, results) in zip(mcs.models, mcs.results)
        for datum_key in savelist
            _store_param_results(m, datum_key, trialnum, results)
        end
    end
end

"""
    save_trial_results(mcs::MonteCarloSimulation, output_dir::String)

Save the stored MCS results to files in the directory `output_dir`
"""
function save_trial_results(mcs::MonteCarloSimulation, output_dir::AbstractString)
    multiple_results = (length(mcs.results) > 1)

    for (i, results) in enumerate(mcs.results)
        if multiple_results
            sub_dir = joinpath(output_dir, "model_$i")
            mkpath(sub_dir, mode=0o750)
        else
            sub_dir = output_dir 
        end

        for datum_key in mcs.savelist
            (comp_name, datum_name) = datum_key
            filename = joinpath(sub_dir, "$datum_name.csv")
            save(filename, results[datum_key])
        end
    end
end

function save_trial_inputs(mcs::MonteCarloSimulation, filename::String)
    mkpath(dirname(filename), mode=0o770)   # ensure that the specified path exists
    save(filename, mcs)
    return nothing
end

# TBD: Modify lhs() to return an array of SampleStore{T} instances?
"""
    get_trial(mcs::MonteCarloSimulation, trialnum::Int)

Return a NamedTuple with the data for next trial. Note that the `trialnum`
parameter is used only to support a 1-deep data cache that allows this
function to be called successively with the same `trialnum` to retrieve
the same NamedTuple. If `trialnum` does not match the current trial number,
the argument is ignored.
"""
function get_trial(mcs::MonteCarloSimulation, trialnum::Int)
    if mcs.current_trial == trialnum
        return mcs.current_data
    end

    vals = [rand(rv.dist) for rv in values(mcs.rvdict)]
    mcs.current_data = mcs.nt_type((vals...,))
    mcs.current_trial = trialnum
    
    return mcs.current_data
end

"""
    generate_trials!(mcs::MonteCarloSimulation, trials::Int; 
                     filename::String="", sampling::SamplingOptions=RANDOM)

Generate the given number of trials for the given MonteCarloSimulation instance. 
Call this before running the MCS to pre-generate data to be used by all 
scenarios. Also enables saving of inputs or choosing a sampling method other 
than RANDOM. (Currently, only LHS and RANDOM are possible.)
"""
function generate_trials!(mcs::MonteCarloSimulation, trials::Int; 
                          filename::String="",
                          sampling::SamplingOptions=RANDOM)
    mcs.trials = trials

    if sampling == LHS
        corrmatrix = correlation_matrix(mcs)
        lhs!(mcs, corrmatrix=corrmatrix)
    else    # sampling == RANDOM
        rand!(mcs)
    end

    # TBD: If user asks for trial data to be saved, generate it up-front, or 
    # open a file that can be written to for each trialnum/scenario set?
    if filename != ""
        save_trial_inputs(mcs, filename)
    end
end

"""
    Random.rand!(mcs::MonteCarloSimulation)

Replace all RVs originally of type Distribution with SampleStores with 
values drawn from that original distribution.
"""
function Random.rand!(mcs::MonteCarloSimulation)
    rvdict = mcs.rvdict
    trials = mcs.trials

    for rv in mcs.dist_rvs
        values = rand(rv.dist, trials)
        rvdict[rv.name] = RandomVariable(rv.name, SampleStore(values))
    end
end

"""
    _copy_mcs_params(mcs::MonteCarloSimulation)

Copy the parameters that are perturbed in this MCS so we can restore them after each trial.
This is necessary when we are applying distributions by adding or multiplying original values.
"""
function _copy_mcs_params(mcs::MonteCarloSimulation)
    param_vec = Vector{Dict{Symbol, ModelParameter}}(undef, length(mcs.models))

    for (i, m) in enumerate(mcs.models)
        md = modelinstance_def(m)
        param_vec[i] = Dict{Symbol, ModelParameter}(trans.paramname => copy(external_param(md, trans.paramname)) for trans in mcs.translist)
    end

    return param_vec
end

function _restore_mcs_params!(mcs::MonteCarloSimulation, param_vec::Vector{Dict{Symbol, ModelParameter}})
    for (m, params) in zip(mcs.models, param_vec)
        md = modelinstance_def(m)

        for trans in mcs.translist
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
    pdims = dimensions(param)   # returns [] for scalar parameters
    num_pdims = length(pdims)

    tdims  = trans.dims
    num_dims = length(tdims)

    if num_pdims != num_dims
        pname = trans.paramname
        error("Dimension mismatch: external parameter :$pname has $num_pdims dimensions ($pdims); MCS has $num_dims")
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

function _perturb_param!(param::ArrayModelParameter{T}, md::ModelDef, trans::TransformSpec, rvalue::Number) where T
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
    _perturb_params!(mcs::MonteCarloSimulation, trialnum::Int)

Modify the stochastic parameters for all models in `mcs`, using the 
values drawn for trial `trialnum`.
"""
function _perturb_params!(mcs::MonteCarloSimulation, trialnum::Int)
    if trialnum > mcs.trials
        error("Attempted to run trial $trialnum, but only $(mcs.trials) trials are defined")
    end

    trialdata = get_trial(mcs, trialnum)

    for m in mcs.models
        md = modelinstance_def(m)

        for trans in mcs.translist        
            param = external_param(md, trans.paramname)
            rvalue = getfield(trialdata, trans.rvname)
            _perturb_param!(param, md, trans, rvalue)
        end
    end
    return nothing
end

function _reset_rvs!(mcs::MonteCarloSimulation)
    for rv in values(mcs.rvdict)
        if rv.dist isa SampleStore
            reset(rv.dist)
        end
    end
end

"""
    _reset_results!(mcs::MonteCarloSimulation)

Reset all MCS results storage to a vector of empty dicts
"""
function _reset_results!(mcs::MonteCarloSimulation)
    mcs.results = [Dict{Tuple, DataFrame}() for m in mcs.models]
end

# Append a string representation of the tuple args to the given directory name
function _compute_output_dir(orig_output_dir, tup)
    output_dir = (orig_output_dir === nothing) ? nothing : joinpath(orig_output_dir, join(map(string, tup), "_"))
    mkpath(output_dir, mode=0o750)
    return output_dir
end

"""
    run_mcs(mcs::MonteCarloSimulation, 
            trials::Union{Int, Vector{Int}, AbstractRange{Int}},
            models_to_run::Int=length(mcs.models);
            ntimesteps::Int=typemax(Int), 
            output_dir::Union{Nothing, AbstractString}=nothing, 
            pre_trial_func::Union{Nothing, Function}=nothing, 
            post_trial_func::Union{Nothing, Function}=nothing,
            scenario_func::Union{Nothing, Function}=nothing,
            scenario_placement::ScenarioLoopPlacement=OUTER,
            scenario_args=nothing)

Run the indicated trial numbers, where the first `models_to_run` associated models are run 
for `ntimesteps`, if specified, else to the maximum defined time period. Note that trial
data are applied to all the associated models even when running only a portion of them.
    
If `pre_trial_func` or `post_trial_func` are defined, the designated functions are called 
just before or after (respectively) running a trial. The functions must have the signature:

    fn(mcs::MonteCarloSimulation, trialnum::Int, ntimesteps::Int, tup::Tuple)

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the MCS loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

If provided, `scenario_args` must be a `Vector{Pair}`, where each `Pair` is a symbol and a 
`Vector` of arbitrary values that will be meaningful to `scenario_func`, which must have
the signature:

    scenario_func(mcs::MonteCarloSimulation, tup::Tuple)

By default, the scenario loop encloses the Monte Carlo loop, but the scenario loop can be
placed inside the Monte Carlo loop by specifying `scenario_placement=INNER`. When `INNER` 
is specified, the `scenario_func` is called after any `pre_trial_func` but before the model
is run.
"""
function run_mcs(mcs::MonteCarloSimulation, 
                 trials::Union{Vector{Int}, AbstractRange{Int}},
                 models_to_run::Int=length(mcs.models);     # run all models by default
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing)

    if (scenario_func === nothing) != (scenario_args === nothing)
        error("run_mcs: scenario_func and scenario_arg must both be nothing or both set to non-nothing values")
    end

    for m in mcs.models
        if ! is_built(m)
            build(m)
        end
    end
    
    # TBD: address confusion over whether trials is a list of trialnums or just the number of trials
    mcs.trials = length(trials)

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
            scenario_func(mcs, outer_tup)

            # we'll store the results of each in a subdir composed of tuple values
            output_dir = _compute_output_dir(orig_output_dir, outer_tup)
        end
                
        # Save the params to be perturbed so we can reset them after each trial
        original_values = _copy_mcs_params(mcs)        
        
        # Reset internal index to 1 for all stored parameters to reuse the data
        _reset_rvs!(mcs)

        for (i, trialnum) in enumerate(trials)
            @debug "Running trial $trialnum"

            for inner_tup in arg_tuples_inner
                tup = has_inner_scenario ? inner_tup : outer_tup

                _perturb_params!(mcs, trialnum)

                if pre_trial_func !== nothing
                    @debug "Calling pre_trial_func($trialnum, $tup)"
                    pre_trial_func(mcs, trialnum, ntimesteps, tup)
                end               

                if has_inner_scenario
                    @debug "Calling inner scenario_func with $inner_tup"
                    scenario_func(mcs, inner_tup)

                    output_dir = _compute_output_dir(orig_output_dir, inner_tup)
                end

                for m in mcs.models[1:models_to_run]    # note that list of models may be changed in scenario_func
                    @debug "Running model"
                    run(m, ntimesteps=ntimesteps)
                end
                
                if post_trial_func !== nothing
                    @debug "Calling post_trial_func($trialnum, $tup)"
                    post_trial_func(mcs, trialnum, ntimesteps, tup)
                end

                _store_trial_results(mcs, trialnum)
                _restore_mcs_params!(mcs, original_values)

                counter += 1
                ProgressMeter.update!(p, counter)                
            end

            if has_inner_scenario && has_output_dir
                save_trial_results(mcs, output_dir)
                _reset_results!(mcs)
            end
        end

        if ! has_inner_scenario && has_output_dir
            save_trial_results(mcs, output_dir)
            _reset_results!(mcs)
        end
    end
end

# Same as above, but takes a number of trials and converts this to `1:trials`.
function run_mcs(mcs::MonteCarloSimulation, trials::Int=mcs.trials, 
                 models_to_run::Int=length(mcs.models); kwargs...)
    return run_mcs(mcs, 1:trials, models_to_run; kwargs...)
end

# Same as above, but takes a single model to run
function run_mcs(mcs::MonteCarloSimulation, m::Model, trials=mcs.trials, 
                 models_to_run::Int=length(mcs.models); kwargs...)
    set_model!(mcs, m)
    return run_mcs(mcs, trials, models_to_run; kwargs...)
end

# Same as above, but takes a multiple models to run
function run_mcs(mcs::MonteCarloSimulation, models::Vector{Model}, trials=mcs.trials, 
                 models_to_run::Int=length(mcs.models); kwargs...)
    set_models!(mcs, models)
    return run_mcs(mcs, 1:trials, models_to_run; kwargs...)
end

function set_models!(mcs::MonteCarloSimulation, models::Vector{Model})
    mcs.models = models
    _reset_results!(mcs)    # sets results vector to same length
end

# Convenience methods for single model and MarginalModel
set_model!(mcs::MonteCarloSimulation, m::Model) = set_models!(mcs, [m])

set_model!(mcs::MonteCarloSimulation, mm::MarginalModel) = set_models!(mcs, [mm.base, mm.marginal])

#
# Iterator functions for MonteCarloSimulation directly, and for use as an IterableTable.
#
function Base.iterate(mcs::MonteCarloSimulation)
    _reset_rvs!(mcs)
    trialnum = 1
    return get_trial(mcs, trialnum), trialnum + 1
end

function Base.iterate(mcs::MonteCarloSimulation, trialnum)
    if trialnum > mcs.trials
        return nothing
    else
        return get_trial(mcs, trialnum), trialnum + 1
    end
end

TableTraits.isiterable(mcs::MonteCarloSimulation) = true
TableTraits.isiterabletable(mcs::MonteCarloSimulation) = true

IterableTables.getiterator(mcs::MonteCarloSimulation) = MCSIterator{mcs.nt_type}(mcs)

column_names(mcs::MonteCarloSimulation) = fieldnames(mcs.nt_type)
column_types(mcs::MonteCarloSimulation) = [eltype(fld) for fld in values(mcs.rvdict)]

column_names(iter::MCSIterator) = column_names(iter.mcs)
column_types(iter::MCSIterator) = IterableTables.column_types(iter.mcs)

function Base.iterate(iter::MCSIterator)
    _reset_rvs!(iter.mcs)
    idx = 1
    return get_trial(iter.mcs, idx), idx + 1
end

function Base.iterate(iter::MCSIterator, idx)
    if idx > iter.mcs.trials
        return nothing
    else
        return get_trial(iter.mcs, idx), idx + 1
    end
end

Base.length(iter::MCSIterator) = iter.mcs.trials

Base.eltype(::Type{MCSIterator{T}}) where T = T