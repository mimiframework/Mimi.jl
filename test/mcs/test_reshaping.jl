using Mimi
using Distributions
using Query
using DataFrames
using IterTools
using DelimitedFiles

using Test

using Mimi: modelinstance, compinstance, get_var_value, OUTER, INNER, ReshapedDistribution

include("test-model/test-model.jl")
using .TestModel
m = create_model()

N = 100

sd = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an model parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # assign RVs to model Parameters
    grosseconomy.share = Uniform(0.2, 0.8)
    emissions.sigma[:, Region1] *= name2
    emissions.sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    grosseconomy.tester = ReshapedDistribution([20, 3], Dirichlet(20*3, 1))

    grosseconomy.depk = [Region1 => Uniform(0.08, 0.14),
            Region2 => Uniform(0.10, 1.50),
            Region3 => Uniform(0.10, 0.20)]

    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

output_dir = joinpath(tempdir(), "mcs")
si = run(sd, m, N; results_output_dir = output_dir, trials_output_filename = joinpath(output_dir, "trialdata.csv"))

d = readdlm(joinpath(output_dir, "trialdata.csv"), ',')
@test size(d)[1] == N+1 # extra row for column names
