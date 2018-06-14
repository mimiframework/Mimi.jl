using IterTools
using IterableTables
using TableTraits
using ProgressMeter

function store_trial_results(m::Model, mcs::MonteCarloSimulation, trialnum::Int)
    for datum_key in mcs.savelist
        # println("\nStoring trial results for $datum_key")
        (comp_name, datum_name) = datum_key
        dims = dimensions(m, comp_name, datum_name)
        results = mcs.results
        
        
        if length(dims) == 0        # scalar value
            value = m[comp_name, datum_name]
            # println("Scalar: $value")

            if haskey(results, datum_key)
                results_df = mcs.results[datum_key]
            else
                results_df = DataFrame([typeof(value), Int32], [datum_name, :trialnum], 0)
                mcs.results[datum_key] = results_df
            end

            push!(results_df, [value, trialnum])
            # println("results_df: $results_df")

        else
            # println("Matrix with dims $dims")
            trial_df = getdataframe(m, comp_name, datum_name)
            trial_df[:trialnum] = trialnum
            # println("size of trial_df: $(size(trial_df))")

            if haskey(results, datum_key)
                results_df = mcs.results[datum_key]
                # println("Appending trial_df $(size(trial_df)) to results_df $(size(results_df))")
                append!(results_df, trial_df)
            else
                # println("Setting results[$datum_key] = trial_df $(size(trial_df))")
                mcs.results[datum_key] = trial_df
            end
        end
    end
end
 
"""
    save_trial_results(mcs::MonteCarloSimulation, output_dir::String)

Save the stored MCS results to files in the directory `output_dir`
"""
function save_trial_results(mcs::MonteCarloSimulation, output_dir::AbstractString)
    mkpath(output_dir, 0o750)   # ensure that the specified path exists

    for datum_key in mcs.savelist
        (comp_name, datum_name) = datum_key
        filename = joinpath(output_dir, "$datum_name.csv")
        results_df = mcs.results[datum_key]
        println("Writing $comp_name.$datum_name to $filename")
        # showcols(results_df)
        save(filename, results_df)
    end
end

function save_trial_inputs(mcs::MonteCarloSimulation, filename::String)
    mkpath(dirname(filename), 0o770)   # ensure that the specified path exists
    save(filename, mcs)
    return nothing
end

# TBD: store rvlist and corrlist in src, or just in mcs?
# TBD: generate a NamedTuple for the set of RVs?
# TBD: Modify lhs() to return an array of SampleStore{T} instances
function get_trial(mcs::MonteCarloSimulation, trialnum::Int)
    # We cache the value for the current trial so we can return the
    # same data if requested again, i.e., to support MarginalModel.
    if mcs.current_trial == trialnum
        return mcs.current_data
    end

    vals = [rand(rv.dist) for rv in values(mcs.rvdict)]
    mcs.current_data = mcs.nt_type(vals...)
    mcs.current_trial = trialnum
    
    return mcs.current_data
end

# Deprecated
# function get_trial_data(mcs::MonteCarloSimulation, trialnum::Int)
#     # We cache the value for the current trial so we can return the
#     # same data if requested again, i.e., to support MarginalModel.
#     if mcs.current_trial == trialnum
#         return mcs.data
#     end

#     rvlist = mcs.rvlist

#     if mcs.corrlist == nothing
#         # If no correlations, just grab the next value from each RV
#         values = [rv.dist.rand() for rv in rvlist]
#     else
#         if ! mcs.generated
#             # TBD: should only generate data for correlated vars or using LHS.
#             # First time through, generate all trial data to enable correlations
#             mcs.lhs_data = lhs(rvlist, mcs.trials, corrmatrix=correlation_matrix(mcs))
#             mcs.generated = true
#         end

#         df = mcs.data
#         values = [df[trialnum, col] for col in 1:size(df, 2)]
#     end

#     # Cache data in case its requested again
#     mcs.current_trial = trialnum
#     mcs.data = nt = mcs.nt_type(values...)
    
#     return nt
# end

"""
    generate_trials!(mcs::MonteCarloSimulation, trials::Int; 
                     filename::String="", sampling::SamplingOptions)

Generate the given number of trials for the given MonteCarloSimulation instance. 
Call this before running the MCS to enable saving of inputs to to choose a sampling 
method other than LHS. (Currently, only LHS and RANDOM are possible.)
"""
function generate_trials!(mcs::MonteCarloSimulation, trials::Int; 
                          filename::String="",
                          sampling::SamplingOptions=LHS)
    mcs.trials = trials

    if sampling == LHS
        corrmatrix = correlation_matrix(mcs)
        rvlist = collect(values(mcs.rvdict))

        # update the dict in mcs
        lhs!(mcs, corrmatrix=corrmatrix)

    else    # sampling == RANDOM
        # we pre-generate the trial data only if we're saving it
        if filename != ""
            rand!(mcs)
        end
    end

    # TBD: If user asks for trial data to be saved, generate it up-front, or 
    # open a file that can be written to for each trialnum/scenario set?
    if filename != ""
        save_trial_inputs(mcs, filename)
    end
