using Base.Test
using Mimi

@defcomp Foo begin
	input = Parameter()
	intermed = Variable(index=[time])
end

function timestep(c::Foo, tt::Int)
    c.Variables.intermed[tt] = c.Parameters.input
end

@defcomp Bar begin
	intermed = Parameter(index=[time])
	output = Variable(index=[time])
end

function timestep(c::Bar, tt::Int)
    c.Variables.output[tt] = c.Parameters.intermed[tt]
end

m = Model()
setindex(m, :time, 1)
foo = addcomponent(m, Foo)
bar = addcomponent(m, Bar)

foo[:input] = 3.14
bar[:intermed] = foo[:intermed]

run(m)

@test m[:Bar, :output][1] == 3.14

