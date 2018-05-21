using Base.Test
using Mimi
using Plots

include("../src/utils/plotting.jl")

@test Mimi.prettify("camelCaseBasic") == "Camel Case Basic"
@test Mimi.prettify("camelWithAOneLetterWord") == "Camel With A One Letter Word"
@test Mimi.prettify("snake_case_basic") == "Snake Case Basic"
@test Mimi.prettify("_snake__case__weird_") == "Snake Case Weird"

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

m = Model()
set_dimension!(m, :time, 2)
foo = addcomponent(m, Foo)
bar = addcomponent(m, Bar)

foo[:input] = 3.14
bar[:intermed] = foo[:intermed]
#connectparameter(m, :Bar, :intermed, :Foo, :intermed)

run(m)

Plots.plot(m, :Bar, :output)
