@testitem "Main_VariableTimestep" begin
    import Mimi:
        reset_variables,
        variable, variable_names, model_param,
        compdef, compdefs, dimension, compinstance

    @defcomp foo1 begin
        index1 = Index()

        par1 = Parameter()
        par2 = Parameter{Bool}(index=[time,index1], description="description par 1")
        par3 = Parameter(index=[time])

        var1 = Variable()
        var2 = Variable(index=[time])
        var3 = Variable(index=[time,index1])

        idx3 = Index()
        idx4 = Index()
        var4 = Variable{Bool}(index=[idx3])
        var5 = Variable(index=[index1, idx4])
    end

    x1 = Model()
    set_dimension!(x1, :index1, [:r1, :r2, :r3])
    set_dimension!(x1, :time, [2010, 2015, 2030])
    set_dimension!(x1, :idx3, 1:3)
    set_dimension!(x1, :idx4, 1:4)
    add_comp!(x1, foo1)
    update_param!(x1, :foo1, :par1, 5.0)

    @test length(dimension(x1.md, :index1)) == 3

    @test_throws ErrorException par1 = model_param(x1, :par1) # unshared
    par1 = model_param(x1, :foo1, :par1)
    @test par1.value == 5.0

    update_param!(x1, :foo1, :par1, 6.0)
    par1 = model_param(x1, :foo1, :par1)
    @test par1.value == 6.0

    update_param!(x1, :foo1, :par2, [true true false; true false false; true true true])

    update_param!(x1, :foo1, :par3, [1.0, 2.0, 3.0])

    Mimi.build!(x1)

    ci = compinstance(x1, :foo1)
    reset_variables(ci)

    # Check all variables are defaulted
    @test isnan(get_var_value(ci, :var1))

    m = Model()
    set_dimension!(m, :time, 20)
    set_dimension!(m, :index1, 5)
    add_comp!(m, foo1)

    @test :var1 in variable_names(x1, :foo1)

end
