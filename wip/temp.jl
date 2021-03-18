using Mimi

@defcomp example begin
    p0 = Parameter(index = [time])
    p1 = Parameter(index = [foo])
    p2 = Parameter(index = [foo, bar])
    p3 = Parameter(index = [foo, baz])
    p4 = Parameter(index = [time, bar])
    p5 = Parameter(index = [time, baz])

    x = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
        v.x[t] = 0
    end
end

m = Model()

set_dimension!(m, :time, 2001:2010)
set_dimension!(m, :foo, 1:5)
set_dimension!(m, :bar, 1:3)
set_dimension!(m, :baz, [:A, :B, :C])

add_comp!(m, example)

set_param!(m, :example, :p0, collect(1:10))
set_param!(m, :example, :p1, collect(1:5))
set_param!(m, :example, :p2, reshape(1:15, 5, 3))
set_param!(m, :example, :p3, reshape(1:15, 5, 3))
set_param!(m, :example, :p4, reshape(1:30, 10, 3))
set_param!(m, :example, :p5, reshape(1:30, 10, 3))
run(m)
explore(m)