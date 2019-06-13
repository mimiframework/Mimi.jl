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

function Base.show(io::IO, sim_def::SimulationDef{T}) where T <: AbstractSimulationData
    println("SimulationDef{$T}")
    
    println("  trials: $(sim_def.trials)")
    println("  current_trial: $(sim_def.current_trial)")
    
    sim_def.current_trial > 0 && println("  current_data: $(sim_def.current_data)")
    
    println("  rvdict:")
    for (key, value) in sim_def.rvdict
        println("    $key: $(typeof(value))")
    end

    print_nonempty("translist", sim_def.translist)
    print_nonempty("savelist",  sim_def.savelist)
    println("  nt_type: $(sim_def.nt_type)")

    Base.show(io, sim_def.data)  # note: data::T
end

function Base.show(io::IO, sim_inst::SimulationInstance{T}) where T <: AbstractSimulationData
    println("SimulationInstance{$T}")
    
    Base.show(io, sim_inst.sim_def)

    println("  $(length(sim_inst.models)) models")
    println("  $(length(sim_inst.results)) results dicts")    
end

function Base.show(obj::T) where T <: AbstractSimulationData
    nothing
end

# Store results for a single parameter
function _store_param_results(m::Model, datum_key::Tuple{Symbol, Symbol}, trialnum::Int, scen_name::Union{Nothing, String}, results::Dict{Tuple, DataFrame})
    @debug "\nStoring trial results for $datum_key"

    (comp_name, datum_name) = datum_key
    dims = dimensions(m, comp_name, datum_name)
    has_scen = ! (scen_name === nothing)

    if length(dims) == 0        # scalar value
        value = m[comp_name, datum_name]
        # println("Scalar: $value")

        if haskey(results, datum_key)
            results_df = results[datum_key]
        else
            if has_scen
                results_df = DataFrame([typeof(value), Int, String], [datum_name, :trialnum, :scen], 0)
            else
                results_df = DataFrame([typeof(value), Int], [datum_name, :trialnum], 0)
            end
            results[datum_key] = results_df
        end

        has_scen ? push!(results_df, [value, trialnum, scen_name]) : push!(results_df, [value, trialnum])
        # println("results_df: $results_df")

    else
        trial_df = getdataframe(m, comp_name, datum_name)
        trial_df[:trialnum] = trialnum
        has_scen ? trial_df[:scen] = scen_name : nothing
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

function _store_trial_results(sim_inst::SimulationInstance{T}, trialnum::Int, scen_name::Union{Nothing, String}) where T <: AbstractSimulationData
    savelist = sim_inst.sim_def.savelist

    for (m, results) in zip(sim_inst.models, sim_inst.results)
        for datum_key in savelist
            _store_param_results(m, datum_key, trialnum, scen_name, results)
        end
    end
end

"""
    save_trial_results(sim_inst::SimulationInstance, output_dir::String)

Save the stored simulation results to files in the directory `output_dir`
"""
function save_trial_results(sim_inst::SimulationInstance{T}, output_dir::AbstractString) where T <: AbstractSimulationData
    multiple_results = (length(sim_inst.results) > 1)

    mkpath(output_dir, mode=0o750)
    
    for (i, results) in enumerate(sim_inst.results)
        if multiple_results
            sub_dir = joinpath(output_dir, "model_$i")
            mkpath(sub_dir, mode=0o750)
        else
            sub_dir = output_dir 
        end

        for datum_key in sim_inst.sim_def.savelist
            (comp_name, datum_name) = datum_key
            filename = joinpath(sub_dir, "$datum_name.csv")
            save(filename, results[datum_key])
        end
    end
end

function save_trial_inputs(sim_def::SimulationDef, filename::String)
    mkpath(dirname(filename), mode=0o750)   # ensure that the specified path exists
    save(filename, sim_def)
    return nothing
end

# TBD: Modify lhs() to return an array of SampleStore{T} instances?
"""
    get_trial(sim_def::SimulationDef, trialnum::Int)

Return a NamedTuple with the data for next trial. Note that the `trialnum`
parameter is used only to support a 1-deep data cache that allows this
function to be called successively with the same `trialnum` to retrieve
the same NamedTuple. If `trialnum` does not match the current trial number,
the argument is ignored.
"""
function get_trial(sim_def::SimulationDef, trialnum::Int)
    if sim_def.current_trial == trialnum
        return sim_def.current_data
    end

    vals = [rand(rv.dist) for rv in values(sim_def.rvdict)]
    sim_def.current_data = sim_def.nt_type((vals...,))
    sim_def.current_trial = trialnum
    
    return sim_def.current_data
end

