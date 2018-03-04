include("mcs_types.jl")
include("defmcs.jl")
include("EmpiricalDistribution.jl")
include("lhs.jl")
include("montecarlo.jl")

export 
    @defmcs, generate_trials!, get_random_variable, lhs, lhs_amend!, run_mcs, save_trial_inputs, save_trial_results,
    AbstractRandomVariable, RandomVariable, TransformSpec, CorrelationSpec, MonteCarloSimulation
