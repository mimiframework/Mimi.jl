function store_trial_results(m::Model, mcs::MonteCarloSimulation, trialnum::Int64)
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
function save_trial_results(mcs::MonteCarloSimulation, output_dir::String=mcs.output_dir)
    if output_dir == nothing
        error("save_trial_results: output_dir must be specified")
    else
        mkpath(output_dir, 0o750)   # ensure that the specified path exists
    end

    for datum_key in mcs.savelist
        (comp_name, datum_name) = datum_key
        filename = joinpath(output_dir, "$datum_name.csv")
        results_df = mcs.results[datum_key]
        println("Writing $comp_name.$datum_name to $filename")
        # showcols(results_df)
        CSV.write(filename, results_df)
    end
end

function save_trial_inputs(mcs::MonteCarloSimulation, filename::String)
    mkpath(dirname(filename), 0o770)   # ensure that the specified path exists
    CSV.write(filename, mcs.data)
    return nothing
end

"""
    generate_trials!(mcs::MonteCarloSimulation, trials::Int64; filename::String="")

Generate the given number of trials for the given MonteCarloSimulation instance.
"""
function generate_trials!(mcs::MonteCarloSimulation, trials::Int64; filename::String="")
    corrmatrix = correlation_matrix(mcs)
    mcs.data = lhs(mcs.rvlist, trials, corrmatrix=corrmatrix)
    mcs.trials = trials

    if filename != ""
        save_trial_inputs(mcs, filename)
    end
end

# TBD: precompute as much of this as possible to get it out of the MCS trial loop
"""
    _perturb_parameters(m::Model, mcs::MonteCarloSimulation, trialnum::Int64)

Modify the stochastic parameters using the values drawn for trial `trialnum`.
"""
function _perturb_parameters(m::Model, mcs::MonteCarloSimulation, trialnum::Int64)
    if trialnum > mcs.trials
        error("Attempted to run trial $trialnum, but only $(mcs.trials) trials are defined")
    end

    mi = m.mi

    # "original" external params that are perturbed in a local copy stored in mi.md
    mi.md.external_params = ext_params = copy_external_params(m.md)

    # point these to our copy of the external params, which we will perturb
    connect_external_params(mi)
    
    rvlist = mcs.rvlist
    trialdata = mcs.data[trialnum, :]

    for trans in mcs.translist
        rvname = trans.rvname
        op     = trans.op
        pname  = trans.paramname
        tdims  = trans.dims

        if ! (op in (:(=), :(*=), :(+=)))
            error("Unknown op ($op) for applying random values in MCS")
        end
        
        param = ext_params[pname]
        pdims = dimensions(param)   # returns [] for scalar parameters
        num_pdims = length(pdims)

        num_dims = length(tdims)
        if num_pdims != num_dims
            error("Dimension mismatch: external parameter :$pname has $num_pdims dimensions ($pdims); MCS has $num_dims")
        end

        rvalue = trialdata[1, rvname]
        pvalue = value(param)
        T = typeof(param)
        # println("$(pname)::$T $(tdims) $op $rvalue")

        if param isa ScalarModelParameter
            if op == :(=)
                param.value = rvalue

            elseif op == :(*=)
                param.value *= rvalue

            else
                param.value += rvalue
            end

        else    # ArrayModelParameter
            indices = Vector()
            for (dim_name, dim_values) in zip(pdims, tdims)
                dim = dimension(mi.md, dim_name)
                # println("Converting $dim_name keys $dim_values to indices")
                push!(indices, dim[dim_values])
            end

            # println("indices: $indices")

            if op == :(=)
                pvalue[indices...] = rvalue

            elseif op == :(*=)
                pvalue[indices...] *= rvalue

            else
                pvalue[indices...] += rvalue
            end
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
    run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Union{Vector{Int64}, Range{Int64}}; ntimesteps=typemax(Int), pretrial_func=nothing, posttrial_func=nothing)

Run the indicated trial numbers, where the model is run for `ntimesteps`, if specified, or to 
the maximum defined time period otherswise. If `pretrial_func` or `posttrial_func` are defined,
the designated functions are called just before or after (respectively) running the trial. The 
functions must have the signature fn(m::Model, mcs::MonteCarloSimulation, trialnum::Int64).
"""
function run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Union{Vector{Int64}, Range{Int64}}; 
                 ntimesteps=typemax(Int), output_dir=nothing, 
                 pre_trial_func=nothing, post_trial_func=nothing)
    if m.mi == nothing
        build(m)
    end

    mcs.output_dir = output_dir

    clear_results(mcs)

    # Compute how often to print a "Running trial ..." message.
    count = length(trials)
    divisor = (count < 50 ? 1 : (count < 500 ? 10 : 100))

    for trialnum in trials
        trialnum % divisor == 0 && println("Running trial $trialnum ")
        _perturb_parameters(m, mcs, trialnum)

        pre_trial_func  != nothing && pre_trial_func(m, mcs, trialnum)
        run(m, ntimesteps=ntimesteps)
        post_trial_func != nothing && post_trial_func(m, mcs, trialnum)

        store_trial_results(m, mcs, trialnum)
    end

    if output_dir != nothing
        save_trial_results(mcs)
    end
end

"""
    run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Int64=mcs.trials; ntimesteps=typemax(Int))

Run the indicated number of trials, where the model is run for `ntimesteps`, if specified, or to 
the maximum defined time period otherswise.
"""
function run_mcs(m::Model, mcs::MonteCarloSimulation, trials::Int64=mcs.trials; 
                 ntimesteps=typemax(Int), output_dir=nothing, 
                 pre_trial_func=nothing, post_trial_func=nothing)
    return run_mcs(m, mcs, 1:trials, ntimesteps=ntimesteps, output_dir=output_dir, 
                   pre_trial_func=pre_trial_func, post_trial_func=post_trial_func)
end