"""
    generate_trials!(sim_def::SimulationDef{T}, samples::Int; filename::Union{String, Nothing}=nothing)

Generate trials for the given SimulationDef using the defined `samplesize.
Call this before running the sim to pre-generate data to be used by all scenarios. 
Also saves inputs if a filename is given.
"""
function generate_trials!(sim_def::SimulationDef{T}, samplesize::Int;
                        filename::Union{String, Nothing}=nothing) where T <: AbstractSimulationData
    sample!(sim_def, samplesize)

    # TBD: If user asks for trial data to be saved, generate it up-front, or 
    # open a file that can be written to for each trialnum/scenario set?
    if filename != nothing
        save_trial_inputs(sim_def, filename)
    end
end

function sample!(sim_def::MonteCarloSimulationDef, samplesize::Int)
    sim_def.trials = samplesize
    rand!(sim_def)
end

"""
    Random.rand!(sim_def::SimulationDef{T})

Replace all RVs originally of type Distribution with SampleStores with 
values drawn from that original distribution.
"""
function Random.rand!(sim_def::SimulationDef{T}) where T <: AbstractSimulationData
    rvdict = sim_def.rvdict
    trials = sim_def.trials

    for rv in values(sim_def.rvdict)
        # use underlying distribution, if known
        orig_dist = (rv.dist isa SampleStore ? rv.dist.dist : rv.dist)
        dist = (orig_dist === nothing ? rv.dist : orig_dist)
        values = rand(dist, trials)
        rvdict[rv.name] = RandomVariable(rv.name, SampleStore(values, orig_dist))
    end
end

"""
    _copy_sim_params(sim_inst::SimulationInstance{T})

Copy the parameters that are perturbed so we can restore them after each trial. This
is necessary when we are applying distributions by adding or multiplying original values.
"""
function _copy_sim_params(sim_inst::SimulationInstance{T}) where T <: AbstractSimulationData
    param_vec = Vector{Dict{Symbol, ModelParameter}}(undef, length(sim_inst.models))

    for (i, m) in enumerate(sim_inst.models)
        md = m.mi.md
        param_vec[i] = Dict{Symbol, ModelParameter}(trans.paramname => copy(external_param(md, trans.paramname)) for trans in sim_inst.sim_def.translist)
    end

    return param_vec
end

function _restore_sim_params!(sim_inst::SimulationInstance{T}, 
                              param_vec::Vector{Dict{Symbol, ModelParameter}}) where T <: AbstractSimulationData
    for (m, params) in zip(sim_inst.models, param_vec)
        md = m.mi.md
        for trans in sim_inst.sim_def.translist
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
    _perturb_params!(sim_inst::SimulationInstance{T}, trialnum::Int)

Modify the stochastic parameters for all models in `sim_inst`, using the 
values drawn for trial `trialnum`.
"""
function _perturb_params!(sim_inst::SimulationInstance{T}, trialnum::Int) where T <: AbstractSimulationData
    if trialnum > sim_inst.sim_def.trials
        error("Attempted to run trial $trialnum, but only $(sim_inst.sim_def.trials) trials are defined")
    end

    trialdata = get_trial(sim_inst.sim_def, trialnum)

    for m in sim_inst.models
        md = m.mi.md
        for trans in sim_inst.sim_def.translist        
            param = external_param(md, trans.paramname)
            rvalue = getfield(trialdata, trans.rvname)
            _perturb_param!(param, md, trans, rvalue)
        end
    end
    return nothing
end

function _reset_rvs!(sim_def::SimulationDef{T}) where T <: AbstractSimulationData
    for rv in values(sim_def.rvdict)
        if rv.dist isa SampleStore
            reset(rv.dist)
        end
    end
end

"""
    _reset_results!(sim_inst::SimulationInstance{T})

Reset all simulation results storage to a vector of empty dicts
"""
function _reset_results!(sim_inst::SimulationInstance{T}) where T <: AbstractSimulationData
    sim_inst.results = [Dict{Tuple, DataFrame}() for m in sim_inst.models]
end

# Append a string representation of the tuple args to the given directory name
function _compute_output_dir(orig_output_dir, tup)
    output_dir = (orig_output_dir === nothing) ? nothing : joinpath(orig_output_dir, join(map(string, tup), "_"))
    mkpath(output_dir, mode=0o750)
    return output_dir
end

"""
    run(sim_def::SimulationDef{T}, models::Union{Vector{Model}, Model}, samplesize::Int; 
            ntimesteps::Int=typemax(Int), 
            trials_output_filename::Union{Nothing, AbstractString}=nothing, 
            results_output_dir::Union{Nothing, AbstractString}=nothing, 
            pre_trial_func::Union{Nothing, Function}=nothing, 
            post_trial_func::Union{Nothing, Function}=nothing,
            scenario_func::Union{Nothing, Function}=nothing,
            scenario_placement::ScenarioLoopPlacement=OUTER,
            scenario_args=nothing,
            results_in_memory::Bool=true)

