module TestPlotting

using Mimi
using Test

using Mimi: plot_comp_graph

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

m = Model()
set_dimension!(m, :time, 2000:3000)
nsteps = Mimi.dim_count(m.md, :time)

add_comp!(m, ShortComponent) #; first=2100)
add_comp!(m, LongComponent) #; first=2000)

set_param!(m, :ShortComponent, :a, 2.)
set_param!(m, :LongComponent, :y, 1.)
connect_param!(m, :LongComponent, :x, :ShortComponent, :b, zeros(nsteps))

run(m)

graph = plot_comp_graph(m)
@test typeof(graph) == Mimi.Compose.Context

end #module