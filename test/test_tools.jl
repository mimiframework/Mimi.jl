module TestTools

using Base.Test
using Mimi

import Mimi:
    getproperty, reset_compdefs

reset_compdefs()

#utils: prettify
@test Mimi.prettify("camelCaseBasic") == Mimi.prettify(:camelCaseBasic) == "Camel Case Basic"
@test Mimi.prettify("camelWithAOneLetterWord") == Mimi.prettify(:camelWithAOneLetterWord) == "Camel With A One Letter Word"
@test Mimi.prettify("snake_case_basic") == Mimi.prettify(:snake_case_basic) == "Snake Case Basic"
@test Mimi.prettify("_snake__case__weird_") == Mimi.prettify(:_snake__case__weird_) == "Snake Case Weird"

#utils: interpolate
step = 2;
last = 10;
ts = 10;
@test Mimi.interpolate(collect(0:step:last), ts) == collect(0:step/ts:last)

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
foo = add_comp!(m, Foo)
bar = add_comp!(m, Bar)

foo[:input] = 3.14
bar[:intermed] = foo[:intermed]

run(m)

end #module