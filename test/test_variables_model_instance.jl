module TestVariablesModelInstance

using Mimi
using Base.Test

import Mimi:
    reset_compdefs, variable_names, compinstance, get_var_value, get_param_value, 
    set_param_value, set_var_value, dim_count, dim_key_dict, dim_value_dict, compdef

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
@test_throws ErrorException run(my_model) #no components added yet

add_comp!(my_model, testcomp1)
set_param!(my_model, :testcomp1, :par1, par)
run(my_model)
#NOTE: this variables function does NOT take in Nullable instances
@test (variable_names(my_model, :testcomp1) == [:var1, :var2])

#test basic def and instance functions
mi = my_model.mi
md = modeldef(mi)
ci = compinstance(mi, :testcomp1)
cdef = compdef(ci)
citer = components(mi)

@test typeof(md) == Mimi.ModelDef && md == mi.md
@test typeof(ci) <: Mimi.ComponentInstance && ci == mi.components[:testcomp1]
@test typeof(cdef) <: Mimi.ComponentDef && cdef == compdef(ci.comp_id)
@test name(ci) == :testcomp1
@test typeof(citer) <: Base.ValueIterator && length(citer) == 1 && eltype(citer) == Mimi.ComponentInstance

#test convenience functions that can be called with name symbol

param_value = get_param_value(ci, :par1)
@test typeof(param_value)<: Mimi.TimestepArray
@test_throws ErrorException get_param_value(ci, :missingpar)

var_value = get_var_value(ci, :var1)
@test_throws ErrorException get_var_value(ci, :missingvar)
@test typeof(var_value) <: Mimi.TimestepArray

params = parameters(mi, :testcomp1)
params2 = parameters(mi, :testcomp1)
@test typeof(params) <: Mimi.ComponentInstanceParameters
@test params == params2

vars = variables(mi, :testcomp1)
vars2 = variables(ci)
@test typeof(vars) <: Mimi.ComponentInstanceVariables
@test vars == vars2

@test dim_count(mi, :time) == 20
key_dict = dim_key_dict(mi)
value_dict = dim_value_dict(mi)
@test Array{Int64}(key_dict[:time]) == [2015:5:2110...] && length(key_dict) == 1
@test value_dict[:time] == [1:1:20...] && length(value_dict) == 1

end #module
