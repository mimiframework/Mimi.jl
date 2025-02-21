function InteractiveUtils.code_warntype(m::Model, comp_id::Symbol)
    if !is_built(m)
        build!(m)
    end

    # println("Running model...")
    mi = modelinstance(m)

    ci = mi.comps_dict[comp_id]

    dimkeys = nothing

    time_keys::Vector{Int} = dimkeys === nothing ? dim_keys(mi.md, :time) : dimkeys[:time]

    ntimesteps = typemax(Int)

    # truncate time_keys if caller so desires
    if ntimesteps < length(time_keys)
        time_keys = time_keys[1:ntimesteps]
    end

    clock = Clock(time_keys)

    dim_val_named_tuple = NamedTuple(name => (name == :time ? timesteps(clock) : collect(values(dim))) for (name, dim) in dim_dict(mi.md))

    t = get_shifted_ts(ci, clock.ts)

    type_vars = typeof(variables(ci))
    type_pars = typeof(parameters(ci))
    type_dims = typeof(dim_val_named_tuple)
    type_timestep = typeof(t)

    InteractiveUtils.code_warntype(ci.run_timestep, (type_vars, type_pars, type_dims, type_timestep))
end
