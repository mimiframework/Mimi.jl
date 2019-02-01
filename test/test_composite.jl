module TestComposite

using Test
using Mimi

import Mimi:
    ComponentId, DatumReference, ComponentDef, AbstractComponentDef, CompositeComponentDef,
    BindingTypes, ModelDef, build, time_labels, reset_compdefs, compdef

reset_compdefs()


@defcomp Comp1 begin
    par_1_1 = Parameter(index=[time])      # external input
    var_1_1 = Variable(index=[time])       # computed
    
    function run_timestep(p, v, d, t)
        @info "Comp1 run_timestep"
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Comp2 begin
    par_2_1 = Parameter(index=[time])      # connected to Comp1.var_1_1
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    
    function run_timestep(p, v, d, t)
        @info "Comp2 run_timestep"
        v.var_2_1[t] = p.par_2_1[t] + p.par_2_2[t]
    end
end

@defcomp Comp3 begin
    par_3_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_3_1 = Variable(index=[time])       # external output
    
    function run_timestep(p, v, d, t)
        @info "Comp3 run_timestep"
        v.var_3_1[t] = p.par_3_1[t] * 2
    end
end

# Test the calls the macro will produce
let calling_module = @__MODULE__
    # calling_module = TestComposite
    global m = Model()

    ccname = :testcomp
    ccid  = ComponentId(calling_module, ccname)
    comps = AbstractComponentDef[compdef(Comp1), compdef(Comp2), compdef(Comp3)]
    
    # TBD: need to implement this to create connections and default value
    bindings::Vector{Pair{DatumReference, BindingTypes}} = [
        DatumReference(:par_1_1, Comp1) => 5,                                 # bind Comp1.par_1_1 to constant value of 5
        DatumReference(:par_2_2, Comp2) => DatumReference(:var_1_1, Comp1),   # connect target Comp2.par_2_1 to source Comp1.var_1_1
        DatumReference(:par_3_1, Comp3) => DatumReference(:var_2_1, Comp2)
    ]

    exports = [
        DatumReference(:par_1_1, Comp1) => :c1p1,        # i.e., export Comp1.par_1_1 as :c1p1
        DatumReference(:par_2_2, Comp2) => :c2p2,
        DatumReference(:var_3_1, Comp3) => :c3v1
    ]

    m.md = md = ModelDef()
    CompositeComponentDef(md, ccid, comps, bindings, exports)
                                
    set_dimension!(m, :time, 2005:2020)
    nothing
end

md = m.md

set_param!(m, :Comp1, :par_1_1, zeros(length(time_labels(md))))
connect_param!(md, :Comp2, :par_2_1, :Comp1, :var_1_1)
connect_param!(md, :Comp2, :par_2_2, :Comp1, :var_1_1)
connect_param!(md, :Comp3, :par_3_1, :Comp2, :var_2_1)

build(m)
run(m)

end # module

# TBD: remove once debugged
m = TestComposite.m
md = m.md
mi = m.mi

nothing
