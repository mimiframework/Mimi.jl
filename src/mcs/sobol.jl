struct SobolData <: AbstractSimulationData
    N::Int
    calc_second_order::Bool
    samples::AbstractArray{<:Number, N} where N

    function SobolData(; N::Int=1000, calc_second_order::Bool=false)
        new(N, calc_second_order)
    end
end

function Base.show(data::SobolData)
    println("N: $(data.N)")
    println("Calc 2nd order: $(data.calc_second_order)")
end

const SobolSimulation = Simulation{SobolData}

function sample!(sim::SobolSimulation)
    sim.trials = size(sim.samples,1)
    rvdict = sim.rvdict
    num_rvs = length(rvdict)
    rvlist = sim.dist_rvs

    for (i, rv) in enumerate(rvlist)
        dist = rv.dist
        name = rv.name
        values = sim.samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values))
    end
end

function analyze(sim::SobolSimulation)
    # analysis done with the SALib.jl repo - we could eventually run that from
    # within Mimi but for now we will just take the outputs of the runs and 
    # manually work with the SALib.jl repo functions
end