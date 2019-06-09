using DataStructures
import GlobalSensitivityAnalysis

mutable struct SobolData <: AbstractSimulationData
    calc_second_order::Bool

    function SobolData(;calc_second_order = false)
        return new(calc_second_order)
    end
end

function Base.show(data::SobolData)
    println("Calc 2nd order: $(data.calc_second_order)")
end

const SobolSimulation = Simulation{SobolData}
const SobolResults = SimulationResults{SobolData}

function _compute_N(sim::SobolSimulation)
    num_rvs = length(sim.rvdict)
    factor = (sim.data.calc_second_order ? 2 : 1)
    N = sim.trials / (factor * num_rvs + 2)
    return N
end

function _compute_trials(sim::SobolSimulation, N::Int)
    num_rvs = length(sim.rvdict)
    factor = (sim.data.calc_second_order ? 2 : 1)
    sim.trials = N * (factor * num_rvs + 2)
end

# Use original distribution when resampling from SampleStore
_get_dist(rv::RandomVariable) = (rv.dist isa SampleStore ? rv.dist.dist : rv.dist)

function sample!(sim::SobolSimulation, samplesize::Int)
    rvdict = sim.rvdict
    sim.trials = _compute_trials(sim, samplesize)

    # get the samples to plug in to trials
    payload = create_GSA_payload(sim)
    samples = GlobalSensitivityAnalysis.sample(payload)

    for (i, rv) in enumerate(values(rvdict))
        # use underlying distribution, if known
        orig_dist = _get_dist(rv)

        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values, orig_dist))
    end
end

function analyze(sim_results::SobolResults, model_output::AbstractArray{<:Number, N}) where N

    if sim_results.sim.trials == 0
        error("Cannot analyze simulation with 0 trials.")
    end
    
    payload = create_GSA_payload(sim_results.sim)
    return GlobalSensitivityAnalysis.analyze(payload, model_output)
end

function create_GSA_payload(sim::SobolSimulation)
    rv_info = OrderedDict{Symbol, Any}([name => _get_dist(rv) for (name, rv) in sim.rvdict])

    # back out N
    N = _compute_N(sim)

    # create payload
    return GlobalSensitivityAnalysis.SobolData(params = rv_info, calc_second_order = sim.data.calc_second_order, N = N)
end