end

"""
    Base.rand!(mcs::MonteCarloSimulation)

Replace all RVs originally of type Distribution with SampleStores with 
values drawn from that original distribution.
"""
function Base.rand!(mcs::MonteCarloSimulation)
    rvdict = mcs.rvdict
    trials = mcs.trials

    for rv in mcs.dist_rvs
        values = rand(rv.dist, trials)
        rvdict[name] = RandomVariable(rv.name, SampleStore(values))
    end
end

"""
Copy only the parameters that are perturbed in this MCS.
"""
function _copy_mcs_params(mcs, md)
    params = Dict{Symbol, ModelParameter}(trans.paramname => copy(external_param(md, trans.paramname)) for trans in mcs.translist)
    return params
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

function _restore_params!(md::ModelDef, mcs::MonteCarloSimulation, params::Dict{Symbol, ModelParameter})
    for trans in mcs.translist
        name = trans.paramname
        param = params[name]
        _restore_param!(param, name, md, trans)
    end
    return nothing
end

function _param_indices(param::ArrayModelParameter{T}, md::ModelDef, trans::TransformSpec) where T
    pdims = dimensions(param)   # returns [] for scalar parameters
    num_pdims = length(pdims)

    tdims  = trans.dims
    num_dims = length(tdims)

    if num_pdims != num_dims
        error("Dimension mismatch: external parameter :$pname has $num_pdims dimensions ($pdims); MCS has $num_dims")
    end

    indices = Vector()
    for (dim_name, dim_values) in zip(pdims, tdims)
        dim = dimension(md, dim_name)
        # println("Converting $dim_name keys $dim_values to indices")
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
    _perturb_params!(m::Model, mcs::MonteCarloSimulation, trialnum::Int)

Modify the stochastic parameters using the values drawn for trial `trialnum`.
"""
function _perturb_params!(m::Model, mcs::MonteCarloSimulation, trialnum::Int)
    if trialnum > mcs.trials
        error("Attempted to run trial $trialnum, but only $(mcs.trials) trials are defined")
    end

    trialdata = get_trial(mcs, trialnum)

    md = m.mi.md

    for trans in mcs.translist        
        param = external_param(md, trans.paramname)
        rvalue = getfield(trialdata, trans.rvname)

        _perturb_param!(param, md, trans, rvalue)
    end

    return nothing
end

function _perturb_params!(mm::MarginalModel, mcs::MonteCarloSimulation, trialnum::Int)
    # N.B. get_trial() returns the same data in consecutive calls with same trialnum
    _perturb_params!(mm.base, mcs, trialnum)
    _perturb_params!(mm.marginal, mcs, trialnum)
end

function _reset_params!(mcs::MonteCarloSimulation)
    for rv in values(mcs.rvdict)
        if rv.dist isa SampleStore
            reset(rv.dist)
        end
    end
end

"""
clear_results(mcs::MonteCarloSimulation)

Reset all MCS results storage to `nothing`.
"""
function clear_results(mcs::MonteCarloSimulation)
    mcs.results = Dict{Tuple, DataFrame}()
end

"""
    run_mcs(m::Union{Model,MarginalModel}, 
            mcs::MonteCarloSimulation, 
            trials::Union{Int, Vector{Int}, Range{Int}}; 
            ntimesteps::Int=typemax(Int), 
            output_dir::Union{Void, AbstractString}=nothing, 
            pre_trial_func::Union{Void, Function}=nothing, 
            post_trial_func::Union{Void, Function}=nothing,
            loop_func::Union{Void, Function}=nothing,
            loop_args=nothing)

Run the indicated trial numbers, where the model is run for `ntimesteps`, if specified, or to 
the maximum defined time period otherswise. If `pretrial_func` or `posttrial_func` are defined,
the designated functions are called just before or after (respectively) running the trial. The 
functions must have the signature fn(m::Model, mcs::MonteCarloSimulation, trialnum::Int).