Run the simulation definition `sim_def` for the `models` using `samplesize` samples.

Optionally run the `models` for `ntimesteps`, if specified, 
else to the maximum defined time period. Note that trial data are applied to all the 
associated models even when running only a portion of them.   

If provided, the generated trials and results will be saved in the indicated 
`trials_output_filename` and `results_output_dir` respectively. If `results_in_memory` is set
to false, then results will be cleared from memory and only stored in the
`results_output_dir`.

If `pre_trial_func` or `post_trial_func` are defined, the designated functions are called 
just before or after (respectively) running a trial. The functions must have the signature:

    fn(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)

where `tup` is a tuple of scenario arguments representing one element in the cross-product
of all scenario value vectors. In situations in which you want the simulation loop to run only
some of the models, the remainder of the runs can be handled using a `pre_trial_func` or
`post_trial_func`.

If provided, `scenario_args` must be a `Vector{Pair}`, where each `Pair` is a symbol and a 
`Vector` of arbitrary values that will be meaningful to `scenario_func`, which must have
the signature:

    scenario_func(sim_inst::SimulationInstance, tup::Tuple)

By default, the scenario loop encloses the simulation loop, but the scenario loop can be
placed inside the simulation loop by specifying `scenario_placement=INNER`. When `INNER` 
is specified, the `scenario_func` is called after any `pre_trial_func` but before the model
is run.

Returns the type `SimulationInstance` that contains a copy of the original `SimulationDef`,
along with mutated information about trials, in addition to the model list and 
results information.
"""
function Base.run(sim_def::SimulationDef{T}, models::Union{Vector{Model}, Model}, samplesize::Int;
                 ntimesteps::Int=typemax(Int), 
                 trials_output_filename::Union{Nothing, AbstractString}=nothing, 
                 results_output_dir::Union{Nothing, AbstractString}=nothing, 
                 pre_trial_func::Union{Nothing, Function}=nothing, 
                 post_trial_func::Union{Nothing, Function}=nothing,
                 scenario_func::Union{Nothing, Function}=nothing,
                 scenario_placement::ScenarioLoopPlacement=OUTER,
                 scenario_args=nothing,
                 results_in_memory::Bool=true) where T <: AbstractSimulationData

            
    # Quick check for results saving
    if (!results_in_memory) && (results_output_dir===nothing)
        error("The results_in_memory keyword arg is set to ($results_in_memory) and 
        results_output_dir keyword arg is set to ($results_output_dir), thus 
        results will not be saved eitehr in memory or in a file.")
    end

    # Initiate the SimulationInstance and set the models and trials for the copied 
    # sim held within sim_inst
    sim_inst = SimulationInstance{typeof(sim_def.data)}(sim_def)
    set_models!(sim_inst, models)
    generate_trials!(sim_inst.sim_def, samplesize; filename=trials_output_filename)

    if (scenario_func === nothing) != (scenario_args === nothing)
        error("run: scenario_func and scenario_arg must both be nothing or both set to non-nothing values")
    end

    for m in sim_inst.models
        if m.mi === nothing
            build(m)
        end
    end
    
    trials = 1:sim_inst.sim_def.trials

    # Save the original dir since we modify the output_dir to store scenario results
    orig_results_output_dir = results_output_dir

    # booleans vars to simplify the repeated tests in the loop below
    has_results_output_dir     = (orig_results_output_dir !== nothing)
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
        scen_name = nothing
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
            scenario_func(sim_inst, outer_tup)

            # we'll store the results of each in a subdir composed of tuple values
            results_output_dir = _compute_output_dir(orig_results_output_dir, outer_tup)

            # we'll need a scenario name for the DataFrame
            scen_name = join(map(string, outer_tup), "_")
        end
                
        # Save the params to be perturbed so we can reset them after each trial
        original_values = _copy_sim_params(sim_inst)        
        
        # Reset internal index to 1 for all stored parameters to reuse the data
        _reset_rvs!(sim_inst.sim_def)

        for (i, trialnum) in enumerate(trials)
            @debug "Running trial $trialnum"

            for inner_tup in arg_tuples_inner
                tup = has_inner_scenario ? inner_tup : outer_tup

                _perturb_params!(sim_inst, trialnum)

                if pre_trial_func !== nothing
                    @debug "Calling pre_trial_func($trialnum, $tup)"
                    pre_trial_func(sim_inst, trialnum, ntimesteps, tup)
                end               

                if has_inner_scenario
                    @debug "Calling inner scenario_func with $inner_tup"
                    scenario_func(sim_inst, inner_tup)

                    results_output_dir = _compute_output_dir(orig_results_output_dir, inner_tup)

                    # we'll need a scenario name for the DataFrame
                    scen_name = join(map(string, inner_tup), "_")
                end

                for m in sim_inst.models   # note that list of models may be changed in scenario_func
                    @debug "Running model"
                    run(m, ntimesteps=ntimesteps)
                end
                
                if post_trial_func !== nothing
                    @debug "Calling post_trial_func($trialnum, $tup)"
                    post_trial_func(sim_inst, trialnum, ntimesteps, tup)
                end

                _store_trial_results(sim_inst, trialnum, scen_name)
                _restore_sim_params!(sim_inst, original_values)

                counter += 1
                ProgressMeter.update!(p, counter)                

                if has_inner_scenario && has_results_output_dir
                    save_trial_results(sim_inst, results_output_dir)
                    if ! results_in_memory
                        _reset_results!(sim_inst)
                    end
                end
            end
        end

        if ! has_inner_scenario && has_results_output_dir
            save_trial_results(sim_inst, results_output_dir)
            if ! results_in_memory
                _reset_results!(sim_inst)
            end
        end
    end

    return sim_inst
end

# Set models
""" 
	    set_models!(sim_inst::SimulationInstance{T}, models::Vector{Model})
	
	Set the `models` to be used by the SimulationDef held by `sim_inst`. 
