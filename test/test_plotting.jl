module TestPlotting

using Mimi
using Test

import Mimi: 
    reset_compdefs

reset_compdefs()

@defcomp LongComponent begin
    x = Parameter(index=[time])
    y = Parameter()
    z = Variable(index=[time])
    
    function run_timestep(p, v, d, ts)
        v.z[ts] = p.x[ts] + p.y
    end
end

@defcomp ShortComponent begin
    a = Parameter()
    b = Variable(index=[time])
    
    function run_timestep(p, v, d, ts)
        v.b[ts] = p.a * ts.t
    end
end

@defcomp ConnectorComponent begin
    input1 = Parameter(index = [time])
    input2 = Parameter(index = [time])
    output =  Variable(index = [time])

    function run_timestep(p, v, d, ts)
        v.output[ts] = p.input2[ts]
    end
end

m = Model()
set_dimension!(m, :time, 2000:3000)
nsteps = Mimi.dim_count(m.md, :time)

add_comp!(m, ShortComponent; first=2100)
add_comp!(m, ConnectorComponent)
add_comp!(m, LongComponent; first=2000)

set_param!(m, :ShortComponent, :a, 2.)
set_param!(m, :LongComponent, :y, 1.)
connect_param!(m, :ConnectorComponent, :input1, :ShortComponent, :b)
set_param!(m, :ConnectorComponent, :input2, zeros(nsteps))
connect_param!(m, :LongComponent, :x, :ConnectorComponent, :output)

run(m)

graph = plot_comp_graph(m)
@test typeof(graph) == Mimi.Compose.Context

end #module