If provided, `loop_args` must be a Vector of Pairs, where each pair is a symbol and a Vector
of arbitrary values that will be meaningful to `loop_func`, which is called with the Model, 
`m`, the MonteCarloSimulation `mcs`, and the splatted tuple of values for the current outer
loop iteration.
"""
function run_mcs(m::Union{Model,MarginalModel}, 
                 mcs::MonteCarloSimulation, 
                 trials::Union{Vector{Int}, Range{Int}}; 
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Void, AbstractString}=nothing, 
                 pre_trial_func::Union{Void, Function}=nothing, 
                 post_trial_func::Union{Void, Function}=nothing,
                 scenario_func::Union{Void, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing)

    if (scenario_func == nothing) != (scenario_args == nothing)
        error("run_mcs: scenario_func and scenario_arg must both be nothing or both set to non-nothing values")
    end

    if m.mi == nothing
        build(m)
    end
    md = m.mi.md
    
    orig_output_dir = output_dir

    has_scenario_func = (scenario_func != nothing)
    has_outer_scenario = (has_scenario_func && scenario_placement == OUTER)
    has_inner_scenario = (has_scenario_func && scenario_placement == INNER)

    if has_scenario_func
        seqs = [arg.second for arg in scenario_args]
        arg_tuples = product(seqs...)

        if has_outer_scenario
            arg_tuples_outer = arg_tuples
            arg_tuples_inner = (nothing,)   # allows one iteration when no scenario loop specified
        else
            arg_tuples_outer = (nothing,)
            arg_tuples_inner = arg_tuples
        end
    else
        arg_tuples = arg_tuples_outer = arg_tuples_inner = (nothing,)
    end
    
    nscenarios = length(arg_tuples)
    ntrials = length(trials)
    total_runs = nscenarios * ntrials
    counter = 1
    p = Progress(total_runs, counter, "Running $ntrials trials for $nscenarios scenarios...")

    # Reset internal index to 1 for all stored parameters to reuse the data
    _reset_params!(mcs)

    for tup in arg_tuples_outer

        clear_results(mcs)
        
        # If we're running scenarios, create a subdir to store the results of each
        if has_scenario_func
            scenario_func(m, mcs, tup...)

            _reset_params!(mcs)

            if orig_output_dir != nothing
                output_dir = joinpath(orig_output_dir, join(map(string, tup), "_"))
            end
        end
        
        # Save the params to be perturbed so we can reset them after each trial
        original_values = _copy_mcs_params(mcs, md)

        for (i, trialnum) in enumerate(trials)
            for tup in arg_tuples_inner               
                _perturb_params!(m, mcs, trialnum)

                if pre_trial_func != nothing
                    pre_trial_func(m, mcs, trialnum, tup)
                end               

                if has_inner_scenario
                    scenario_func(m, mcs, tup...)

                    if orig_output_dir != nothing
                        output_dir = joinpath(orig_output_dir, join(map(string, tup), "_"))
                    end
                end

                run(m, ntimesteps=ntimesteps)
                
                if post_trial_func != nothing
                    post_trial_func(m, mcs, trialnum, tup)
                end

                _restore_params!(md, mcs, original_values)
                store_trial_results(m, mcs, trialnum)

                counter += 1
                ProgressMeter.update!(p, counter)
                
                if output_dir != nothing
                    save_trial_results(mcs, output_dir)
                end
            end
        end
    end
end

function run_mcs(m::Union{Model,MarginalModel}, 
                 mcs::MonteCarloSimulation, 
                 trials::Int=mcs.trials; 
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Void, AbstractString}=nothing, 
                 pre_trial_func::Union{Void, Function}=nothing, 
                 post_trial_func::Union{Void, Function}=nothing,
                 scenario_func::Union{Void, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing)
    return run_mcs(m, mcs, 1:trials, 
                   ntimesteps=ntimesteps, 
                   output_dir=output_dir, 
                   pre_trial_func=pre_trial_func, 
                   post_trial_func=post_trial_func,
                   scenario_func=scenario_func, 
                   scenario_placement=scenario_placement,
                   scenario_args=scenario_args)
end

# Iterator protocol. `State` is just the trial number

function Base.start(mcs::MonteCarloSimulation)
    _reset_params!(mcs)
    return 1
end
Base.next(mcs::MonteCarloSimulation, trialnum) = (get_trial(mcs, trialnum), trialnum + 1)
Base.done(mcs::MonteCarloSimulation, trialnum) = (trialnum == mcs.trials)

TableTraits.isiterable(mcs::MonteCarloSimulation) = true
TableTraits.isiterabletable(mcs::MonteCarloSimulation) = true

IterableTables.getiterator(mcs::MonteCarloSimulation) = MCSIterator{mcs.nt_type}(mcs)
# IterableTables.getiterator(mcs::MonteCarloSimulation) = mcs

column_names(mcs::MonteCarloSimulation) = fieldnames(mcs.nt_type)
column_types(mcs::MonteCarloSimulation) = [eltype(fld) for fld in values(mcs.rvdict)]

column_names(iter::MCSIterator) = column_names(iter.mcs)
column_types(iter::MCSIterator) = IterableTables.column_types(iter.mcs)

function Base.start(iter::MCSIterator)
    _reset_params!(iter.mcs)
    return 1
end

Base.next(iter, idx) = (get_trial(iter.mcs, idx), idx + 1)
Base.done(iter, idx) = (idx == iter.mcs.trials)
Base.length(iter) = iter.mcs.trials

Base.eltype(::Type{MCSIterator{T}}) where T = T