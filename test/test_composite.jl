module TestComposite

using Test
using Mimi

import Mimi:
    reset_compdefs, compdef, ComponentId, DatumReference, ComponentDef, BindingTypes, ModelDef, 
    SubcompsDef, SubcompsDefTypes, build, time_labels

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
    global MyComposite = Model()

    ccname = :testcomp
    ccid  = ComponentId(calling_module, ccname)
    comps::Vector{ComponentDef{<: SubcompsDefTypes}} = [compdef(Comp1), compdef(Comp2), compdef(Comp3)]
    
    # TBD: need to implement this to create connections and default value
    bindings::Vector{Pair{DatumReference, BindingTypes}} = [
        DatumReference(Comp1, :par_1_1) => 5,                                 # bind Comp1.par_1_1 to constant value of 5
        DatumReference(Comp2, :par_2_2) => DatumReference(Comp1, :var_1_1),   # connect target Comp2.par_2_1 to source Comp1.var_1_1
        DatumReference(Comp3, :par_3_1) => DatumReference(Comp2, :var_2_1)
    ]

    exports = [
        DatumReference(Comp1, :par_1_1) => :c1p1,        # i.e., export Comp1.par_1_1 as :c1p1
        DatumReference(Comp2, :par2_2)  => :c2p2,
        DatumReference(Comp3, :var_3_1) => :c3v1
    ]

    subcomps = SubcompsDef(comps, bindings, exports)
    MyComposite.md = ModelDef(ComponentDef(ccid, ccname, subcomps))
                                
    set_dimension!(MyComposite, :time, 2005:2020)
    nothing
end

m = MyComposite
md = m.md
ccd = md.ccd

set_param!(m, :Comp1, :par_1_1, zeros(length(time_labels(md))))
connect_param!(md, :Comp2, :par_2_1, :Comp1, :var_1_1)
connect_param!(md, :Comp2, :par_2_2, :Comp1, :var_1_1)
connect_param!(md, :Comp3, :par_3_1, :Comp2, :var_2_1)

build(MyComposite)

end # module

m = TestComposite.m
md = m.md
ccd = md.ccd
mi = m.mi
cci = mi.cci

nothing