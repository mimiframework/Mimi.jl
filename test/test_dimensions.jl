@testitem "Dimensions" begin
    import Mimi:
        compdef, AbstractDimension, RangeDimension, Dimension, key_type, first_period, last_period,
        ComponentReference, ComponentPath, ComponentDef, time_labels, model_params,
        is_nothing_param, get_model_param_name

    ## 
    ## Constants
    ##

    dim_varargs = Dimension(:foo, :bar, :baz)   # varargs
    dim_vec = Dimension([:foo, :bar, :baz]) # Vector	
    dim_range = Dimension(2010:2100)     # AbstractRange
    rangedim = RangeDimension(2010:2100) # RangeDimension type	
    dim_vals = Dimension(4) # Same as 1:4

    ##
    ## Test a Bunch of Small Functionalities and Helpers
    ##

    @test key_type(dim_varargs) == Symbol
    @test key_type(dim_vec) == Symbol
    @test key_type(dim_range) == Int
    @test key_type(dim_vals) == Int

    @test length(dim_varargs) == 3
    @test length(dim_vec) == 3
    @test length(dim_vals) == 4
    @test length(dim_range) == 91
    @test length(rangedim) == 91

    # Test iteration
    @test [x.first for x in dim_varargs] == collect(keys(dim_varargs))
    @test [x.first for x in dim_range]   == collect(keys(dim_range))

    @test lastindex(dim_varargs) == :baz
    @test lastindex(dim_vec) == :baz
    @test lastindex(dim_range) == 2100
    @test lastindex(dim_vals) == 4

    @test Base.keys(rangedim) == [2010:2100...]
    @test Base.values(rangedim) == [1:91...]

    for i = 1:length(dim_range)
        @test getindex(dim_range, 2010 + i - 1) == i
    end
    @test dim_range[:] == [1:91...]
    @test dim_varargs[:bar] == 2
    @test dim_varargs[:] == [1,2,3]

    # @test rangedim[2011] == 2 # TODO: this errors..
    @test get(dim_varargs, :bar, 999) == 2
    @test get(dim_varargs, :new, 4) == 4 #adds a key/value pair
    @test get(rangedim, 2010, 1) == 1 
    # @test get(rangedim, 2101, 92) == 92 # TODO:  this errors ...

    #test iteratable
    dim_vals2 = Dimension(2:2:8)
    intkeys = [2,4,6,8]
    # Work around new global scoping rules
    # Without the `let`, `index` is unknown in the for loop
    let index = 1
        for pair in dim_vals2
            @test dim_vals2[intkeys[index]] == index
            index += 1
        end
    end

    rangedim2 = RangeDimension(2:2:8)
    # Work around new global scoping rules
    # Without the `let`, `index` is unknown in the for loop
    let index = 1
        for pair in rangedim2   # uses iterate()
            @test get(rangedim2, Base.keys(rangedim2)[index]) == index
            index += 1
        end
    end

    @test getindex(dim_varargs, :bar) == 2
    @test getindex(dim_varargs, :) == [1,2,3]

    # Test that d.time returns AbstracTimesteps that can be used as indexes
    @defcomp bar begin
        v1 = Variable(index = [time])

        function run_timestep(p, v, d, t)
            if is_first(t)
                for i in d.time
                    v.v1[i] = gettime(i)
                end
            end
        end
    end

    fixed_years = 2000:2010
    variable_years = [2000, 2005, 2020, 2050, 2100]

    m = Model()
    set_dimension!(m, :time, fixed_years)
    add_comp!(m, bar)
    run(m)
    @test m[:bar, :v1] == fixed_years

    m = Model()
    set_dimension!(m, :time, variable_years)
    add_comp!(m, bar)
    run(m)
    @test m[:bar, :v1] == variable_years

    # test variable_dimensions function
    comp_path = ComponentPath((:bar,))
    dims = [:time]
    @test variable_dimensions(m, comp_path, :v1) == dims
    @test variable_dimensions(m, :bar, :v1) == dims
    @test variable_dimensions(m, (:bar,), :v1) == dims

    ##
    ## Test time dimension (and resetting it!)
    ##

    @defcomp foo2 begin 
        x = Parameter(index=[time]) 
        y = Variable(index=[4])
    end 

    # build model, set dims, and add components
    m = Model()
    @test_throws ErrorException add_comp!(m, foo2) # cannot add a component before time dimension is set
    set_dimension!(m, :time, 2000:2100)

    @test_throws ErrorException add_comp!(m, foo2; first = 2000, last = 2105)   # 2105 cannot be found in the model's time dimension
    @test_throws ErrorException add_comp!(m, foo2; first = 1950, last = 2100)   # 1950 cannot be found in the model's time dimension

    foo2_ref1 = add_comp!(m, foo2)
    foo2_ref2 = ComponentReference(m, :foo2)
    @test foo2_ref1 === foo2_ref2
    my_foo2 = compdef(foo2_ref1)

    @test first_period(m.md) == first_period(m.md.namespace[:foo2]) == 2000
    @test last_period(m.md) == last_period(m.md.namespace[:foo2]) == 2100

    # Set Parameters
    original_x_vals = collect(2000:2100)
    @test_throws ErrorException update_param!(m, :foo2, :x, 1990:2200) # too long
    @test_throws ErrorException update_param!(m, :foo2, :x, 2005:2095) # too short

    add_shared_param!(m, :x, original_x_vals, dims = [:time])
    connect_param!(m, :foo2, :x, :x)

    run(m)

    # Reset Dimension
    @test_throws ErrorException set_dimension!(m, :time, 2050:2100) # can't move time forward
    @test_throws ErrorException set_dimension!(m, :time, 2105:2200) # can't move new first past old last
    set_dimension!(m, :time, 1990:2050)

    @test first_period(m.md) == 1990 
    @test last_period(m.md) == 2050
    @test first_period(m.md.namespace[:foo2]) == 2000 # no change
    @test last_period(m.md.namespace[:foo2]) == 2050 # trimmed with model

    # check that parameters were padded properly
    new_x_vals = model_params(m)[:x].values.data
    @test length(new_x_vals) == length(time_labels(m))
    @test new_x_vals[11:end] == original_x_vals[1:51]
    @test all(ismissing, new_x_vals[1:10])

    run(m) # should still run because parameters were adjusted under the hood

    # reset again with late end
    set_dimension!(m, :time, 1990:2200)
    new_x_vals = model_params(m)[:x].values.data
    @test length(new_x_vals) == length(time_labels(m))
    @test all(ismissing, new_x_vals[1:10])
    @test new_x_vals[11:61] == original_x_vals[1:51]
    @test all(ismissing, new_x_vals[62:end])

    run(m)

    # check internal parameter connection dimensions between parameters and variable_years
    @defcomp comp1 begin
        par1 = Parameter(index=[time])
        var1 = Variable(index=[time])
        function run_timestep(p,v,d,t)
                v.var1[t] = p.par1[t]
        end
    end

    @defcomp comp2 begin
        par2 = Parameter(index=[time, country])
        var2 = Variable(index=[time,country])
        function run_timestep(p,v,d,t)
                v.var2[t] = p.par2[t]
        end
    end

    @defcomp comp3 begin
        par3 = Parameter(index=[time, town])
        var3 = Variable(index=[time,town])
        function run_timestep(p,v,d,t)
            v.var3[t,:] = p.par3[t,:]
        end
    end

    m = Model()
    set_dimension!(m, :time, 2000:2010)
    set_dimension!(m, :country, [:A, :B, :C])
    add_comp!(m, comp1)
    add_comp!(m, comp2)
    set_param!(m, :comp1, :par1, 1:11)
    connect_param!(m, :comp2 => :par2, :comp1 => :var1)

    error_msg = (try eval(run(m)) catch err err end).msg
    @test occursin("Mismatched dimensions of internal parameter connection", error_msg)

    m = Model()
    set_dimension!(m, :time, 2000:2010)
    set_dimension!(m, :country, [:A, :B, :C])
    set_dimension!(m, :town, ["a", "b", "c", "d"])
    add_comp!(m, comp2)
    add_comp!(m, comp3)
    set_param!(m, :comp2, :par2, zeros(11,3))
    connect_param!(m, :comp3 => :par3, :comp2 => :var2)

    error_msg = (try eval(run(m)) catch err err end).msg
    @test occursin("Mismatched data size for internal parameter connection", error_msg)

    ## Test resetting a non-time dimension
    @defcomp mycomp begin
        par = Parameter(index=[region])
        var = Variable(index=[region])
        function init(p,v,d)
            for r in d.region
                v.var[r] = p.par[r]
            end
        end
        function run_timestep(p,v,d,t)
        end
    end

    m = Model()
    set_dimension!(m, :time, 2000:2002)
    set_dimension!(m, :region, ["A", "B", "C"])
    add_comp!(m, mycomp)
    update_param!(m, :mycomp, :par, [1., 2., 3.])
    run(m)
    @test m[:mycomp, :var] == [1., 2., 3.]

    set_dimension!(m, :region, ["A", "B"]) # reset to shorter
    @test is_nothing_param(m.md.model_params[get_model_param_name(m.md, :mycomp, :par)])
    @test_throws ErrorException run(m)
    update_param!(m, :mycomp, :par, [100., 200.])
    run(m)
    @test m[:mycomp, :var] == [100., 200.]

    set_dimension!(m, :region, ["A", "B"]) # reset to the same - no check, still will reset to nothing
    @test is_nothing_param(m.md.model_params[get_model_param_name(m.md, :mycomp, :par)])
    @test_throws ErrorException run(m)
    update_param!(m, :mycomp, :par, [100., 200.])
    run(m)
    @test m[:mycomp, :var] == [100., 200.]

    # try a shared model parameter
    m = Model()
    set_dimension!(m, :time, 2000:2002)
    set_dimension!(m, :region, ["A", "B", "C"])
    add_comp!(m, mycomp, :mycomp1)
    add_comp!(m, mycomp, :mycomp2)

    add_shared_param!(m, :shared_parameter, [5., 6., 7.]; dims = [:region])
    connect_param!(m, :mycomp1, :par, :shared_parameter)
    connect_param!(m, :mycomp2, :par, :shared_parameter)
    run(m)

    @test m[:mycomp1, :var] == [5., 6., 7.]
    @test m[:mycomp2, :var] == [5., 6., 7.]

    set_dimension!(m, :region, ["A", "B"]) # reset to the same - no check, still will reset to nothing
    @test get_model_param_name(m.md, :mycomp1, :par) == get_model_param_name(m.md, :mycomp2, :par) == :shared_parameter
    @test is_nothing_param(m.md.model_params[:shared_parameter])
    @test_throws ErrorException run(m)
    update_param!(m, :shared_parameter, [100., 200.])
    run(m)

    @test m[:mycomp1, :var] == [100., 200.]
    @test m[:mycomp2, :var] == [100., 200.]
end
