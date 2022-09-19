@testitem "New Param API" begin
    ## Testing the New Parameter API

    import Mimi: model_param, is_shared

    #
    # Section 1. update_param!, add_shared_param! and connect_param!
    #

    @defcomp A begin

        p1 = Parameter{Symbol}()
        p2 = Parameter(default = 2)
        p3 = Parameter()
        p4 = Parameter(unit = "dollars")
        p5 = Parameter(unit = "\$")
        p6 = Parameter(index = [time])
        p7 = Parameter(index = [regions, time])

        function run_timestep(p,v,d,t)
        end
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 1:5);
        set_dimension!(m, :regions, [:R1, :R2, :R3])
        add_comp!(m, A)
        return m
    end

    # General Functionality
    m = _get_model()

    @test_throws MethodError update_param!(m, :A, :p1, 3) # can't convert
    update_param!(m, :A, :p1, :hello)
    @test model_param(m, :A, :p1).value == :hello
    add_shared_param!(m, :p1_fail, 3)
    @test_throws ErrorException connect_param!(m, :A, :p1, :p1_fail) # we throw specific error here
    add_shared_param!(m, :p1, :goodbye)
    connect_param!(m, :A, :p1, :p1)
    @test model_param(m, :A, :p1).value == :goodbye
    @test_throws ErrorException update_param!(m, :A, :p1, :foo) # can't call this method on a shared parameter
    update_param!(m, :p1, :foo)
    @test model_param(m, :A, :p1).value == :foo
    disconnect_param!(m, :A, :p1)
    update_param!(m, :A, :p1, :foo) # now we can update :p1 with this syntax since it was disconnected
    update_param!(m, :p1, :bar) # this is the shared parameter named :p1
    @test model_param(m, :A, :p1).value == :foo
    @test model_param(m, :p1).value == :bar
        
    m = _get_model()

    add_shared_param!(m, :shared_param, 100)
    connect_param!(m, :A, :p2, :shared_param)
    connect_param!(m, :A, :p3, :shared_param)
    @test model_param(m, :A, :p2).value == model_param(m, :A, :p3).value == 100

    # still error because they are connected to a shared parameter
    @test_throws ErrorException update_param!(m, :A, :p2, 1)
    @test_throws ErrorException update_param!(m, :A, :p3, 2)

    disconnect_param!(m, :A, :p2)
    update_param!(m, :A, :p2, 1)
    model_param(m, :A, :p2).value == 1
    model_param(m, :A, :p3).value == model_param(m, :shared_param).value == 100

    # Defaults
    m = _get_model()

    @test model_param(m, :A, :p2).value == 2
    @test !(is_shared(model_param(m, :A, :p2)))
    update_param!(m, :A, :p2, 100)
    @test !(is_shared(model_param(m, :A, :p2)))

    # Dimensions
    m = _get_model()

    @test_throws ErrorException add_shared_param!(m, :x, [1:10]) # need dimensions to be specified
    @test_throws ErrorException add_shared_param!(m, :x, [1:10], dims = [:time]) # wrong dimensions
    add_shared_param!(m, :x, 1:5, dims = [:time])

    @test_throws ErrorException add_shared_param!(m, :y, fill(1, 3, 5)) # need dimensions to be specified
    @test_throws ErrorException add_shared_param!(m, :y, fill(1, 3, 5), dims = [:time, :regions]) # need dimensions to be specified
    add_shared_param!(m, :y, fill(1, 5, 3), dims = [:time, :regions])

    @test_throws ErrorException connect_param!(m, :A, :p7, :y) # wrong dimensions, flipped around

    # Units and Datatypes
    m = _get_model()

    add_shared_param!(m, :myparam, 100)
    connect_param!(m, :A, :p3, :myparam)
    @test_throws ErrorException connect_param!(m, :A, :p4, :myparam) # units error
    connect_param!(m, :A, :p4, :myparam; ignoreunits = true)
    @test model_param(m, :A, :p3).value == model_param(m, :A, :p4).value == 100
    @test_throws ErrorException update_param!(m, :myparam, :boo) # cannot convert
    update_param!(m, :myparam, 200)
    @test model_param(m, :A, :p3).value == model_param(m, :A, :p4).value == 200
    @test_throws ErrorException connect_param!(m, :A, :p3, :myparam) # units error

    #
    # Section 2. add_shared_param! defaults
    #

    @defcomp A begin
        pA1 = Parameter{Symbol}()   # type will by Symbol
        pA2 = Parameter()           # type will be Number
        function run_timestep(p,v,d,t)
        end
    end

    @defcomp B begin
        pB1 = Parameter{Number}()   # type will be Number
        pB2 = Parameter{Int64}()    # type will be Int64
        function run_timestep(p,v,d,t)
        end
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 1:5);
        add_comp!(m, A)
        add_comp!(m, B)
        return m
    end

    # typical behavior
    m = _get_model()
    add_shared_param!(m, :myparam, 5)
    @test model_param(m, :myparam) isa Mimi.ScalarModelParameter{Float64} # by default same as model, which defaults to number_type(m) == Float64

    exp = :(connect_param!(m, :A, :pA1, :myparam)) # pA1 should have a specified parameter type of Symbol and !(Float64 <: Symbol)
    myerr1 = try eval(exp) catch err err end 
    @test occursin("Mismatched datatype of parameter connection", sprint(showerror, myerr1))

    connect_param!(m, :A, :pA2, :myparam) # pA2 should have a parameter type of Number by default and Float64 <: Number
    connect_param!(m, :B, :pB1, :myparam) # pB1 should have a specified parameter type of Number and Float64 <: Number

    exp = :(connect_param!(m, :B, :pB2, :myparam)) # pB2 should have a specified parameter type of Int64 and !(Float64 <: Int64)
    myerr2 = try eval(exp) catch err err end 
    @test occursin("Mismatched datatype of parameter connection", sprint(showerror, myerr2))

    # try data_type keyword argument
    m = _get_model() # number_type(m) == Float64

    exp = :(add_shared_param!(m, :myparam, :foo; data_type = Int64)) # !(:foo isa Int64)
    myerr3 = try eval(exp) catch err err end 
    @test occursin("Mismatched datatypes:", sprint(showerror, myerr3))

    add_shared_param!(m, :myparam, 5; data_type = Int64)
    @test model_param(m, :myparam) isa Mimi.ScalarModelParameter{Int64} # 5 is convertible to Int64

    connect_param!(m, :B, :pB2, :myparam) # pB2 should have a specified parameter type of Int64 and Int64 <: Int64
    connect_param!(m, :A, :pA2, :myparam) # we allow pB2 and pA2 types to conflict as long as they both passed compatibilty with the model parameter

    #
    # Section 2. update_leftover_params! and set_leftover_params!
    #

    @defcomp A begin

        p1 = Parameter{Symbol}()
        p2 = Parameter(default = 100)
        p3 = Parameter()

        function run_timestep(p,v,d,t)
        end
    end

    @defcomp B begin

        p1 = Parameter{Symbol}()
        p2 = Parameter()
        p3 = Parameter()
        p4 = Parameter()
        function run_timestep(p,v,d,t)
        end
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 1:5);
        add_comp!(m, A)
        add_comp!(m, B)
        return m
    end

    #
    # set_leftover_params!
    #

    m = _get_model()

    # wrong type (p1 must be a Symbol)
    m = _get_model()
    parameters = Dict("p1" => 1, "p2" => 2, "p3" => 3, "p4" => 4)
    fail_expr1 = :(set_leftover_params!(m, parameters))
    err1 = try eval(fail_expr1) catch err err end 
    @test occursin("Cannot `convert`", sprint(showerror, err1))

    # missing entry (missing p4)
    m = _get_model()
    parameters = Dict("p1" => :foo, "p2" => 2, "p3" => 3)
    fail_expr2 = :(set_leftover_params!(m, parameters))
    err2 = try eval(fail_expr2) catch err err end 
    @test occursin("not found in provided dictionary", sprint(showerror, err2))

    # successful calls
    m = _get_model()
    parameters = Dict(:p1 => :foo, "p2" => 2, :p3 => 3, "p4" => 4) # keys can be Symbols or Strings
    set_leftover_params!(m, parameters)
    run(m)
    @test m[:A, :p1] == m[:B, :p1] == :foo
    @test model_param(m, :p1).is_shared

    @test m[:A, :p2] == 100 # remained default value
    @test !model_param(m, :A, :p2).is_shared # remains its default so is not shared

    @test m[:B, :p2] == 2 # took on shared value
    @test model_param(m, :p2).is_shared

    @test m[:A, :p3] == m[:B, :p3] == 3
    @test model_param(m, :p3).is_shared

    @test m[:B, :p4] == 4
    @test model_param(m, :p4).is_shared


    #
    # update_leftover_params!
    #

    # wrong type (p1 must be a Symbol)
    m = _get_model()
    parameters = Dict(  (:A, :p1) => 1, (:B, :p1) => 10, 
                        (:B, :p2) => 20, 
                        (:A, :p3) => 3, (:B, :p3) => 30,
                        (:A, :p4) => 4, (:B, :p4) => 40
                    ) 
    fail_expr3 = :(update_leftover_params!(m, parameters))
    err3 = try eval(fail_expr3) catch err err end 
    @test occursin("Cannot `convert`", sprint(showerror, err3))

    # missing entry (missing B's p4)
    m = _get_model()
    parameters = Dict(  (:A, :p1) => :foo, (:B, :p1) => :bar, 
                        (:B, :p2) => 20, 
                        (:A, :p3) => 3, (:B, :p3) => 30,
                        (:A, :p4) => 4
                    )
    fail_expr4 = :(update_leftover_params!(m, parameters))
    err4 = try eval(fail_expr4) catch err err end 
    @test occursin("not found in provided dictionary", sprint(showerror, err4))

    # successful calls
    m = _get_model()
    parameters = Dict(  (:A, :p1) => :foo, (:B, "p1") => :bar, 
                        (:B, :p2) => 20, 
                        (:A, :p3) => 3, (:B, :p3) => 30,
                        (:A, "p4") => 4, (:B, :p4) => 40
                    ) 
    update_leftover_params!(m, parameters)
    run(m)
    @test m[:A, :p1] == :foo && m[:B, :p1] == :bar
    @test !model_param(m, :A, :p1).is_shared && !model_param(m, :B, :p1).is_shared
    @test isnothing(model_param(m, :p1, missing_ok = true)) # no shared model parameter created

    @test m[:A, :p2] == 100 # remained default value
    @test !model_param(m, :A, :p2).is_shared # remains its default so is not shared

    @test m[:B, :p2] == 20 # took on shared value
    @test !model_param(m, :B, :p2).is_shared

    @test isnothing(model_param(m, :p2, missing_ok = true)) # no shared model parameter created

    @test m[:A, :p3] == 3 && m[:B, :p3] == 30
    @test !model_param(m, :A, :p3).is_shared && !model_param(m, :B, :p3).is_shared
    @test isnothing(model_param(m, :p3, missing_ok = true)) # no shared model parameter created

    @test m[:B, :p4] == 40
    @test !model_param(m, :B, :p4).is_shared
    @test isnothing(model_param(m, :p4, missing_ok = true)) # no shared model parameter created

    #
    # Section 3. update_params!
    #

    @defcomp A begin

        p1 = Parameter(default = 0)
        p2 = Parameter(default = 0)
        p3 = Parameter()
        p4 = Parameter()
        p5 = Parameter()
        p6 = Parameter()

        function run_timestep(p,v,d,t)
        end
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 1:5);
        add_comp!(m, A)

        add_shared_param!(m, :shared_param, 0)
        connect_param!(m, :A, :p3, :shared_param)
        connect_param!(m, :A, :p4, :shared_param)

        return m
    end

    # update the shared parameters and unshared parameters separately
    m = _get_model()

    shared_dict = Dict(:shared_param => 1)
    update_params!(m, shared_dict)

    unshared_dict = Dict((:A, :p5) => 2, (:A, :p6) => 3)
    update_params!(m, unshared_dict)

    run(m)
    @test m[:A, :p3] == m[:A, :p4] == 1
    @test m[:A, :p5] == 2
    @test m[:A, :p6] == 3

    # update both at the same time
    m = _get_model()

    dict = Dict(:shared_param => 1, (:A, :p5) => 2, (:A, :p6) => 3)
    update_params!(m, dict)

    run(m)
    @test m[:A, :p3] == m[:A, :p4] == 1
    @test m[:A, :p5] == 2
    @test m[:A, :p6] == 3

    # test failures

    m = _get_model()

    shared_dict = Dict(:shared_param => :foo)
    @test_throws ErrorException update_params!(m, shared_dict) # units failure
    shared_dict = Dict(:p3 => 3)
    @test_throws ErrorException update_params!(m, shared_dict) # can't find parameter

    unshared_dict = Dict((:A, :p5) => :foo, (:A, :p6) => 3)
    @test_throws MethodError update_params!(m, unshared_dict) # units failure
    unshared_dict = Dict((:B, :p5) => 5) 
    @test_throws ErrorException update_params!(m, unshared_dict) # can't find component
    unshared_dict = Dict((:B, :missing) => 5) 
    @test_throws ErrorException update_params!(m, unshared_dict) # can't find parameter

end
