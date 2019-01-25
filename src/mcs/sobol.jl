using DataStructures

mutable struct SobolData <: AbstractSimulationData
    params::Union{OrderedDict{Symbol, <:Any}, Nothing} # TODO: want {Symbol, <:Distribution}
    calc_second_order::Bool
    N::Int 
    results::Union{Dict{}, Nothing}

    function SobolData(;params = nothing, calc_second_order = false, N = 1000, results = nothing)
        return new(params, calc_second_order, N, results)
    end
end

function Base.show(data::SobolData)
    println("N: $(data.N)")
    println("Calc 2nd order: $(data.calc_second_order)")
    println("Params: $(data.params)")
end

const SobolSimulation = Simulation{SobolData}

function sample!(sim::SobolSimulation)
    trials = sim.trials
    rvdict = sim.rvdict
    num_rvs = length(rvdict)
    rvlist = sim.dist_rvs

    # add all distinct rvs to the SobolData params dictionary
    for (i, rv) in enumerate(rvlist)
        if sim.data.params == nothing 
            sim.data.params = OrderedDict(rv.name => rv.dist)
        else
            sim.data.params[rv.name] = rv.dist
        end
    end

    # get the samples
    SALib_data = SALib.SobolData(sim.data.params, sim.data.calc_second_order, sim.data.N, sim.data.results)
    samples = SALib.sample(SALib_data)

    for (i, rv) in enumerate(rvlist)
        dist = rv.dist
        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values))
    end
end

function analyze!(sim::SobolSimulation)
    # TODO
end
