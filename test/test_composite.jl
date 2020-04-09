module TestComposite

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
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo * p.par_2_2[t]
    end
end

@defcomp Comp3 begin
    par_3_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_3_1 = Variable(index=[time])       # external output
    foo = Parameter(default=30)

    function run_timestep(p, v, d, t)
        # @info "Comp3 run_timestep"
        v.var_3_1[t] = p.par_3_1[t] * 2
    end
end

@defcomp Comp4 begin
    par_4_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_4_1 = Variable(index=[time])        # external output
    foo = Parameter(default=300)

    function run_timestep(p, v, d, t)
        # @info "Comp4 run_timestep"
        v.var_4_1[t] = p.par_4_1[t] * 2
    end
end

m = Model()
set_dimension!(m, :time, 2005:2020)

@defcomposite A begin
    Component(Comp1)
    Component(Comp2)

    foo1 = Parameter(Comp1.foo)
    foo2 = Parameter(Comp2.foo)

    var_2_1 = Variable(Comp2.var_2_1)

    connect(Comp2.par_2_1, Comp1.var_1_1)
    connect(Comp2.par_2_2, Comp1.var_1_1)
end

@defcomposite B begin
    Component(Comp3)
    Component(Comp4)

    foo3 = Parameter(Comp3.foo)
    foo4 = Parameter(Comp4.foo)

    var_3_1 = Variable(Comp3.var_3_1)
end

@defcomposite top begin
    Component(A)

    fooA1 = Parameter(A.foo1)
    fooA2 = Parameter(A.foo2)

    # TBD: component B isn't getting added to mi
    Component(B)
    foo3 = Parameter(B.foo3)
    foo4 = Parameter(B.foo4)

    var_3_1 = Variable(B.Comp3.var_3_1)

    connect(B.par_3_1, A.var_2_1)
    connect(B.par_4_1, B.var_3_1)
end

# We have created the following composite structure:
#
#          top
#        /    \
#       A       B
#     /  \     /  \
#    1    2   3    4

top_ref = add_comp!(m, top, nameof(top))
top_comp = compdef(top_ref)

md = m.md

@test find_comp(md, :top) == top_comp

#
# Test various ways to access sub-components
#
c1 = find_comp(md, ComponentPath(:top, :A, :Comp1))
@test c1.comp_id == Comp1.comp_id

c2 = md[:top][:A][:Comp2]
@test c2.comp_id == Comp2.comp_id

c3 = find_comp(md, "/top/B/Comp3")
@test c3.comp_id == Comp3.comp_id

set_param!(m, :fooA1, 1)
set_param!(m, :fooA2, 2)

# TBD: default values set in @defcomp are not working...
# Also, external_parameters are stored in the parent, so both of the
# following set parameter :foo in "/top/B", with 2nd overwriting 1st.
set_param!(m, :foo3, 10)
set_param!(m, :foo4, 20)

set_param!(m, :par_1_1, collect(1:length(time_labels(md))))

build(m)

run(m)

mi = m.mi

@test mi[:top][:A][:Comp2, :par_2_2] == collect(1.0:16.0)
@test mi["/top/A/Comp2", :par_2_2] == collect(1.0:16.0)

@test mi["/top/A/Comp2", :var_2_1] == collect(3.0:3:48.0)
@test mi["/top/A/Comp1", :var_1_1] == collect(1.0:16.0)
@test mi["/top/B/Comp4", :par_4_1] == collect(6.0:6:96.0)

#
# Test joining external params.
#
m2 = Model()
set_dimension!(m2, :time, 2005:2020)

@defcomposite top2 begin
    Component(Comp1)
    Component(Comp2)

    connect(Comp2.par_2_1, Comp1.var_1_1)
    connect(Comp2.par_2_2, Comp1.var_1_1)

    foo = Parameter(Comp1.foo, Comp2.foo)
end

top2_ref = add_comp!(m2, top2, nameof(top2))

end # module

nothing
