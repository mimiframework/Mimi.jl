using Mimi

@defcomp ConnectorComp begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output = Variable(index = [time])
end

function run_timestep(s::ConnectorComp, ts::Timestep)
    p = s.Parameters
    v = s.Variables

    if hasvalue(p.input1, ts)
        v.output[ts] = p.input1[ts]
    elseif hasvalue(p.input2, ts)
        v.output[ts] = p.input2[ts]
    else
        error("Neither of the inputs to ConnectorComp have data for the current timestep: $(gettime(ts)).")
    end
end
