module TestReferences

using Test
using Mimi

@defcomp Foo begin
    input = Parameter()
    intermed = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
        v.intermed[t] = p.input
    end
end
    
@defcomp Bar begin
    intermed = Parameter(index=[time])
    output = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
        v.output[t] = p.intermed[t]
    end
end

@Mimi.defmodel m begin
    index[time] = [1]
    component(Foo)
    component(Bar)

    Foo.input = 3.14
    Foo.intermed => Bar.intermed
end

run(m)

@test m[:Bar, :output][1] == 3.14

end