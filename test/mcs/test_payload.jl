@testitem "payload" begin
    @defcomp c begin
    end

    m = Model()
    set_dimension!(m, :time, 1:2)
    add_comp!(m, c)

    function post_trial(sim_inst::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Union{Nothing, Tuple})
        data = Mimi.payload(sim_inst)
        data[trialnum] = trialnum
    end

    sim_def = @defsim begin
    end

    trials = 10

    original_payload = zeros(trials)
    Mimi.set_payload!(sim_def, original_payload)

    sim_inst = run(sim_def, m, trials, post_trial_func = post_trial)

    @test Mimi.payload(sim_def) == original_payload   # in the original defintion, it's still zeros
    @test Mimi.payload(sim_inst) == collect(1:trials) # in the instance, it's now 1:10
    @test Mimi.payload(sim_inst.sim_def) == original_payload  # the definition stored in the instance still holds the unmodified payload object
end
