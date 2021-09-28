using Mimi

@defcomp ConnectorCompVector begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output =  Variable(index = [time])

    first = Parameter() # first year to use the shorter data
    last = Parameter()  # last year to use the shorter data

    function run_timestep(p, v, d, t)
        if gettime(t) >= p.first && gettime(t) <= p.last
            input = p.input1
        else
            input = p.input2
        end 

        v.output[t] = @allow_missing(input[t])
        
    end
end

@defcomp ConnectorCompMatrix begin
    ConnectorCompMatrix_Dim2 = Index()

    input1 = Parameter(index = [time, ConnectorCompMatrix_Dim2])
    input2 = Parameter(index = [time, ConnectorCompMatrix_Dim2])
    output =  Variable(index = [time, ConnectorCompMatrix_Dim2])

    first = Parameter() # first year to use the shorter data
    last = Parameter()  # last year to use the shorter data

    function run_timestep(p, v, d, t)

        if gettime(t) >= p.first && gettime(t) <= p.last
            input = p.input1
        else
            input = p.input2
        end 

        for r in d.ConnectorCompMatrix_Dim2
            v.output[t, r] = @allow_missing(input[t, r])
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
#     function run_timestep(p, v, d, t)
#         colons = repeat([:], inner=ndims(v.output) - 1)
#         if hasvalue(p.input1, t)
#             v.output[t, colons...] = p.input1[t, colons...]
#         elseif hasvalue(p.input2, t)
#             v.output[t, colons...] = p.input2[t, colons...]
#         else
#             error("Neither of the inputs to ConnectorComp have data for the current timestep: $(gettime(t)).")
#         end
#     end
# end
