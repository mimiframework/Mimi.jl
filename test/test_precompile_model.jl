@testitem "PrecompileModel" begin
    @defcomp PCsource begin
        regions = Index()

        out    = Variable(index=[time, regions])
        scalar = Variable()
        inp    = Parameter(index=[time, regions])
        factor = Parameter()

        function init(p, v, d)
            v.scalar = 0.0
        end

        function run_timestep(p, v, d, t)
            for r in d.regions
                v.out[t, r] = p.inp[t, r] * p.factor
            end
        end
    end

    @defcomp PCsink begin
        regions = Index()

        total = Variable(index=[time])
        inp   = Parameter(index=[time, regions])

        function run_timestep(p, v, d, t)
            v.total[t] = sum(p.inp[t, :])
        end
    end

    function build_model(years; sink_first = nothing)
        nsteps, nregions = length(years), 2
        m = Model()
        set_dimension!(m, :time, years)
        set_dimension!(m, :regions, [:R1, :R2])
        add_comp!(m, PCsource, :source)
        add_comp!(m, PCsink, :sink, first = sink_first)
        update_param!(m, :source, :inp, ones(nsteps, nregions))
        update_param!(m, :source, :factor, 2.0)
        connect_param!(m, :sink, :inp, :source, :out)
        return m
    end

    nspecs(f) = count(!isnothing, Base.specializations(only(methods(f))))
    compinst(m, name) = only([c for c in Mimi.components(Mimi.modelinstance(m)) if c.comp_name == name])

    # Two functions for :source (it defines both init and run_timestep) and one
    # for :sink, which defines only run_timestep.
    m = build_model(2000:2005)
    @test Mimi.precompile_model(m) == 3

    # Building is implicit when the model has not been built yet.
    @test Mimi.is_built(m)

    # Each component's function now has a specialization, without having run.
    source, sink = compinst(m, :source), compinst(m, :sink)
    @test nspecs(source.run_timestep) > 0
    @test nspecs(source.init) > 0
    @test nspecs(sink.run_timestep) > 0
    @test sink.init === nothing

    # Precompiling must not perturb the model: running afterwards still works and
    # gives the same answer as a model that was never precompiled.
    run(m)
    reference = build_model(2000:2005)
    run(reference)
    @test m[:sink, :total] == reference[:sink, :total]
    @test all(m[:sink, :total] .== 4.0)

    # A component placed with `first` gets a shifted timestep, which must not
    # throw when we reconstruct its signature.
    @test Mimi.precompile_model(build_model(2000:2005, sink_first = 2002)) == 3

    # Non-uniform time, i.e. VariableTimestep rather than FixedTimestep.
    @test Mimi.precompile_model(build_model([2000, 2005, 2015])) == 3

    # MarginalModel covers both of its inner models.
    mm = Mimi.create_marginal_model(build_model(2000:2005), 1.0)
    @test Mimi.precompile_model(mm) == 6
end

@testitem "PrecompileModel composite" begin
    @defcomp PCleaf begin
        v1 = Variable(index=[time])
        p1 = Parameter(index=[time])

        function run_timestep(p, v, d, t)
            v.v1[t] = p.p1[t]
        end
    end

    @defcomposite PCcomposite begin
        Component(PCleaf)

        p1 = Parameter(PCleaf.p1)
    end

    m = Model()
    set_dimension!(m, :time, 2000:2005)
    add_comp!(m, PCcomposite, :composite)
    update_param!(m, :composite, :p1, collect(1.0:6.0))

    # The leaf inside the composite is reached by recursing, exactly as the run
    # loop does; the composite itself has no run_timestep of its own.
    @test Mimi.precompile_model(m) == 1

    leaf = only(Mimi.components(only(Mimi.components(Mimi.modelinstance(m)))))
    @test count(!isnothing, Base.specializations(only(methods(leaf.run_timestep)))) > 0

    run(m)
    @test Mimi._get_datum(leaf, :v1) == collect(1.0:6.0)
end
