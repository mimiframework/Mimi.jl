module TestComposite

using Test
using Mimi

import Mimi:
    reset_compdefs, compdef, ComponentId, DatumReference, CompositeComponentDef, AbstractComponentDef, BindingTypes, ModelDef

reset_compdefs()


@defcomp Comp1 begin
    par1 = Parameter(index=[time])      # external input
    var1 = Variable(index=[time])       # computed
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp Comp2 begin
    par1 = Parameter(index=[time])      # connected to Comp1.var1
    par2 = Parameter(index=[time])      # external input
    var1 = Variable(index=[time])       # computed
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t] + p.par2[t]
    end
end

@defcomp Comp3 begin
    par1 = Parameter(index=[time])      # connected to Comp2.var1
    var1 = Variable(index=[time])       # external output
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t] * 2
    end
end

# Test the calls the macro will produce
let calling_module = @__MODULE__
    # calling_module = TestComposite
    global MyComposite = Model()

    ccname = :testcomp
    ccid  = ComponentId(calling_module, ccname)
    comps = [compdef(Comp1), compdef(Comp2), compdef(Comp3)]
    
    bindings = [
        DatumReference(Comp2, :par1) => 5,                              # bind Comp1.par1 to constant value of 5
        DatumReference(Comp2, :par1) => DatumReference(Comp1, :var1),   # connect target Comp2.par1 to source Comp1.var1
        DatumReference(Comp3, :par1) => DatumReference(Comp2, :var1)
    ]

    exports = [
        DatumReference(Comp1, :par1) => :c1p1,        # i.e., export Comp1.par1 as :c1p1
        DatumReference(Comp2, :par2) => :c2p2,
        DatumReference(Comp3, :var1) => :c3v1
    ]

    ccd = CompositeComponentDef(ccid, ccname, 
                                Vector{AbstractComponentDef}(comps), 
                                Vector{Pair{DatumReference, BindingTypes}}(bindings),
                                exports)

    MyComposite.md = ModelDef(ccd)
    set_dimension!(MyComposite, :time, 2005:2020)
    nothing
end

end # module

nothing