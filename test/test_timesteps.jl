# we'll have Bar run from 2000 to 2010
# and Foo from 2005 to 2010

@defcomp Foo begin
    input = Parameter()
    intermed = Variable(index=[time])
end

function run_timestep(c::Foo, ts::Timestep)
    c.Variables.intermed[ts] = c.Parameters.input
end

@defcomp Bar begin
    intermed = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Bar, ts::Timestep)
    if ts.t <= 5
        c.Parameters.intermed[ts] = 1
    else


    c.Variables.output[ts] = c.Parameters.intermed[ts]
end

m = Model()
setindex(m, :time, 2000:2010)
foo = addcomponent(m, Foo, 2005) #offset for foo
bar = addcomponent(m, Bar)

#connectparameter(m, :Bar, :intermed, :Foo, :intermed)

run(m)
