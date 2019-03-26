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

m = Model()
set_dimension!(m, :time, 2005:2020)

@defcomposite top begin
    component(Comp1; exports=[foo => foo1])
    component(Comp2, exports=[foo => foo2])
    component(Comp3, exports=[foo => foo3]) #bindings=[foo => bar, baz => [1 2 3; 4 5 6]])
    # exports(list of names or pairs to export)
end

top_ref = add_comp!(m, top, nameof(top))
top_comp = compdef(top_ref)

md = m.md

@test find_comp(md, :top) == top_comp

c1 = find_comp(md, ComponentPath((:top, :Comp1)), relative=true) 
@test c1.comp_id == Comp1.comp_id

c3 = find_comp(md, "/top/Comp3")
@test c3.comp_id == Comp3.comp_id

set_param!(m, "/top/Comp1", :foo, 10)
set_param!(m, "/top/Comp2", :foo, 20)

set_param!(m, "/top/Comp1", :par_1_1, zeros(length(time_labels(md))))

connect_param!(top, :Comp2, :par_2_1, :Comp1, :var_1_1)
connect_param!(top, :Comp2, :par_2_2, :Comp1, :var_1_1)
connect_param!(top, :Comp3, :par_3_1, :Comp2, :var_2_1)

# build(m)
# run(m)

end # module

nothing
