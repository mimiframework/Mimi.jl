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

function sample!(sim::SobolSimulation, samplesize::Int)

    rvdict = sim.rvdict
    rvlist = sim.dist_rvs
    num_rvs = length(rvdict)

    if sim.data.calc_second_order
        sim.trials = samplesize * (2 * num_rvs + 2)
    else
        sim.trials = samplesize * (num_rvs + 2)
    end

    # get the samples to plug in to trials
    payload = create_GSA_payload(sim)
    samples = GlobalSensitivityAnalysis.sample(payload)

    for (i, rv) in enumerate(rvlist)
        dist = rv.dist
        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values))
    end
end

function analyze(sim::SobolSimulation, model_output::AbstractArray{<:Number, N1}; N::Union{Nothing, Int}=nothing) where N1
    if N != nothing
        sim.data.calc_second_order ? factor = 2 * length(sim.rvdict) : factor = length(sim.rvdict)
        sim.trials = N * (factor + 2)
    end

    if sim.trials == 0
        error("Cannot analyze simulation with 0 trials (sim.trials == 0), either run generate_trials to set N, or pass N to analyze function as a keyword argument")
    end
    
    payload = create_GSA_payload(sim)
    return GlobalSensitivityAnalysis.analyze(payload, model_output)
end

function create_GSA_payload(sim::SobolSimulation)

    rvlist = sim.dist_rvs

    # add all distinct rvs to the rv_info dictionary to be passed to GSA's 
    # SobolData payload
    rv_info = OrderedDict{Symbol, Any}(rvlist[1].name => rvlist[1].dist)
    for rv in rvlist[2:end] 
        rv_info[rv.name] = rv.dist
    end

    # back out N
    num_rvs = length(sim.rvdict)
    if sim.data.calc_second_order
        samples = sim.trials / (2 * num_rvs + 2)
    else
        samples = sim.trials / (num_rvs + 2)
    end

    # create payload
    return GlobalSensitivityAnalysis.SobolData(params = rv_info, calc_second_order = sim.data.calc_second_order, N = samples)
    
end
