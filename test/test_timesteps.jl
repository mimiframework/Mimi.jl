using Mimi
using Base.Test

# we'll have Bar run from 2000 to 2010
# and Foo from 2005 to 2010

@defcomp Foo begin
    input = Parameter()
    output = Variable(index=[time])
end

function run_timestep(c::Foo, ts::Timestep)
    c.Variables.output[ts] = c.Parameters.input + ts.t
end

@defcomp Bar begin
    input = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Bar, ts::Timestep)
    if gettime(ts) < 2005
        c.Variables.output[ts] = c.Parameters.input[ts]
    else
        c.Variables.output[ts] = c.Parameters.input[ts] * ts.t
    end
end

m = Model()
setindex(m, :time, 2000:2010)
foo = addcomponent(m, Foo, start=2005) #offset for foo
bar = addcomponent(m, Bar)

set_external_parameter(m, :x, 5.)
set_external_parameter(m, :y, collect(1:11))
connectparameter(m, :Foo, :input, :x)
connectparameter(m, :Bar, :input, :y)

run(m)
