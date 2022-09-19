@testitem "defmcs modifications" begin
    using Distributions
    using Mimi: delete_RV!, delete_transform!, add_RV!, add_transform!, replace_RV!, delete_save!, add_save!, get_simdef_rvnames

    # construct a mcs

    include("test-model-2/multi-region-model.jl")
    using .MyModel

    m = construct_MyModel()
    N = 10
    output_dir = mktempdir()

    sd = @defsim begin

        rv(name1) = Normal(1, 0.2)
        rv(name2) = Uniform(0.75, 1.25)
        rv(name3) = LogNormal(20, 4)

        grosseconomy.share = Uniform(0.2, 0.8)
        emissions.sigma[:, Region1] *= name2
        emissions.sigma[2020:5:2050, (Region2, Region3)] *= Uniform(0.8, 1.2)

        grosseconomy.depk = [Region1 => Uniform(0.08, 0.14),
                Region2 => Uniform(0.10, 1.50),
                Region3 => Uniform(0.10, 0.20)]

        sampling(LHSData, corrlist=[(:name1, :name2, 0.7), (:name1, :name3, 0.5)])
        
        save(grosseconomy.K, grosseconomy.YGROSS, emissions.E, emissions.E_Global, grosseconomy.share_var, grosseconomy.depk_var)
    end

    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # test modification functions

    # add_RV!
    @test_throws ErrorException add_RV!(sd, :name1, Normal(1,0))
    add_RV!(sd, :new_RV, Normal(0, 1))
    @test sd.rvdict[:new_RV].dist == Normal(0, 1)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # replace_RV!
    @test_throws ErrorException replace_RV!(sd, :missing_RV, Uniform(0, 1))
    replace_RV!(sd, :new_RV, Uniform(0, 1))
    @test sd.rvdict[:new_RV].dist == Uniform(0, 1)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # delete_RV! (calls delete_transform!)
    @test_logs (:warn, "Simulation def does not have RV :missing_RV. Nothing being deleted.")  delete_RV!(sd, :missing_RV)
    delete_RV!(sd, :new_RV)
    @test !haskey(sd.rvdict, :new_RV)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # delete_save! and add_save!
    @test_logs (:warn, "Simulation def doesn't have (:comp, :param) in its save list. Nothing being deleted.") delete_save!(sd, :comp, :param)
    delete_save!(sd, :grosseconomy, :K)
    pos = pos = findall(isequal((:grosseconomy, :K)), sd.savelist)
    @test isempty(pos)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    @test_logs (:warn, "Simulation def already has (:emissions, :E) in its save list. Nothing being added.") add_save!(sd, :emissions, :E) 
    add_save!(sd, :grosseconomy, :K)
    pos = findall(isequal((:grosseconomy, :K)), sd.savelist)
    @test length(pos) == 1
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # add_transform!
    rvs = get_simdef_rvnames(sd, :share)
    delete_RV!(sd, rvs[1])
    add_RV!(sd, :new_RV, Uniform(0.2, 0.8))
    add_transform!(sd, :grosseconomy, :share, :(=), :new_RV)
    @test :new_RV in map(i->i.rvname, sd.translist)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    delete_RV!(sd, :new_RV)
    add_RV!(sd, :new_RV, Uniform(0.2, 0.8))
    add_transform!(sd, :grosseconomy, :share, :(=), :new_RV) # should work with the component name too even though it is shared
    @test :new_RV in map(i->i.rvname, sd.translist)
    run(sd, m, N; trials_output_filename = joinpath(output_dir, "trialdata.csv"), results_output_dir=output_dir)

    # get_simdef_rvnames
    rvs = get_simdef_rvnames(sd, :depk)
    @test length(rvs) == 3
end
