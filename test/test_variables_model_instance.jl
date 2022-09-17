@testitem "VariablesModelInstance" begin
    import Mimi:
        variable_names, compinstance, get_var_value, get_param_value,
        set_param_value, set_var_value, dim_count, compdef, components, parameters, variables,
        LeafComponentInstance, AbstractComponentInstance, ComponentDef, TimestepArray,
        ComponentInstanceParameters, ComponentInstanceVariables

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
    update_param!(my_model, :testcomp1, :par1, par)
    run(my_model)
    #NOTE: this variables function does NOT take in Nullable instances
    @test (variable_names(my_model, :testcomp1) == [:var1, :var2])

    #test basic def and instance functions
    mi = my_model.mi
    md = modeldef(mi)
    ci = compinstance(mi, :testcomp1)
    cdef = compdef(md, ci.comp_path)
    citer = components(mi)

    @test typeof(md) == Mimi.ModelDef && md == mi.md
    @test typeof(ci) <: LeafComponentInstance && ci == compinstance(mi, :testcomp1)
    @test typeof(cdef) <: ComponentDef && cdef.comp_id == ci.comp_id
    @test ci.comp_name == :testcomp1
    @test typeof(citer) <: Base.ValueIterator && length(citer) == 1 && eltype(citer) <: AbstractComponentInstance

    #test convenience functions that can be called with name symbol

    param_value = get_param_value(ci, :par1)
    @test typeof(param_value)<: TimestepArray
    @test_throws ErrorException get_param_value(ci, :missingpar)

    var_value = get_var_value(ci, :var1)
    @test_throws ErrorException get_var_value(ci, :missingvar)
    @test typeof(var_value) <: TimestepArray

    params = parameters(mi, :testcomp1)
    params2 = parameters(mi, :testcomp1)
    @test typeof(params) <: ComponentInstanceParameters
    @test params == params2

    vars = variables(mi, :testcomp1)
    vars2 = variables(ci)
    @test typeof(vars) <: ComponentInstanceVariables
    @test vars == vars2

    @test dim_count(mi, :time) == 20

end
