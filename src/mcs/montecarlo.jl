using IterTools

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
    save(filename, mcs.data)
    return nothing
end

"""
    generate_trials!(mcs::MonteCarloSimulation, trials::Int; filename::String="")

Generate the given number of trials for the given MonteCarloSimulation instance.
"""
function generate_trials!(mcs::MonteCarloSimulation, trials::Int; filename::String="")
    corrmatrix = correlation_matrix(mcs)
    mcs.data = lhs(mcs.rvlist, trials, corrmatrix=corrmatrix)
    mcs.trials = trials

    if filename != ""
        save_trial_inputs(mcs, filename)
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

# TBD: precompute as much of this as possible to get it out of the MCS trial loop
"""
    _perturb_params!(m::Model, mcs::MonteCarloSimulation, trialnum::Int)

Modify the stochastic parameters using the values drawn for trial `trialnum`.
"""
function _perturb_params!(md::ModelDef, mcs::MonteCarloSimulation, trialnum::Int)
    if trialnum > mcs.trials
        error("Attempted to run trial $trialnum, but only $(mcs.trials) trials are defined")
    end

    trialdata = mcs.data[trialnum, :]

    for trans in mcs.translist        
        param = external_param(md, trans.paramname)
        rvalue = trialdata[1, trans.rvname]
        _perturb_param!(param, md, trans, rvalue)
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
    run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Union{Int, Vector{Int}, Range{Int}}; 
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
function run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Union{Vector{Int}, Range{Int}}; 
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Void, AbstractString}=nothing, 
                 pre_trial_func::Union{Void, Function}=nothing, 
                 post_trial_func::Union{Void, Function}=nothing,
                 loop_func::Union{Void, Function}=nothing,
                 loop_args=nothing)

    if (loop_func == nothing) != (loop_args == nothing)
        error("run_mcs: loop_func and loop_arg must both be nothing or both set to non-nothing values")
    end

    if m.mi == nothing
        build(m)
    end
    md = m.mi.md
    
    orig_output_dir = output_dir

    if loop_args == nothing
        arg_tuples = (nothing,)     # handles case with no outer loop
    else
        seqs = [arg.second for arg in loop_args]
        arg_tuples = product(seqs...)
    end

    for tup in arg_tuples

        if loop_func != nothing
            # Call outer loop setup function
            loop_func(m, mcs, tup...)

            # Create a subdir to store the results of each outer loop
            if orig_output_dir != nothing
                output_dir = joinpath(orig_output_dir, join(map(string, tup), "_"))
            end
        end

        clear_results(mcs)
        
        # Save the params to be perturbed so we can reset them after each trial
        original_values = _copy_mcs_params(mcs, md)

        # Compute how often to print a "Running trial ..." message.
        count = length(trials)
        divisor = (count < 50 ? 1 : (count < 500 ? 10 : 100))
        
        for (i, trialnum) in enumerate(trials)
            i % divisor == 0 && println("Running trial $trialnum ")
            _perturb_params!(md, mcs, trialnum)

            pre_trial_func  == nothing || pre_trial_func(m, mcs, trialnum)
            run(m, ntimesteps=ntimesteps)
            post_trial_func == nothing || post_trial_func(m, mcs, trialnum)

            _restore_params!(md, mcs, original_values)
            store_trial_results(m, mcs, trialnum)
        end

        if output_dir != nothing
            save_trial_results(mcs, output_dir)
        end
    end
end

function run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Int=mcs.trials; 
                 ntimesteps::Int=typemax(Int), 
                 output_dir::Union{Void, AbstractString}=nothing, 
                 pre_trial_func::Union{Void, Function}=nothing, 
                 post_trial_func::Union{Void, Function}=nothing,
                 loop_func::Union{Void, Function}=nothing,
                 loop_args=nothing)
    return run_mcs(m, mcs, 1:trials, ntimesteps=ntimesteps, output_dir=output_dir, 
                   pre_trial_func=pre_trial_func, post_trial_func=post_trial_func,
                   loop_func=loop_func, loop_args=loop_args)
end
