@testitem "Timesteps" begin
    import Mimi:
        AbstractTimestep, FixedTimestep, VariableTimestep, TimestepVector,
        TimestepMatrix, TimestepArray, next_timestep, hasvalue, getproperty, Clock,
        time_index, get_timestep_array

    #------------------------------------------------------------------------------
    #  Test basic timestep functions and Base functions for Fixed Timestep
    #------------------------------------------------------------------------------

    t1 = FixedTimestep{1850, 10, 3000}(1)
    @test is_first(t1)
    @test t1 == TimestepIndex(1)
    @test t1 == TimestepValue(1850)
    @test TimestepIndex(1) == t1    # test both ways because to test both method definitions
    @test t1 == TimestepValue(1850)
    @test TimestepValue(1850) == t1 # test both ways because to test both method definitions
    @test_throws ErrorException t1_prev = t1-1 #first timestep, so cannot get previous

    t2 = next_timestep(t1)
    @test t2.t == 2
    @test t2 == TimestepIndex(2)
    @test t2 == TimestepValue(1860)
    @test t2 > TimestepIndex(1)
    @test t2 > TimestepValue(1850)
    @test t2 < TimestepIndex(3)
    @test t2 < TimestepValue(1870)
    @test_throws ErrorException t2_prev = t2 - 2 #can't get before first timestep

    @test t2 == t1 + 1
    @test t1 == t2 - 1

    t3 = FixedTimestep{2000, 1, 2050}(51)
    @test is_last(t3)
    @test_throws ErrorException t3_next = t3 + 2 #can't go beyond last timestep

    t4 = next_timestep(t3)
    @test t4 == TimestepIndex(52)
    @test t4 == TimestepValue(2051)
    @test_throws ErrorException t_next = t4 + 1
    @test_throws ErrorException next_timestep(t4)


    #------------------------------------------------------------------------------
    #  Test basic timestep functions and Base functions for Variable Timestep
    #------------------------------------------------------------------------------
    years = Tuple([2000:1:2024; 2025:5:2105])

    t1 = VariableTimestep{years}()
    @test is_first(t1)
    @test t1 == TimestepIndex(1)
    @test t1 == TimestepValue(2000)
    @test_throws ErrorException t1_prev = t1-1 #first timestep, so cannot get previous

    t2 = next_timestep(t1)
    @test t2.t == 2
    @test t2 == TimestepIndex(2)
    @test t2 == TimestepValue(2001)
    @test TimestepIndex(1) < t2
    @test TimestepValue(2000) < t2
    @test TimestepIndex(3) > t2
    @test TimestepValue(2002) > t2
    @test_throws ErrorException t2_prev = t2 - 2 #can't get before first timestep

    @test t2 == t1 + 1
    @test t1 == t2 - 1

    t3 = VariableTimestep{years}(42)
    @test is_last(t3)
    @test ! is_first(t3)
    @test_throws ErrorException t3_next = t3 + 2 #can't go beyond last timestep

    t4 = next_timestep(t3)
    @test t4 == TimestepIndex(43)

    # note here that this comes back to an assumption made in variable
    # timesteps that we may assume the next step is 1 year for the final year in TIMES
    @test t4 == TimestepValue(2106)
    @test_throws ErrorException t_next = t4 + 1
    @test_throws ErrorException next_timestep(t4)

    #------------------------------------------------------------------------------
    #  Test some basic functions for TimestepIndex and TimestepValue
    #------------------------------------------------------------------------------
    start = 1
    stop = 10
    step = 2

    # TimestepValue
    @test TimestepValue(2000, offset = 1) + 1 == TimestepValue(2000, offset = 2)
    @test TimestepValue(2000) + 1 == TimestepValue(2000, offset = 1)
    @test TimestepValue(2000, offset = 1) - 1 == TimestepValue(2000)

    # TimestepIndex
    @test TimestepIndex(start):TimestepIndex(stop) == TimestepIndex.([start:stop...])
    @test TimestepIndex(start):TimestepIndex(stop) == TimestepIndex(start):1:TimestepIndex(stop)
    @test TimestepIndex(start):step:TimestepIndex(stop) == TimestepIndex.([start:step:stop...])

    @test TimestepIndex(1) + 1 == TimestepIndex(2)
    @test TimestepIndex(2) - 1 == TimestepIndex(1)

    #------------------------------------------------------------------------------
    #  Test a model with components with different offsets
    #------------------------------------------------------------------------------

    # we'll have Bar run from 2000 to 2010
    # and Foo from 2005 to 2010

    @defcomp Foo begin
        inputF = Parameter()
        output = Variable(index=[time])

        function run_timestep(p, v, d, ts)
            v.output[ts] = p.inputF + ts.t
        end
    end

    @defcomp Bar begin
        inputB = Parameter(index=[time])
        output = Variable(index=[time])

        function run_timestep(p, v, d, ts)
            if ts < TimestepValue(2005)
                v.output[ts] = p.inputB[ts]
            else
                v.output[ts] = p.inputB[ts] * ts.t
            end
        end
    end

    years = 2000:2010
    first_foo = 2005

    m = Model()
    set_dimension!(m, :time, years)

    # test that you can only add components with first/last within model's time index range
    @test_throws ErrorException add_comp!(m, Foo; first=1900)
    @test_throws ErrorException add_comp!(m, Foo; last=2100)

    foo = add_comp!(m, Foo, first=first_foo)
    bar = add_comp!(m, Bar)

    update_param!(m, :Foo, :inputF, 5.)
    update_param!(m, :Bar, :inputB, collect(1:length(years)))

    run(m)

    @test length(m[:Foo, :output]) == length(years)
    @test length(m[:Bar, :output]) == length(years)

    yr_dim = Mimi.Dimension(years)
    idxs = yr_dim[first_foo]:yr_dim[years[end]]
    foo_output = m[:Foo, :output]

    offset = first_foo - years[1]
    for i in idxs
        @test foo_output[i] == 5+(i-offset) # incorporate offset into i now because we set ts.t to match component not model
    end

    for i in 1:5
        @test m[:Bar, :output][i] == i
    end

    for i in 6:11
        @test m[:Bar, :output][i] == i*i
    end

    #------------------------------------------------------------------------------
    #  test get_timestep_array
    #------------------------------------------------------------------------------

    m = Model()

    #fixed timestep to start
    set_dimension!(m, :time, 2000:2009)

    vector = ones(5)
    matrix = ones(3,2)

    t_vector = get_timestep_array(m.md, Float64, 1, 1, vector)
    t_matrix = get_timestep_array(m.md, Float64, 2, 1, matrix)

    @test typeof(t_vector) <: TimestepVector
    @test typeof(t_matrix) <: TimestepMatrix


    # try with variable timestep
    set_dimension!(m, :time, [2000:1:2004; 2005:2:2009])

    t_vector = get_timestep_array(m.md, Float64, 1, 1, vector)
    t_matrix = get_timestep_array(m.md, Float64, 2, 2, matrix)

    @test typeof(t_vector) <: TimestepVector
    @test typeof(t_matrix) <: TimestepMatrix


    #------------------------------------------------------------------------------
    #  Now build a model with connecting components
    #------------------------------------------------------------------------------

    @defcomp Foo2 begin
        inputF = Parameter(index=[time])
        output = Variable(index=[time])

        function run_timestep(p, v, d, ts)
            v.output[ts] = p.inputF[ts]
        end
    end

    m2 = Model()
    set_dimension!(m2, :time, years)
    bar = add_comp!(m2, Bar)
    foo2 = add_comp!(m2, Foo2, first = first_foo)

    update_param!(m2, :Bar, :inputB, collect(1:length(years)))
    connect_param!(m2, :Foo2, :inputF, :Bar, :output)

    run(m2)

    foo_output2 = m2[:Foo2, :output][yr_dim[first_foo]:yr_dim[years[end]]]
    for i in 1:6
        @test foo_output2[i] == (i+5)^2
    end

    #------------------------------------------------------------------------------
    #  Connect them in the other direction
    #------------------------------------------------------------------------------

    @defcomp Bar2 begin
        inputB = Parameter(index=[time])
        output = Variable(index=[time])

        function run_timestep(p, v, d, ts)
            v.output[ts] = p.inputB[ts] * ts.t
        end
    end

    years = 2000:2010

    m3 = Model()

    set_dimension!(m3, :time, years)
    add_comp!(m3, Foo, first=2005)
    add_comp!(m3, Bar2)

    update_param!(m3, :Foo, :inputF, 5.)
    connect_param!(m3, :Bar2, :inputB, :Foo, :output, zeros(length(years)))

    run(m3)

    @test length(m3[:Foo, :output]) == 11
    @test length(m3[:Bar2, :inputB]) == 11
    @test length(m3[:Bar2, :output]) == 11
end
