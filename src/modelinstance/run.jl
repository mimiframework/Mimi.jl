function run(mi::ModelInstance, ntimesteps, indices_values)
    if length(mi.components) == 0
        error("Cannot run a model with no components.")
    end

    for (name,c) in mi.components
        resetvariables(c)
        init(c)
    end

    components = [x for x in mi.components]
    offsets = mi.offsets
    final_times = mi.final_times

    clock = makeclock(mi, ntimesteps, indices_values)
    duration = getduration(indices_values)
    comp_clocks = [Clock(offsets[i], final_times[i], duration) for i in collect(1:length(components))]

    while !finished(clock)
        for (i, (name, c)) in enumerate(components)
            if gettime(clock) >= offsets[i] && gettime(clock) <= final_times[i]
                run_timestep(c, gettimestep(comp_clocks[i]))
                move_forward(comp_clocks[i])
            end
        end
        move_forward(clock)
    end
end
