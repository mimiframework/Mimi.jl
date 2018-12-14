using Mimi

@defcomp ConnectorCompVector begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output =  Variable(index = [time])

    first = Parameter() # first year to use the shorter data
    last = Parameter()  # last year to use the shorter data

    function run_timestep(p, v, d, ts)
        if gettime(ts) >= p.first && gettime(ts) <= p.last
            v.output[ts.t] = p.input1[ts.t]
        else
            v.output[ts.t] = p.input2[ts.t]
        end 
    end
end

@defcomp ConnectorCompMatrix begin
    regions = Index()

    input1 = Parameter(index = [time, regions])
    input2 = Parameter(index = [time, regions])
    output =  Variable(index = [time, regions])

    first = Parameter() # first year to use the shorter data
    last = Parameter()  # last year to use the shorter data

    function run_timestep(p, v, d, ts)
        if gettime(ts) >= p.first && gettime(ts) <= p.last 
            v.output[ts.t, :] = p.input1[ts.t, :]
        else
            v.output[ts.t, :] = p.input2[ts.t, :]
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
