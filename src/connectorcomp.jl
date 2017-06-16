using Mimi

@defcomp ConnectorCompA begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output = Variable(index = [time])
end

function run_timestep(s::ConnectorCompA, ts::Timestep)
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

@defcomp ConnectorCompB begin
    regions = Index()
    
    input1 = Parameter(index = [time, regions])
    input2 = Parameter(index = [time, regions])
    output = Variable(index = [time, regions])
end

function run_timestep(s::ConnectorCompB, ts::Timestep)
    p = s.Parameters
    v = s.Variables
    d = s.Dimensions

    for r in d.regions
        if hasvalue(p.input1, ts, r)
            v.output[ts, r] = p.input1[ts, r]
        elseif hasvalue(p.input2, ts, r)
            v.output[ts, r] = p.input2[ts, r]
        else
            error("Neither of the inputs to ConnectorComp have data for the current timestep: $(gettime(ts)).")
        end
    end
end
