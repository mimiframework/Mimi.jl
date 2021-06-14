using Mimi
using Distributions
using Test

include("test-model/test-model.jl")
using .TestModel

m = create_model()
mm1 = create_marginal_model(create_model())
mm2 = create_marginal_model(create_model())

simdef = @defsim begin
    grosseconomy.share = Uniform(0, 1)
    save(emissions.E_Global)
end

# Test running one MarginalModel

function post_trial1(si, trialnum, ntimesteps, tup)
    @test length(si.models) == 1
    @test si.models[1] isa MarginalModel
end

si = run(simdef, mm1, 2, post_trial_func = post_trial1, results_in_memory = true)
@test all(iszero, si.results[1][:emissions, :E_Global][!, :E_Global])   # Test that the marginal emission saved from the MarginalModel are zeros (because there's no difference between mm.base and mm.modified)

# Test running a vector of MarginalModels

function post_trial2(si, trialnum, ntimesteps, tup)
    @test length(si.models) == 2
    @test si.models[1] isa MarginalModel
    @test si.models[2] isa MarginalModel
end

si = run(simdef, [mm1, mm2], 2, post_trial_func = post_trial2, results_in_memory = true)
@test all(iszero, si.results[1][:emissions, :E_Global][!, :E_Global])  # Test that the regular model has non-zero emissions
@test all(iszero, si.results[2][:emissions, :E_Global][!, :E_Global])   # Test that the marginal emission saved from the MarginalModel are zeros (because there's no difference between mm.base and mm.modified)


# Test running a vector of a Model and a MarginalModel

function post_trial3(si, trialnum, ntimesteps, tup)
    @test length(si.models) == 2
    @test si.models[1] isa Model
    @test si.models[2] isa MarginalModel
end

si = run(simdef, [m, mm1], 2, post_trial_func = post_trial3, results_in_memory = true)
@test all(!iszero, si.results[1][:emissions, :E_Global][!, :E_Global])  # Test that the regular model has non-zero emissions
@test all(iszero, si.results[2][:emissions, :E_Global][!, :E_Global])   # Test that the marginal emission saved from the MarginalModel are zeros (because there's no difference between mm.base and mm.modified)
