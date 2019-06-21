cd("/Users/lisarennels/.julia/dev/Mimi/test/")

using Mimi
using Test
using DataFrames
using VegaLite
using Electron
using Distributions
using Query
using CSVFiles

# Get the example
include("../examples/tutorial/02-two-region-model/two-region-model.jl")
using .MyModel
m = construct_MyModel()

N = 100

sd = @defsim begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(1, 0.2)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # assign RVs to model Parameters
    share = Uniform(0.2, 0.8)
    sigma[:, Region1] *= name2
    sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

    depk = [Region1 => Uniform(0.08, 0.14),
            Region2 => Uniform(0.10, 1.50),
            Region3 => Uniform(0.10, 0.20)]

    sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])
    
    # indicate which parameters to save for each model run. Specify
    # a parameter name or [later] some slice of its data, similar to the
    # assignment of RVs, above.
    save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global)
end

si = run(sd, m, N)

## 1. Full Specs for VegaLite
# TODO: createspec_singletrumpet, createspec_singletrumpet_static, 
# createspec_singletrumpet_interactive, createspec_multitrumpet, 
# createspec_multitrumpet_interactive, createspec_multitrumpet_static, 
# createspec_histogram, createspec_multihistogram

## 2. Explore

w = explore(si, title="Testing Window")
@test typeof(w) == Electron.Window
close(w)

## 3. Plots

# trumpet plot
p = Mimi.plot(si, :emissions, :E_Global)
@test typeof(p) == VegaLite.VLSpec{:plot}

# mulitrumpet plot
p = Mimi.plot(si, :emissions, :E)
@test typeof(p) == VegaLite.VLSpec{:plot}
