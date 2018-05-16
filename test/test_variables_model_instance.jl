using Mimi
using Base.Test

import Mimi: 
    reset_compdefs

reset_compdefs()

my_model = Model()

@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    var2 = Variable(index=[time])
    par1 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

par = collect(2015:5:2110)

set_dimension!(my_model, :time, 2015:5:2110)
addcomponent(my_model, testcomp1)
set_parameter!(my_model, :testcomp1, :par1, par)
run(my_model);
#NOTE: this variables function does NOT take in Nullable instances
@test (Mimi.variable_names(my_model, :testcomp1) == [:var1, :var2])