"""
function set_models!(sim_inst::SimulationInstance{T}, models::Vector{Model}) where T <: AbstractSimulationData
    sim_inst.models = models
    _reset_results!(sim_inst)    # sets results vector to same length
end

# Convenience methods for single model and MarginalModel
""" 
set_models!(sim_inst::SimulationInstance{T}, m::Model)
	
    Set the model `m` to be used by the Simulatoin held by `sim_inst`.
"""
set_models!(sim_inst::SimulationInstance{T}, m::Model)  where T <: AbstractSimulationData = set_models!(sim_inst, [m])

""" 
set_models!(sim::SimulationInstance{T}, mm::MarginalModel)

    Set the models to be used by the SimulationDef held by `sim_inst` to be `mm.base` and `mm.marginal`
	which make up the MarginalModel `mm`. 
"""
set_models!(sim_inst::SimulationInstance{T}, mm::MarginalModel) where T <: AbstractSimulationData = set_models!(sim_inst, [mm.base, mm.marginal])

#
# Iterator functions for Simulation definition directly, and for use as an IterableTable.
#
function Base.iterate(sim_def::SimulationDef{T}) where T <: AbstractSimulationData
    _reset_rvs!(sim_def)
    trialnum = 1
    return get_trial(sim_def, trialnum), trialnum + 1
end

function Base.iterate(sim_def::SimulationDef{T}, trialnum) where T <: AbstractSimulationData
    if trialnum > sim_def.trials
        return nothing
    else
        return get_trial(sim_def, trialnum), trialnum + 1
    end
end

IteratorInterfaceExtensions.isiterable(sim_def::SimulationDef{T}) where T <: AbstractSimulationData = true
TableTraits.isiterabletable(sim_def::SimulationDef{T}) where T <: AbstractSimulationData = true

IteratorInterfaceExtensions.getiterator(sim_def::SimulationDef) = SimIterator{sim_def.nt_type}(sim_def)

column_names(sim_def::SimulationDef{T}) where T <: AbstractSimulationData = fieldnames(sim_def.nt_type)
column_types(sim_def::SimulationDef{T}) where T <: AbstractSimulationData = [eltype(fld) for fld in values(sim_def.rvdict)]

#
# Iteration support (which in turn supports the "save" method)
#
column_names(iter::SimIterator) = column_names(iter.sim_def)
column_types(iter::SimIterator) = error("Not implemented") # Used to be `IterableTables.column_types(iter.sim_def)`

function Base.iterate(iter::SimIterator)
    _reset_rvs!(iter.sim_def)
    idx = 1
    return get_trial(iter.sim_def, idx), idx + 1
end

function Base.iterate(iter::SimIterator, idx)
    if idx > iter.sim_def.trials
        return nothing
    else
        return get_trial(iter.sim_def, idx), idx + 1
    end
end

Base.length(iter::SimIterator) = iter.sim_def.trials

Base.eltype(::Type{SimIterator{NT, T}}) where {NT, T} = NT
