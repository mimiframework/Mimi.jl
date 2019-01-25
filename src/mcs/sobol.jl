using DataStructures
import SALib

mutable struct SobolData <: AbstractSimulationData
    calc_second_order::Bool
    N::Int 

    function SobolData(;calc_second_order = false, N = 1000)
        return new(calc_second_order, N)
    end
end

function Base.show(data::SobolData)
    println("N: $(data.N)")
    println("Calc 2nd order: $(data.calc_second_order)")
end

const SobolSimulation = Simulation{SobolData}

function sample!(sim::SobolSimulation)

    rvdict = sim.rvdict
    rvlist = sim.dist_rvs
    
    # get the samples
    payload = create_SALib_payload(sim)
    samples = SALib.sample(payload)

    for (i, rv) in enumerate(rvlist)
        dist = rv.dist
        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values))
    end
end

function analyze(sim::SobolSimulation, model_output::AbstractArray{<:Number, N}) where N
    payload = create_SALib_payload(sim)
    return SALib.analyze(payload, model_output)
end

function create_SALib_payload(sim::SobolSimulation)

    rvlist = sim.dist_rvs

    # add all distinct rvs to the rv_info dictionary to be passed to SALib's 
    # SobolData payload
    rv_info = OrderedDict{Symbol, Any}(rvlist[1].name => rvlist[1].dist)
    for rv in rvlist[2:end] 
        rv_info[rv.name] = rv.dist
    end

    #create payload
    return SALib.SobolData(params = rv_info, calc_second_order = sim.data.calc_second_order, N = sim.data.N)
    
end
