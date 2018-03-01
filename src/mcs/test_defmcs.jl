using Mimi
using Distributions

include("examples/tutorial/02-two-region-model/main.jl")

m = tworegion.my_model

mcs = @defmcs begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # define correlations
    name1:name2 = 0.7
    name1:name3 = 0.5

    # assign RVs to model Parameters
    share = Uniform(0.2, 0.8)
    sigma[1:end, 1:end] *= name2

    # indicate which parameters to save for each model run. Specify
    # a parameter name or some slice of its data, similar to the
    # assignment of RVs, above.
    save(share, sigma, E_Global)        # TBD: need to as specify (comp_name.datum_name, ...)
end

generate_trials!(mcs, 20, filename="/tmp/trialdata.csv")
run_mcs(m, mcs, 4)
