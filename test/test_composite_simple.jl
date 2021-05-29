module TestCompositeSimple

using Test
using Mimi

import Mimi:
    ComponentId, ComponentPath, ComponentDef, AbstractComponentDef,
    CompositeComponentDef, ModelDef, build, time_labels, compdef, find_comp,
    import_params!

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
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo
    end
end

@defcomposite A begin
    Component(Comp1)
    Component(Comp2)

    foo1 = Parameter(Comp1.foo)
    foo2 = Parameter(Comp2.foo, default=100)

    connect(Comp2.par_2_1, Comp1.var_1_1)
end

@defcomposite Top begin
    Component(A)

    fooA1 = Parameter(A.foo1)
    fooA2 = Parameter(A.foo2)
end

m = Model()
set_dimension!(m, :time, 2005:2020)
add_comp!(m, Top)
update_param!(m, :Top, :fooA1, 10)
update_param!(m, :Top, :par_1_1, 1:16) # unshared
run(m)

m = Model()
set_dimension!(m, :time, 2005:2020)
add_comp!(m, Top)
update_param!(m, :Top, :fooA1, 10)
@test_throws ErrorException add_shared_param!(m, :par_1_1, 1:16) # need to give indices
add_shared_param!(m, :par_1_1, 1:16, dims = [:time]) # shared
connect_param!(m, :Top, :par_1_1, :par_1_1)
run(m)

end
