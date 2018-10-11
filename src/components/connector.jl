using Mimi

@defcomp ConnectorCompVector begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output =  Variable(index = [time])

    function run_timestep(p, v, d, ts)
        if !ismissing(p.input1[ts])
            v.output[ts] = p.input1[ts]
        elseif !ismissing(p.input2[ts])
            v.output[ts] = p.input2[ts]
        else
            error("Neither of the inputs to ConnectorCompVector have data for the current timestep: $(gettime(ts)).")
        end
    end
end

@defcomp ConnectorCompMatrix begin
    regions = Index()

    input1 = Parameter(index = [time, regions])
    input2 = Parameter(index = [time, regions])
    output =  Variable(index = [time, regions])

    function run_timestep(p, v, d, ts)
        for r in d.regions
            if !ismissing(p.input1[ts, r])
                v.output[ts, r] = p.input1[ts, r]
            elseif !ismissing(p.input2[ts, r])
                v.output[ts, r] = p.input2[ts, r]
            else
                error("Neither of the inputs to ConnectorCompMatrix have data for the current timestep: $(gettime(ts)).")
            end
        end
    end
end

#
# TBD: define a version with arbitrary dimensions. The problem currently
# is that we have no way to indicate a Parameter with an indeterminate
# dimensions.
#
# @defcomp ConnectorComp begin
#     input1 = Parameter(index = [time, ...])
#     input2 = Parameter(index = [time, ...])
#     output =  Variable(index = [time, ...])

#     # Allow copying of vars/params with arbitrary dimensions
#     function run_timestep(p, v, d, ts)
#         colons = repeat([:], inner=ndims(v.output) - 1)
#         if hasvalue(p.input1, ts)
#             v.output[ts, colons...] = p.input1[ts, colons...]
#         elseif hasvalue(p.input2, ts)
#             v.output[ts, colons...] = p.input2[ts, colons...]
#         else
#             error("Neither of the inputs to ConnectorComp have data for the current timestep: $(gettime(ts)).")
#         end
#     end
# end
