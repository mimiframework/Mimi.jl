using DataStructures
import GlobalSensitivityAnalysis

mutable struct DeltaData <: AbstractSimulationData

    function DeltaData()
        return new()
    end
end

const DeltaSimulationDef = SimulationDef{DeltaData}
const DeltaSimulationInstance = SimulationInstance{DeltaData}

function create_GSA_payload(sim_inst::DeltaSimulationInstance)
    rv_info = OrderedDict{Symbol, Any}([name => _get_dist(rv) for (name, rv) in sim_inst.sim_def.rvdict])

    # create payload
    return GlobalSensitivityAnalysis.DeltaData(params = rv_info, N = sim_inst.trials)
end

function sample!(sim_inst::DeltaSimulationInstance, samplesize::Int)
    rvdict = sim_inst.sim_def.rvdict
    sim_inst.trials = samplesize

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
    analyze(sim_inst::DeltaSimulationInstance, model_input::AbstractArray{<:Number, N1}, 
            model_output::AbstractArray{<:Number, N2}; num_resamples::Int = 1_000, 
            conf_level::Number = 0.95, N_override::Union{Nothing, Int}=nothing, 
            progress_meter::Bool = true) where {N1, N2}

Analyze the results for `sim_inst` with intput `model_input` and output `model_output` 
and return sensitivity analysis metrics as defined by GlobalSensitivityAnalysis package and 
type parameterization of the `sim_inst` ie. Delta Method.
"""
function analyze(sim_inst::DeltaSimulationInstance, model_input::AbstractArray{<:Number, N1}, 
                model_output::AbstractArray{<:Number, N2}; num_resamples::Int = 1_000, 
                conf_level::Number = 0.95, N_override::Union{Nothing, Int}=nothing, 
                progress_meter::Bool = true) where {N1, N2}

    if sim_inst.trials == 0
        error("Cannot analyze simulation with 0 trials.")
    end
    
    payload = create_GSA_payload(sim_inst)

    return GlobalSensitivityAnalysis.analyze(payload, model_input, model_output; num_resamples = num_resamples, conf_level = conf_level, N_override = N_override, progress_meter = progress_meter)
end

