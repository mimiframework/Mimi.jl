module TestComposite

using Test
using Mimi

import Mimi:
    ComponentId, ComponentPath, DatumReference, ComponentDef, AbstractComponentDef, CompositeComponentDef,
    Binding, ExportsDict, ModelDef, build, time_labels, compdef, find_comp


@defcomp Comp1 begin
    par_1_1 = Parameter(index=[time])      # external input
    var_1_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        # @info "Comp1 run_timestep"
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Comp2 begin
    par_2_1 = Parameter(index=[time])      # connected to Comp1.var_1_1
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        # @info "Comp2 run_timestep"
        v.var_2_1[t] = p.par_2_1[t] + p.par_2_2[t]
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
    var_41 = Variable(index=[time])        # external output
    foo = Parameter(default=300)

    function run_timestep(p, v, d, t)
        # @info "Comp4 run_timestep"
        v.var_4_1[t] = p.par_4_1[t] * 2
    end
end

m = Model()
set_dimension!(m, :time, 2005:2020)

@defcomposite A begin
    component(Comp1; exports=[foo => foo1])
    component(Comp2, exports=[foo => foo2])
end

# @defcomposite B begin
#     component(Comp3, exports=[foo => foo3]) #bindings=[foo => bar, baz => [1 2 3; 4 5 6]])
#     component(Comp4, exports=[foo => foo4])
# end

@defcomposite top begin
    component(A; exports=[foo1 => fooA1, foo2 => fooA2])
    # component(B; exports=[foo3, foo4])
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

c1 = find_comp(md, ComponentPath(:top, :A, :Comp1))
@test c1.comp_id == Comp1.comp_id

# c3 = find_comp(md, "/top/B/Comp3")
# @test c3.comp_id == Comp3.comp_id

set_param!(m, "/top/A/Comp1", :foo, 10)
set_param!(m, "/top/A/Comp2", :foo, 20)

set_param!(m, "/top/A/Comp1", :par_1_1, zeros(length(time_labels(md))))

c1_path = ComponentPath(:A, :Comp1)
c2_path = ComponentPath(:A, :Comp2)
# c3_path = ComponentPath(:B, :Comp3)
# c4_path = ComponentPath(:B, :Comp4)

connect_param!(top, c2_path, :par_2_1, c1_path, :var_1_1)
connect_param!(top, c2_path, :par_2_2, c1_path, :var_1_1)
# connect_param!(top, c3_path, :par_3_1, c2_path, :var_2_1)

# build(m)
# run(m)

end # module

nothing
