@testitem "Explorer Sim" begin
    using DataFrames
    using VegaLite
    using Electron
    using Distributions
    using Query
    using CSVFiles

    import Mimi:
        _spec_for_sim_item, menu_item_list, getdataframe, get_sim_results

    # Helper function returns true if VegaLite is verison 3 or above, and false otherwise
    function _is_VegaLite_v3()
        return isdefined(VegaLite, :vlplot) ? true : false
    end

    # Get the example
    include("mcs/test-model-2/multi-region-model.jl")
    using .MyModel
    m = construct_MyModel()

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

        grosseconomy.depk = [Region1 => Uniform(0.08, 0.14),
                Region2 => Uniform(0.10, 1.50),
                Region3 => Uniform(0.10, 0.20)]

        sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])

        # indicate which parameters to save for each model run. Specify
        # a parameter name or [later] some slice of its data, similar to the
        # assignment of RVs, above.
        save(grosseconomy.K, grosseconomy.YGROSS, grosseconomy.share_var, grosseconomy.depk_var,
            emissions.E, emissions.E_Global)
    end

    si = run(sd, m, N)
    results_output_dir = mktempdir()
    si_disk = run(sd, m, N; results_output_dir = results_output_dir, results_in_memory = false)

    ## 1. Specs and Menu
    pairs = [(:grosseconomy, :K), (:grosseconomy, :YGROSS), (:grosseconomy, :share_var),
            (:grosseconomy, :depk_var), (:emissions, :E), (:emissions, :E_Global)]
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

    w = explore(si_disk, results_output_dir = results_output_dir)
    @test typeof(w) == Electron.Window
    close(w)

    @test_throws ErrorException explore(si_disk) #should error, no in-memory results

    ## 3. Plots

    function plot_type_test(p)
        if _is_VegaLite_v3()
            @test typeof(p) == VegaLite.VLSpec
        else
            @test typeof(p) == VegaLite.VLSpec{:plot}
        end
    end

    # trumpet plot
    p = Mimi.plot(si, :emissions, :E_Global)
    plot_type_test(p)
    p = Mimi.plot(si, :emissions, :E_Global; interactive = true)
    plot_type_test(p)

    p = Mimi.plot(si_disk, :emissions, :E_Global, results_output_dir = results_output_dir)
    plot_type_test(p)
    p = Mimi.plot(si_disk, :emissions, :E_Global; interactive = true, results_output_dir = results_output_dir)
    plot_type_test(p)

    @test_throws ErrorException Mimi.plot(si_disk, :emissions, :E_Global) #should error, no in-memory results

    # mulitrumpet plot
    p = Mimi.plot(si, :emissions, :E)
    plot_type_test(p)
    p = Mimi.plot(si, :emissions, :E; interactive = true);
    plot_type_test(p)

    p = Mimi.plot(si_disk, :emissions, :E, results_output_dir = results_output_dir)
    plot_type_test(p)
    p = Mimi.plot(si_disk, :emissions, :E; interactive = true, results_output_dir = results_output_dir);
    plot_type_test(p)

    # histogram plot
    p = Mimi.plot(si, :grosseconomy, :share_var)
    plot_type_test(p)
    p = Mimi.plot(si, :grosseconomy, :share_var; interactive = true); # currently just calls static version
    plot_type_test(p)

    p = Mimi.plot(si_disk, :grosseconomy, :share_var; results_output_dir = results_output_dir)
    plot_type_test(p)
    p = Mimi.plot(si_disk, :grosseconomy, :share_var; interactive = true, results_output_dir = results_output_dir); # currently just calls static version
    plot_type_test(p)

    # multihistogram plot
    p = Mimi.plot(si, :grosseconomy, :depk_var)
    plot_type_test(p)
    p = Mimi.plot(si, :grosseconomy, :depk_var; interactive = true); 
    plot_type_test(p)

    p = Mimi.plot(si_disk, :grosseconomy, :depk_var; results_output_dir = results_output_dir)
    plot_type_test(p)
    p = Mimi.plot(si_disk, :grosseconomy, :depk_var; interactive = true, results_output_dir = results_output_dir); 
    plot_type_test(p)

    Mimi.close_explore_app()
end
