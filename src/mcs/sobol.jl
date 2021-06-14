using DataStructures
import GlobalSensitivityAnalysis

mutable struct SobolData <: AbstractSimulationData
    calc_second_order::Bool

    function SobolData(;calc_second_order = true)
        return new(calc_second_order)
    end
end

function Base.show(data::SobolData)
    println("Calc 2nd order: $(data.calc_second_order)")
end

const SobolSimulationDef = SimulationDef{SobolData}
const SobolSimulationInstance = SimulationInstance{SobolData}

function _compute_N(sim_inst::SobolSimulationInstance)
    num_rvs = length(sim_inst.sim_def.rvdict)
    factor = (sim_inst.sim_def.data.calc_second_order ? 2 : 1)
    N = sim_inst.trials / (factor * num_rvs + 2)
    return N
end

function _compute_trials(sim_inst::SobolSimulationInstance, N::Int)
    num_rvs = length(sim_inst.sim_def.rvdict)
    factor = (sim_inst.sim_def.data.calc_second_order ? 2 : 1)
    sim_inst.trials = N * (factor * num_rvs + 2)
end

function create_GSA_payload(sim_inst::SobolSimulationInstance)
    rv_info = OrderedDict{Symbol, Any}([name => _get_dist(rv) for (name, rv) in sim_inst.sim_def.rvdict])

    # back out N
    N = _compute_N(sim_inst)

    # create payload
    return GlobalSensitivityAnalysis.SobolData(params = rv_info, calc_second_order = sim_inst.sim_def.data.calc_second_order, N = N)
end

function sample!(sim_inst::SobolSimulationInstance, samplesize::Int)
    rvdict = sim_inst.sim_def.rvdict
    sim_inst.trials = _compute_trials(sim_inst, samplesize)

    # get the samples to plug in to trials
    payload = create_GSA_payload(sim_inst)
    samples = GlobalSensitivityAnalysis.sample(payload)

    for (i, rv) in enumerate(values(rvdict))
        # use underlying distribution, if known
        orig_dist = _get_dist(rv)

        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values, orig_dist))
    end
end

"""
    analyze(sim_inst::SobolSimulationInstance, model_output::AbstractArray{<:Number, N}; 
            num_resamples::Union{Nothing, Int} = 1_000, conf_level::Union{Nothing, Number} = 0.95, 
            N_override::Union{Nothing, Int}=nothing, progress_meter::Bool = true) where N

Analyze the results for `sim_inst` with intput `model_input` and output `model_output` 
and return sensitivity analysis metrics as defined by GlobalSensitivityAnalysis package and 
type parameterization of the `sim_inst` ie. Sobol Method.
"""
function analyze(sim_inst::SobolSimulationInstance, model_output::AbstractArray{<:Number, N}; 
                num_resamples::Union{Nothing, Int} = 1_000, conf_level::Union{Nothing, Number} = 0.95, 
                N_override::Union{Nothing, Int}=nothing, progress_meter::Bool = true) where N

    if sim_inst.trials == 0
        error("Cannot analyze simulation with 0 trials.")
    end
    
    payload = create_GSA_payload(sim_inst)

    return GlobalSensitivityAnalysis.analyze(payload, model_output; num_resamples = num_resamples, conf_level = conf_level, N_override = N_override, progress_meter = progress_meter)
end
