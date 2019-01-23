# Rough draft for Lisa to complete
mutable struct SobolData <: AbstractSimulationData
    N::Int
    calc_second_order::Bool
end

function Base.show(data::SobolData)
    println("N: $(data.N)")
    println("Calc 2nd order: $(data.calc_second_order)")
end

const SobolSimulation = Simulation{SobolData}

function sample!(sim::SobolSimulation)
    trials = sim.trials
    # do whatever
end

function analyze(sim::SobolSimulation)
end