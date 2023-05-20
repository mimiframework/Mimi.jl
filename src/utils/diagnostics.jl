function find_type_instabilities(m, comp, tool=InteractiveUtils.code_warntype)
    m.mi===nothing && error("Model must be built.")
    
    mi = m.mi

    time_keys::Vector{Int} = dim_keys(mi.md, :time)
    clock = Clock(time_keys)

    dim_dict = getproperty(mi.comps_dict[comp].comp_id.module_obj, mi.comps_dict[comp].comp_id.comp_name).dim_dict

    f = mi.comps_dict[comp].run_timestep
    v = typeof(mi.comps_dict[comp].variables)
    p = typeof(mi.comps_dict[comp].parameters)    
    d = typeof(NamedTuple(name => (name == :time ? timesteps(clock) : collect(values(dim))) for (name, dim) in dim_dict))

    tool(f, (p, v, d, Int))
end
