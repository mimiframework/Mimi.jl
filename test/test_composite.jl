module TestComposite

using Test
using Mimi

import Mimi:
    ComponentId, DatumReference, ComponentDef, AbstractComponentDef, CompositeComponentDef,
    Binding, ExportsDict, ModelDef, build, time_labels, compdef


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
    foo = Parameter()

    function run_timestep(p, v, d, t)
        # @info "Comp3 run_timestep"
        v.var_3_1[t] = p.par_3_1[t] * 2
    end
end

global m = Model()
set_dimension!(m, :time, 2005:2020)
md = m.md

LONG_WAY = false

if LONG_WAY

    # Test the calls the macro will produce the following
    comps = [
        (Comp1, [:foo => :foo1]),
        (Comp2, [:foo => :foo2]),
        (Comp3, [:foo => :foo3])
    ]

    # TBD: need to implement this to create connections and default value
    bindings = Binding[]
        # DatumReference(:par_1_1, Comp1) => 5,                                 # bind Comp1.par_1_1 to constant value of 5
        # DatumReference(:par_2_2, Comp2) => DatumReference(:var_1_1, Comp1),   # connect target Comp2.par_2_1 to source Comp1.var_1_1
        # DatumReference(:par_3_1, Comp3) => DatumReference(:var_2_1, Comp2)
    # ]

    exports = []
        # DatumReference(:par_1_1, Comp1) => :c1p1,        # i.e., export Comp1.par_1_1 as :c1p1
        # DatumReference(:par_2_2, Comp2) => :c2p2,
        # DatumReference(:var_3_1, Comp3) => :c3v1
    # ]

    compos_name = :top
    compos_id = ComponentId(:TestComposite, compos_name)
    compos = CompositeComponentDef(compos_id)

    top = add_comp!(md, compos, nameof(compos))   # add top-level composite under model def to test 2-layer model

    # Add components to composite
    for (c, exports) in comps
        add_comp!(top, c, nameof(c), exports=exports)     # later allow pair for renaming
    end
else
    exports = []        # TBD: what to export from the composite
    bindings = Binding[]

    @defcomposite top begin
        component(Comp1; exports=[foo => foo1])
        component(Comp2, exports=[foo => foo2])
        component(Comp3, exports=[foo => foo3]) #bindings=[foo => bar, baz => [1 2 3; 4 5 6]])
        # exports(list of names or pairs to export)
    end
    
    add_comp!(md, top, nameof(top))
end

merge!(md.exports, ExportsDict(exports))
append!(md.bindings, bindings)

set_param!(m, "/top/Comp1", :foo, 10)
set_param!(m, "/top/Comp2", :foo, 20)
set_param!(m, "/top/Comp3", :foo, 30)

set_param!(m, "/top/Comp1", :par_1_1, zeros(length(time_labels(md))))

connect_param!(top, :Comp2, :par_2_1, :Comp1, :var_1_1)
connect_param!(top, :Comp2, :par_2_2, :Comp1, :var_1_1)
connect_param!(top, :Comp3, :par_3_1, :Comp2, :var_2_1)

# build(m)
# run(m)

end # module

# TBD: remove once debugged
m = TestComposite.m
md = m.md
mi = m.mi

nothing
