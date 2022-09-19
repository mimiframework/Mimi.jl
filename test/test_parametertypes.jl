@testitem "ParameterTypes" begin
    import Mimi:
        model_params, model_param, TimestepMatrix, TimestepVector,
        ArrayModelParameter, ScalarModelParameter, FixedTimestep, import_params!, 
        set_first_last!, _get_param_times

    #
    # Test that simple constructors don't error
    #

    values = [1,2,3]
    dim_names = [:time]
    shared = true
    p1 = ArrayModelParameter(values, dim_names, shared)
    p2 = ArrayModelParameter(values, dim_names)
    @test p1.values == p2.values == values
    @test p1.dim_names == p2.dim_names == dim_names
    @test Mimi.is_shared(p1) && !Mimi.is_shared(p2)

    p3 = ScalarModelParameter(3, shared)
    p4 = ScalarModelParameter(3)
    @test p3.value == p4.value == 3
    @test Mimi.is_shared(p3) && !Mimi.is_shared(p4)

    #
    # Test that parameter type mismatches are caught
    #
    expr = :(
        @defcomp BadComp1 begin
            a = Parameter(index=[time, regions], default=[10, 11, 12])  # should be 2D default
            function run_timestep(p, v, d, t)
            end
        end
    )
    @test_throws ErrorException eval(expr)

    expr = :(
        @defcomp BadComp2 begin
            a = Parameter(default=[10, 11, 12])  # should be scalar default
            function run_timestep(p, v, d, t)
            end
        end
    )
    @test_throws ErrorException eval(expr)

    #
    # Test that the old type parameterization syntax errors
    #
    expr = :(
        @defcomp BadComp3 begin
            a::Int = Parameter()
            function run_timestep(p, v, d, t)
            end
        end
    )
    @test_throws LoadError eval(expr)


    @defcomp MyComp begin
        a = Parameter(index=[time, regions], default=ones(101,3))
        b = Parameter(index=[time], default=1:101)
        c = Parameter(index=[regions])
        d = Parameter()
        e = Parameter(index=[four])
        f = Parameter{Array{Float64, 2}}()
        g = Parameter{Int}(default=10.0)    # value should be Int despite Float64 default
        h = Parameter(default=10)           # should be "numtype", despite Int default
        j = Parameter{Int}(index = [regions])

        function run_timestep(p, v, d, t)
        end
    end

    # Check that explicit number type for model works as expected
    numtype = Float32
    arrtype = Union{Missing, numtype}

    m = Model(numtype)

    set_dimension!(m, :time, 2000:2100)
    set_dimension!(m, :regions, 3)
    set_dimension!(m, :four, 4)

    add_comp!(m, MyComp)
    update_param!(m, :MyComp, :c, [4,5,6])
    update_param!(m, :MyComp, :d, 0.5)   # 32-bit float constant
    update_param!(m, :MyComp, :e, [1,2,3,4])
    update_param!(m, :MyComp, :f, reshape(1:16, 4, 4))
    update_param!(m, :MyComp, :j, [1,2,3])

    Mimi.build!(m)
    extpars = model_params(m.mi.md)

    a_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :a)
    b_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :b)
    c_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :c)
    d_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :d)
    e_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :e)
    f_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :f)
    g_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :g)
    h_sym = Mimi.get_model_param_name(m.mi.md, :MyComp, :h)

    @test isa(extpars[a_sym], ArrayModelParameter)
    @test isa(extpars[b_sym], ArrayModelParameter)
    @test _get_param_times(extpars[a_sym]) == _get_param_times(extpars[b_sym]) == 2000:2100

    @test isa(extpars[c_sym], ArrayModelParameter)
    @test isa(extpars[d_sym], ScalarModelParameter)
    @test isa(extpars[e_sym], ArrayModelParameter)
    @test isa(extpars[f_sym], ScalarModelParameter) # note that :f is stored as a scalar parameter even though its values are an array

    @test typeof(extpars[a_sym].values) == TimestepMatrix{FixedTimestep{2000, 1, 2100}, arrtype, 1, Array{arrtype, 2}}
    @test typeof(extpars[b_sym].values) == TimestepVector{FixedTimestep{2000, 1, 2100}, arrtype, Array{arrtype, 1}}

    @test typeof(extpars[c_sym].values) == Array{arrtype, 1}
    @test typeof(extpars[d_sym].value) == numtype
    @test typeof(extpars[e_sym].values) == Array{arrtype, 1}
    @test typeof(extpars[f_sym].value) == Array{Float64, 2}
    @test typeof(extpars[g_sym].value) <: Int
    @test typeof(extpars[h_sym].value) == numtype

    # test updating parameters
    @test_throws ErrorException update_param!(m, :a, 5) # expects an array
    @test_throws ErrorException update_param!(m, :a, ones(101)) # wrong size
    @test_throws ErrorException update_param!(m, :a, fill("hi", 101, 3)) # wrong type

    update_param!(m, :MyComp, :a, Array{Int,2}(zeros(101, 3))) # should be able to convert from Int to Float
    @test_throws ErrorException update_param!(m, :MyComp, :d, ones(5)) # wrong type; should be scalar
    update_param!(m, :MyComp, :d, 5) # should work, will convert to float
    new_extpars = model_params(m)    # Since there are changes since the last build, need to access the updated dictionary in the model definition
    @test extpars[d_sym].value == 0.5      # The original dictionary still has the old value
    @test new_extpars[d_sym].value == 5.   # The new dictionary has the updated value
    @test_throws ErrorException update_param!(m, :e, 5) # wrong type; should be array
    @test_throws ErrorException update_param!(m, :e, ones(10)) # wrong size
    update_param!(m, :MyComp, :e, [4,5,6,7])

    @test length(extpars) == length(new_extpars) == 9 # we replaced the unshared default for :a with a shared for :a       
    @test typeof(new_extpars[a_sym].values) == TimestepMatrix{FixedTimestep{2000, 1, 2100}, arrtype, 1, Array{arrtype, 2}}

    @test typeof(new_extpars[d_sym].value) == numtype
    @test typeof(new_extpars[e_sym].values) == Array{arrtype, 1}


    #------------------------------------------------------------------------------
    # Test updating TimestepArrays with update_param!
    #------------------------------------------------------------------------------

    @defcomp MyComp2 begin
        x=Parameter(index=[time])
        y=Variable(index=[time])
        function run_timestep(p,v,d,t)
            v.y[t]=p.x[t]
        end
    end

    # 1. update_param! with Fixed Timesteps

    m = Model()
    set_dimension!(m, :time, 2000:2004)
    add_comp!(m, MyComp2, first=2001, last=2003)
    update_param!(m, :MyComp2, :x, [1, 2, 3, 4, 5])
    # Year      x       Model   MyComp2 
    # 2000      1       first   
    # 2001      2               first
    # 2002      3
    # 2003      4               last
    # 2004      5      last

    update_param!(m, :MyComp2, :x, [2.,3.,4.,5.,6.])
    update_param!(m, :MyComp2, :x, zeros(5))
    update_param!(m, :MyComp2, :x, [1,2,3,4,5])

    set_dimension!(m, :time, 1999:2001)
    # Year      x       Model   MyComp2 
    # 1999      missing first
    # 2000      1          
    # 2001      2       last    first, last

    x = model_param(m, :MyComp2, :x) 
    @test ismissing(x.values.data[1])
    @test x.values.data[2:3] == [1.0, 2.0]
    @test _get_param_times(x) == 1999:2001
    run(m) # should be runnable

    update_param!(m, :MyComp2, :x, [2, 3, 4]) # change x to match 
    # Year      x       Model   MyComp2 
    # 1999      2       first   
    # 2000      3               
    # 2001      4       last    first, last

    x = model_param(m, :MyComp2, :x)
    @test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{1999, 1, 2001}, Union{Missing,Float64}, 1}
    @test x.values.data == [2., 3., 4.]
    run(m)
    @test ismissing(m[:MyComp2, :y][1])  # 1999
    @test ismissing(m[:MyComp2, :y][2])  # 2000
    @test m[:MyComp2, :y][3] == 4   # 2001

    set_first_last!(m, :MyComp2, first = 1999, last = 2001)
    # Year      x       Model   MyComp2 
    # 1999      2       first   first
    # 2000      3               
    # 2001      4       last    last

    run(m)
    @test m[:MyComp2, :y] == [2, 3, 4]

    # 2. Test with Variable Timesteps

    m = Model()
    set_dimension!(m, :time, [2000, 2005, 2020])
    add_comp!(m, MyComp2)
    update_param!(m, :MyComp2, :x, [1, 2, 3])
    # Year      x       Model   MyComp2 
    # 2000      1       first   first
    # 2005      2               
    # 2010      3       last    last

    set_dimension!(m, :time, [2000, 2005, 2020, 2100])
    # Year      x       Model   MyComp2 
    # 2000      1       first   first
    # 2005      2               
    # 2020      3               last
    # 2100      missing last

    x = model_param(m, :MyComp2, :x) 
    @test ismissing(x.values.data[4])
    @test x.values.data[1:3] == [1.0, 2.0, 3.0]

    update_param!(m, :MyComp2, :x, [2, 3, 4, 5]) # change x to match 
    # Year      x       Model   MyComp2 
    # 2000      2       first   first
    # 2005      3               
    # 2020      4               last
    # 2100      5        last

    x = model_param(m, :MyComp2, :x)
    @test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2000, 2005, 2020, 2100)}, Union{Missing,Float64}, 1}
    @test x.values.data == [2., 3., 4., 5.]
    run(m)
    @test m[:MyComp2, :y][1] == 2   # 2000
    @test m[:MyComp2, :y][2] == 3   # 2005
    @test m[:MyComp2, :y][3] == 4   # 2020
    @test ismissing(m[:MyComp2, :y][4]) # 2100 - past last attribute for component 

    set_first_last!(m, :MyComp2, first = 2000, last = 2020)
    # Year      x       Model   MyComp2 
    # 2000      1       first   first
    # 2005      2               
    # 2020      3       last    last

    run(m)
    @test m[:MyComp2, :y][1:3] == [2., 3., 4.]
    @test ismissing(m[:MyComp2, :y][4])

    # 3. Test updating from a dictionary

    m = Model()
    set_dimension!(m, :time, [2000, 2005, 2020])
    add_comp!(m, MyComp2)
    update_param!(m, :MyComp2, :x, [1, 2, 3])

    set_dimension!(m, :time, [2000, 2005, 2020, 2100])

    update_params!(m, Dict((:MyComp2, :x)=>[2, 3, 4, 5]))
    x = model_param(m, :MyComp2, :x)
    @test x.values isa Mimi.TimestepArray{Mimi.VariableTimestep{(2000, 2005, 2020, 2100)}, Union{Missing,Float64}, 1}
    @test x.values.data == [2., 3., 4., 5.]
    run(m)

    @test m[:MyComp2, :y][1] == 2   # 2000
    @test m[:MyComp2, :y][2] == 3   # 2005
    @test m[:MyComp2, :y][3] == 4   # 2020
    @test ismissing(m[:MyComp2, :y][4])   # 2100

    # 4. Test updating the time index to a different length

    m = Model()
    set_dimension!(m, :time, 2000:2002)     # length 3
    add_comp!(m, MyComp2)
    update_param!(m, :MyComp2, :x, [1, 2, 3])
    # Year      x       Model   MyComp2 
    # 2000      1       first   first
    # 2001      2               
    # 2002      3       last    last

    set_dimension!(m, :time, 1999:2003)     # length 5
    update_param!(m, :MyComp2, :x, [2, 3, 4, 5, 6])
    # Year      x       Model   MyComp2 
    # 1999      2       first   
    # 2000      3               first
    # 2001      4               
    # 2002      5               last
    # 2003      6       last

    x = model_param(m, :MyComp2, :x)
    @test x.values isa Mimi.TimestepArray{Mimi.FixedTimestep{1999, 1, 2003}, Union{Missing, Float64}, 1, 1}
    @test x.values.data == [2., 3., 4., 5., 6.]

    run(m)
    @test ismissing(m[:MyComp2, :y][1]) 
    @test m[:MyComp2, :y][2:4] == [3., 4., 5.]
    @test ismissing(m[:MyComp2, :y][5]) 

    set_first_last!(m, :MyComp2, first = 1999, last = 2001)
    # Year      x       Model   MyComp2 
    # 1999      2       first   first
    # 2000      3               
    # 2001      4               last
    # 2002      5               
    # 2003      6       last

    run(m)
    @test ismissing(m[:MyComp2, :y][4])
    @test ismissing(m[:MyComp2, :y][5])
    @test m[:MyComp2, :y][1:3] == [2., 3., 4.]

    # 5. Test all the warning and error cases

    @defcomp MyComp3 begin
        regions=Index()
        x=Parameter(index=[time])       # One timestep array parameter
        y=Parameter(index=[regions])    # One non-timestep array parameter
        z=Parameter()                   # One scalar parameter
    end

    m = Model()                             # Build the model
    set_dimension!(m, :time, 2000:2002)     # Set the time dimension
    set_dimension!(m, :regions, [:A, :B])
    add_comp!(m, MyComp3)
    update_param!(m, :MyComp3, :x, [1, 2, 3])
    update_param!(m, :MyComp3, :y, [10, 20])
    update_param!(m, :MyComp3, :z, 0)

    @test_throws ErrorException update_param!(m, :x, [1, 2, 3, 4]) # Will throw an error because size
    update_param!(m, :MyComp3, :y, [10, 15])
    @test model_param(m, :MyComp3, :y).values == [10., 15.]
    update_param!(m, :MyComp3, :z, 1)
    @test model_param(m, :MyComp3, :z).value == 1

    # Reset the time dimensions
    set_dimension!(m, :time, 1999:2001)

    update_params!(m, Dict((:MyComp3, :x) =>[3,4,5], (:MyComp3, :y) =>[10,20], (:MyComp3, :z) =>0)) # Won't error when updating from a dictionary

    @test model_param(m, :MyComp3, :x).values isa Mimi.TimestepArray{Mimi.FixedTimestep{1999,1, 2001},Union{Missing,Float64},1}
    @test model_param(m, :MyComp3, :x).values.data == [3.,4.,5.]
    @test model_param(m, :MyComp3, :y).values == [10.,20.]
    @test model_param(m, :MyComp3, :z).value == 0

    #------------------------------------------------------------------------------
    # Test the three different set_param! methods for a Symbol type parameter
    #------------------------------------------------------------------------------

    @defcomp A begin
        p1 = Parameter{Symbol}()
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 10)
        add_comp!(m, A)
        return m
    end

    # Test the 3-argument version of set_param!
    m = _get_model()
    @test_throws MethodError set_param!(m, :p1, 3)  # Can't set it with an Int

    set_param!(m, :p1, :foo)    # Set it with a Symbol
    run(m)
    @test m[:A, :p1] == :foo

    # Test the 4-argument version of set_param!
    m = _get_model()
    @test_throws MethodError set_param!(m, :A, :p1, 3)

    set_param!(m, :A, :p1, :foo)
    run(m)
    @test m[:A, :p1] == :foo

    # Test the 5-argument version of set_param!
    m = _get_model()
    @test_throws MethodError set_param!(m, :A, :p1, :A_p1, 3)

    set_param!(m, :A, :p1, :A_p1, :foo)
    run(m)
    @test m[:A, :p1] == :foo


    #------------------------------------------------------------------------------
    # Test a few different update_param! methods for a Symbol type parameter
    #------------------------------------------------------------------------------

    @defcomp A begin
        p1 = Parameter{Symbol}()
    end

    function _get_model()
        m = Model()
        set_dimension!(m, :time, 10)
        add_comp!(m, A)
        return m
    end

    # Test the 3-argument version of update_param!
    m = _get_model()

    add_shared_param!(m, :p1_fail, 3)
    @test_throws ErrorException connect_param!(m, :A, :p1, :p1_fail)  # Can't connect it to an Int

    add_shared_param!(m, :p1, :foo) 
    connect_param!(m, :A, :p1, :p1) # connect it to a Symbol

    run(m)
    @test m[:A, :p1] == :foo

    # Test the 4-argument version of update_param!
    m = _get_model()
    @test_throws MethodError update_param!(m, :A, :p1, 3) # wrong type
    @test_throws MethodError update_param!(m, :A, :p1, [1,2,3]) # wrong type

    update_param!(m, :A, :p1, :foo)
    run(m)
    @test m[:A, :p1] == :foo

    #------------------------------------------------------------------------------
    # Test that if set_param! errors in the connection step, 
    #       the created param doesn't remain in the model's list of params
    #------------------------------------------------------------------------------

    @defcomp A begin
        p1 = Parameter(index = [time])
    end

    @defcomp B begin
        p1 = Parameter(index = [time])
    end

    m = Model()
    set_dimension!(m, :time, 10)
    add_comp!(m, A)
    add_comp!(m, B)

    @test_throws ErrorException set_param!(m, :p1, 1:5)     # this will error because the provided data is the wrong size
    @test !(:p1 in keys(model_params(m)))                     # But it should not be added to the model's dictionary

end
