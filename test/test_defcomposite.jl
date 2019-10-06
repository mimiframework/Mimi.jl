module TestDefComposite

using Test
using Mimi
using MacroTools

import Mimi: ComponentPath, build, @defmodel

@defcomp Comp1 begin
    par_1_1 = Parameter(index=[time])      # external input
    var_1_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Comp2 begin
    par_2_1 = Parameter(index=[time])      # connected to Comp1.var_1_1
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo * p.par_2_2[t]
    end
end

@defcomposite A begin
    component(Comp1)
    component(Comp2)

    # imports
    bar = Comp1.par_1_1
    foo2 = Comp2.foo

    # linked imports
    # foo = Comp1.foo, Comp2.foo

    foo1 = Comp1.foo
    foo2 = Comp2.foo

    # connections
    Comp2.par_2_1 = Comp1.var_1_1   
    Comp2.par_2_2 = Comp1.var_1_1
end


# doesn't work currently
# @defmodel m begin
#     index[time] = 2005:2020
#     component(A)

#     A.foo1 = 10
#     A.foo2 = 4
# end

m = Model()
years = 2005:2020
set_dimension!(m, :time, years)
add_comp!(m, A)

set_param!(m, "/A/Comp1", :par_1_1, 2:2:2*length(years))

a = m.md[:A]
set_param!(a, :Comp1, :foo, 10)
set_param!(a, :Comp2, :foo, 4)      # TBD: why does this overwrite the 10 above??

build(m)
run(m)

end # module

m = TestDefComposite.m
A = TestDefComposite.A
md = m.md

nothing
