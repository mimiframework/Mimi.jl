# Rough draft for Lisa to complete
struct SobolData <: AbstractSimulationData
    N::Int
    calc_second_order::Bool

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
    # sim.trials = N * whatever...
end

function analyze(sim::SobolSimulation)
end