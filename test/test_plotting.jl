using Mimi

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

add_comp!(m, ShortComponent; first=2100)
add_comp!(m, ConnectorCompVector, :MyConnector) # can give it your own name
add_comp!(m, LongComponent; first=2000)

set_param!(m, :ShortComponent, :a, 2.)
set_param!(m, :LongComponent, :y, 1.)
connect_param!(m, :MyConnector, :input1, :ShortComponent, :b)
set_param!(m, :MyConnector, :input2, zeros(nsteps))
connect_param!(m, :LongComponent, :x, :MyConnector, :output)

run(m)

plot_comp_graph(m)
