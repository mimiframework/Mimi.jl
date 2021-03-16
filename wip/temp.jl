using Mimi

@defcomp example begin
    p0 = Parameter(index = [time])
    p1 = Parameter(index = [foo])
    p2 = Parameter(index = [foo, bar])
    p3 = Parameter(index = [foo, baz])
    p4 = Parameter(index = [time, bar])
    p5 = Parameter(index = [time, baz])
end

m = Model()
set_dimension!(m, :time, collect(1:10))
add_comp!(m, example)
set_dimension!(m, :foo, 1:5)
set_dimension!(m, :bar, 1:3)
set_dimension!(m, :baz, [:A, :B, :C])
set_param!(m, :example, :p0, 1:10)
set_param!(m, :example, :p1, 1:5)
set_param!(m, :example, :p2, reshape(1:15, 5, 3))
set_param!(m, :example, :p3, reshape(1:15, 5, 3))
set_param!(m, :example, :p4, reshape(1:30, 10, 3))
set_param!(m, :example, :p5, reshape(1:30, 10, 3))
run(m)
explore(m)