using Mimi
using Test
using DataFrames
using VegaLite
using Electron
using Distributions
using Query
using CSVFiles

import Mimi: 
    _spec_for_sim_item, menu_item_list, getdataframe, get_sim_results

# Get the example
include("mcs/test-model-2/multi-region-model.jl")
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
    save(grosseconomy.K, grosseconomy.YGROSS, grosseconomy.share_var, grosseconomy.depk_var, emissions.E, emissions.E_Global)
end

si = run(sd, m, N)
results_output_dir = tempdir()
si_disk = run(sd, m, N; results_output_dir = results_output_dir, results_in_memory = false)

## 1. Specs and Menu
pairs = [(:grosseconomy, :K), (:grosseconomy, :YGROSS), (:grosseconomy, :share_var), (:grosseconomy, :depk_var), (:emissions, :E), (:emissions, :E_Global)]
for (comp, var) in pairs
    results = get_sim_results(si, comp, var)

    static_spec = _spec_for_sim_item(si, comp, var, results; interactive = false)
    interactive_spec = _spec_for_sim_item(si, comp, var, results)

    name = string(comp, " : ", var)
    @test static_spec["name"] == interactive_spec["name"] == name
end

## 2. Explore
w = explore(si, title="Testing Window")
@test typeof(w) == Electron.Window
close(w)

w = explore(si_disk, title="Testing Window", results_output_dir = results_output_dir)
@test typeof(w) == Electron.Window
close(w)

@test_throws ErrorException w = explore(si_disk) #should error, no in-memory results

## 3. Plots

# trumpet plot
p = Mimi.plot(si, :emissions, :E_Global)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si, :emissions, :E_Global; interactive = true)
@test typeof(p) == VegaLite.VLSpec

p = Mimi.plot(si_disk, :emissions, :E_Global, results_output_dir = results_output_dir)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si_disk, :emissions, :E_Global; interactive = true, results_output_dir = results_output_dir)
@test typeof(p) == VegaLite.VLSpec

@test_throws ErrorException p = Mimi.plot(si_disk, :emissions, :E_Global) #should error, no in-memory results

# mulitrumpet plot
p = Mimi.plot(si, :emissions, :E)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si, :emissions, :E; interactive = true);
@test typeof(p) == VegaLite.VLSpec

p = Mimi.plot(si_disk, :emissions, :E, results_output_dir = results_output_dir)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si_disk, :emissions, :E; interactive = true, results_output_dir = results_output_dir);
@test typeof(p) == VegaLite.VLSpec

# histogram plot
p = Mimi.plot(si, :grosseconomy, :share_var)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si, :grosseconomy, :share_var; interactive = true); # currently just calls static version
@test typeof(p) == VegaLite.VLSpec

p = Mimi.plot(si_disk, :grosseconomy, :share_var; results_output_dir = results_output_dir)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si_disk, :grosseconomy, :share_var; interactive = true, results_output_dir = results_output_dir); # currently just calls static version
@test typeof(p) == VegaLite.VLSpec

# multihistogram plot
p = Mimi.plot(si, :grosseconomy, :depk_var)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si, :grosseconomy, :depk_var; interactive = true); 
@test typeof(p) == VegaLite.VLSpec

p = Mimi.plot(si_disk, :grosseconomy, :depk_var; results_output_dir = results_output_dir)
@test typeof(p) == VegaLite.VLSpec
p = Mimi.plot(si_disk, :grosseconomy, :depk_var; interactive = true, results_output_dir = results_output_dir); 
@test typeof(p) == VegaLite.VLSpec
