@testitem "parallel" begin
    using Distributions
    using DataFrames
    using Random

    # NOTE: nothing here may call `rand` from inside a component, a trial callback or a
    # scenario function. Mimi's own random draws are all made up front by `generate_trials!`,
    # which is what lets a parallel run reproduce a serial one exactly; a model that draws
    # its own random numbers gets an independent stream per worker task, and the equality
    # tests below would then fail intermittently.

    @defcomp par begin
        regions = Index()

        p_scalar = Parameter(default = 5.0)
        p_time   = Parameter(index = [time], default = collect(1.0:20.0))
        p_region = Parameter(index = [regions], default = [1.0, 2.0, 3.0])

        v_time   = Variable(index = [time])
        v_region = Variable(index = [regions])
        v_scalar = Variable()

        function run_timestep(p, v, d, t)
            for r in d.regions
                v.v_region[r] = p.p_region[r] * p.p_scalar
            end
            v.v_time[t] = p.p_scalar * p.p_time[t]
            v.v_scalar  = p.p_scalar
        end
    end

    function make_model()
        m = Model()
        set_dimension!(m, :time, 2015:5:2110)
        set_dimension!(m, :regions, [:R1, :R2, :R3])
        add_comp!(m, par)
        return m
    end

    sd = @defsim begin
        rv(name1) = Normal(1, 0.2)
        rv(name2) = Uniform(0.75, 1.25)

        par.p_scalar = name1
        par.p_time[2015] *= name2
        par.p_region[(R1, R3)] *= Uniform(0.8, 1.2)

        save(par.v_time, par.v_region, par.v_scalar)
    end

    N = 25

    # every file under `dir`, as relative path => contents
    function dir_contents(dir)
        files = Dict{String, Vector{UInt8}}()
        for (root, _, filenames) in walkdir(dir), filename in filenames
            path = joinpath(root, filename)
            files[relpath(path, dir)] = read(path)
        end
        return files
    end

    # Run the same simulation serially and on `ntasks` tasks, from the same seed, and return
    # both simulation instances along with what each wrote to its own output directory.
    function run_both(ntasks::Int; seed::Int = 42, kwargs...)
        serial_dir   = mktempdir()
        parallel_dir = mktempdir()

        Random.seed!(seed)
        serial = run(sd, make_model(), N; results_output_dir = serial_dir, kwargs...)

        Random.seed!(seed)
        parallel = run(sd, make_model(), N; results_output_dir = parallel_dir, ntasks = ntasks, kwargs...)

        return serial, parallel, dir_contents(serial_dir), dir_contents(parallel_dir)
    end

    #
    # A parallel run reproduces a serial one exactly: same values, same row order, both in
    # memory and on disk.
    #
    serial, parallel, serial_files, parallel_files = run_both(4)
    @test serial.results == parallel.results
    @test length(serial_files) == 3
    @test serial_files == parallel_files

    # with an OUTER scenario loop
    outer_scenario(sim_inst, tup) = nothing
    scenario_args = [:scen => [:low, :high], :rate => [0.015, 0.05]]

    serial, parallel, serial_files, parallel_files = run_both(4;
                    scenario_func = outer_scenario, scenario_args = scenario_args)
    @test serial.results == parallel.results
    @test length(serial_files) == 12    # 3 saved data x 4 scenarios
    @test serial_files == parallel_files

    # with an INNER scenario loop, whose scenario_func perturbs the models it is handed and
    # so has to act on each worker's own models
    function inner_scenario(sim_inst, tup)
        update_param!(sim_inst.models[1], :par, :p_scalar, tup[2])
    end

    serial, parallel, serial_files, parallel_files = run_both(4;
                    scenario_func = inner_scenario, scenario_args = scenario_args,
                    scenario_placement = Mimi.INNER)
    @test serial.results == parallel.results
    @test serial_files == parallel_files

    #
    # Results don't depend on how many tasks the trials were spread over, and repeating a
    # parallel run from the same seed gives the same answer again.
    #
    results = map((1, 2, 3, 8, 8)) do ntasks
        Random.seed!(11)
        return run(sd, make_model(), N; ntasks = ntasks).results
    end
    @test all(r -> r == results[1], results)

    # ntasks = :auto changes nothing about the results
    Random.seed!(11)
    @test run(sd, make_model(), N; ntasks = :auto).results == results[1]

    #
    # Trial callbacks run once per trial, and a payload indexed by trial number is filled in
    # exactly as it is in a serial run.
    #
    function post_trial(sim_inst, trialnum, ntimesteps, tup)
        Mimi.payload(sim_inst)[trialnum] = sim_inst.models[1][:par, :v_scalar]
    end

    Mimi.set_payload!(sd, zeros(N))
    Random.seed!(3)
    serial_payload = Mimi.payload(run(sd, make_model(), N; post_trial_func = post_trial))

    Mimi.set_payload!(sd, zeros(N))
    Random.seed!(3)
    parallel_payload = Mimi.payload(run(sd, make_model(), N; post_trial_func = post_trial, ntasks = 4))

    @test all(parallel_payload .!= 0)
    @test serial_payload == parallel_payload
    Mimi.set_payload!(sd, nothing)

    #
    # A MarginalModel is copied as a unit, so its base and modified models stay in step.
    #
    Random.seed!(5)
    serial = run(sd, create_marginal_model(make_model(), 1.0), N)
    Random.seed!(5)
    parallel = run(sd, create_marginal_model(make_model(), 1.0), N; ntasks = 4)
    @test serial.results == parallel.results

    #
    # Results only on disk: memory is cleared as the run goes, and the files still match.
    #
    serial_dir = mktempdir(); parallel_dir = mktempdir()
    Random.seed!(17)
    serial = run(sd, make_model(), N; results_output_dir = serial_dir, results_in_memory = false)
    Random.seed!(17)
    parallel = run(sd, make_model(), N; results_output_dir = parallel_dir,
                    results_in_memory = false, ntasks = 4)
    @test all(isempty, parallel.results)
    @test dir_contents(serial_dir) == dir_contents(parallel_dir)

    #
    # An error thrown from a trial reaches the caller as itself, rather than wrapped in a
    # TaskFailedException, and doesn't leave the run hanging.
    #
    function failing_post_trial(sim_inst, trialnum, ntimesteps, tup)
        trialnum == 13 && error("failure inside trial $trialnum")
        return nothing
    end

    for ntasks in (1, 4)
        @test_throws ErrorException run(sd, make_model(), N;
                                        post_trial_func = failing_post_trial, ntasks = ntasks)
    end

    #
    # ntasks validation
    #
    @test Mimi._resolve_ntasks(:auto, 100) == Threads.nthreads(:default)
    @test Mimi._resolve_ntasks(8, 3) == 3            # never more workers than there are trials
    @test_throws ErrorException Mimi._resolve_ntasks(0, 10)
    @test_throws ErrorException Mimi._resolve_ntasks(-1, 10)
    @test_throws ErrorException Mimi._resolve_ntasks(:whatever, 10)

    #
    # Perturbed parameters are restored to their original values after each trial, rather
    # than each trial's perturbation compounding onto the previous one. Array parameters
    # used to compound, because copying one shared its values with the original.
    #
    Random.seed!(23)
    sim_inst = run(sd, make_model(), N)

    name1_draws = sim_inst.sim_def.rvdict[:name1].dist.values
    name2_draws = sim_inst.sim_def.rvdict[:name2].dist.values

    first_period = filter(row -> row.time == 2015, sim_inst.results[1][(:par, :v_time)])
    sort!(first_period, :trialnum)

    # v_time[2015] = p_scalar * p_time[2015] = name1 * (1.0 * name2)
    @test first_period.v_time ≈ name1_draws .* name2_draws
end
