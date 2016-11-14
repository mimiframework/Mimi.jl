using Base.Test
using Mimi
using Plots

@test Mimi.prettifystring("camelCaseBasic") == "Camel Case Basic"
@test Mimi.prettifystring("camelWithAOneLetterWord") == "Camel With A One Letter Word"
@test Mimi.prettifystring("snake_case_basic") == "Snake Case Basic"
@test Mimi.prettifystring("_snake__case__weird_") == "Snake Case Weird"

@defcomp Foo begin
    input = Parameter()
    intermed = Variable(index=[time])
end

function run_timestep(c::Foo, tt)
    c.Variables.intermed[tt] = c.Parameters.input
end

@defcomp Bar begin
    intermed = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(c::Bar, tt)
    c.Variables.output[tt] = c.Parameters.intermed[tt]
end

m = Model()
setindex(m, :time, 1)
foo = addcomponent(m, Foo)
bar = addcomponent(m, Bar)

foo[:input] = 3.14
bar[:intermed] = foo[:intermed]
#connectparameter(m, :Bar, :intermed, :Foo, :intermed)

run(m)
Plots.plot(m, :Bar, :output)
savefig("test")

f1 = open("test.png")
f2 = open("testout.png")

s1 = readstring(f1)
s2 = readstring(f2)
@test s1 == s2

rm("test.png")
