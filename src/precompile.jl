using PrecompileTools

#
# Components used only by the precompile workload below.
#
# These are defined at module scope (rather than inside `@compile_workload`,
# which wraps its body in a `let` block) for the same reason the built-in
# components in `components/` are: `@defcomp` needs to define its
# `run_timestep_Mimi_*` function in a module.
#
# Between them they cover the shapes that matter for the build pipeline: a
# second (non-time) dimension, a scalar parameter, 1-D and 2-D time-indexed
# arrays, a variable read back as a parameter by a downstream component, and an
# `init` function.
#
@defcomp _PrecompileEconomy begin
    regions = Index()

    YGROSS  = Variable(index=[time, regions])
    K       = Variable(index=[time, regions])
    l       = Parameter(index=[time, regions])
    tfp     = Parameter(index=[time, regions])
    depk    = Parameter(index=[regions])
    k0      = Parameter(index=[regions])
    share   = Parameter()

    function init(p, v, d)
        nothing
    end

    function run_timestep(p, v, d, t)
        for r in d.regions
            if is_first(t)
                v.K[t, r] = p.k0[r]
            else
                v.K[t, r] = (1 - p.depk[r]) * v.K[t-1, r]
            end
        end

        for r in d.regions
            v.YGROSS[t, r] = p.tfp[t, r] * v.K[t, r]^p.share * p.l[t, r]
        end
    end
end

@defcomp _PrecompileEmissions begin
    regions = Index()

    E        = Variable(index=[time, regions])
    E_Global = Variable(index=[time])
    sigma    = Parameter(index=[time, regions])
    YGROSS   = Parameter(index=[time, regions])

    function run_timestep(p, v, d, t)
        for r in d.regions
            v.E[t, r] = p.YGROSS[t, r] * p.sigma[t, r]
        end
        v.E_Global[t] = sum(v.E[t, :])
    end
end

# Build a small two-component model. `years` may be a UnitRange (uniform time,
# giving FixedTimestep) or a Vector (non-uniform, giving VariableTimestep); both
# are exercised below.
function _workload_model(years)
    nsteps = length(years)
    regions = [:R1, :R2]
    nregions = length(regions)

    m = Model()
    set_dimension!(m, :time, years)
    set_dimension!(m, :regions, regions)

    add_comp!(m, _PrecompileEconomy, :economy)
    add_comp!(m, _PrecompileEmissions, :emissions)

    update_param!(m, :economy, :l, ones(nsteps, nregions))
    update_param!(m, :economy, :tfp, ones(nsteps, nregions))
    update_param!(m, :economy, :depk, fill(0.1, nregions))
    update_param!(m, :economy, :k0, fill(100.0, nregions))
    update_param!(m, :economy, :share, 0.3)

    # the shared-parameter path, which is what most models use for inputs that
    # feed more than one component
    add_shared_param!(m, :shared_sigma, ones(nsteps, nregions), dims=[:time, :regions])
    connect_param!(m, :emissions, :sigma, :shared_sigma)

    # an internal (component to component) connection
    connect_param!(m, :emissions, :YGROSS, :economy, :YGROSS)

    return m
end

@compile_workload begin
    # Uniform time dimension: FixedTimestep, the common case.
    m = _workload_model(2000:5:2020)
    run(m)

    m[:emissions, :E]
    m[:emissions, :E_Global]
    dim_keys(m, :time)
    getdataframe(m, :emissions, :E)

    # Re-running after a parameter update goes down the rebuild path.
    update_param!(m, :economy, :share, 0.25)
    run(m)

    # MarginalModel, used by every SCC calculation.
    mm = create_marginal_model(m, 1.0)
    run(mm)
    mm[:emissions, :E_Global]

    # Non-uniform time dimension: VariableTimestep.
    mv = _workload_model([2000, 2005, 2015, 2030])
    run(mv)
    mv[:emissions, :E]

    # Exercise the `precompile_model` path itself, so that model packages calling
    # it in their own workload do not have to compile it first. Reuse a model we
    # have already built rather than a new time horizon, which would pull in a
    # whole extra set of TimestepArray types for no benefit.
    precompile_model(m)
end
