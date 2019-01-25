using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles
using CSVFiles

using Test

include("../../wip/get_SALib.jl")
get_SALib("/Users/lisarennels/.julia/dev/Mimi/test/mcs", "/Users/lisarennels/JuliaProjects/SAJulia/src")
using Main.SALib

N = 100

sim = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Uniform(0, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = Uniform(4, 20)

    # assign RVs to model Parameters
    share = name1
    sigma[:, Region1] *= name2
    sigma[2020:5:2050, (Region2, Region3)] = name3

    depk = [Region1 => name1,
            Region2 => name3,
            Region3 => name2]

    sampling(SobolData, N = N)
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

Mimi.reset_compdefs()
include("../../examples/tutorial/02-two-region-model/main.jl")

m = model

output_dir = "/Users/lisarennels/.julia/dev/Mimi/test/mcs/sim"
generate_trials!(sim, N, filename=joinpath(output_dir, "trialdata.csv")) 

run_sim(sim, m, sim.trials, output_dir=output_dir)

model_output = load("/Users/lisarennels/.julia/dev/Mimi/test/mcs/sim/E.csv") |> DataFrame
model_output = model_output[1:60:end, 3]

results = analyze(sim, model_output)
