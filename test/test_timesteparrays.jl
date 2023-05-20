@testitem "TimestepArrays" begin
    import Mimi:
        FixedTimestep, VariableTimestep, TimestepVector, TimestepMatrix, TimestepArray, next_timestep, hasvalue,
        isuniform, first_period, last_period, first_and_step

    function reset_time_val(arr, vals::Array{T, 1}) where T
        arr[:] = vals
    end

    function reset_time_val(arr, vals::Array{T, 2}) where T
        arr[:,:] = vals
    end

    function reset_time_val(arr, vals::Array{T, 3}) where T
        arr[:,:,:] = vals
    end

    ## quick check of isuniform
    @test isuniform([]) == false
    @test isuniform([1]) == true
    @test isuniform([1,2,3]) == true
    @test isuniform([1,2,3,5]) == false
    @test isuniform(1) == true

    @test first_and_step([2,3,4]) == (2,1)
    @test first_and_step([1:2:10...]) == (1,2)

    # shorthand for stuff used a lot
    idx1 = TimestepIndex(1)
    idx2 = TimestepIndex(2)
    idx3 = TimestepIndex(3)
    idx4 = TimestepIndex(4)

    #------------------------------------------------------------------------------
    # 1. Test TimestepVector - Fixed Timestep
    #------------------------------------------------------------------------------

    #1a.  test constructor, lastindex, and length (with both
    # matching years and mismatched years)

    x = TimestepVector{FixedTimestep{2000, 1, 2003}, Int}([9, 10, 11, 12])
    @test length(x) == 4
    @test lastindex(x) == TimestepIndex(4)

    time_dim_val = [9, 10, 11, 12]
    temp_dim_val = [100, 101, 102, 103]

    #1b.  test hasvalue, getindex, and setindex! (with both matching years and
    # mismatched years)

    # Using a colon in the time dimension
    @test x[:] == time_dim_val
    x[:] = temp_dim_val
    @test x[:] == temp_dim_val
    reset_time_val(x, time_dim_val)

    # TimestepValue and TimestepIndex Indexing
    @test x[idx1] == time_dim_val[1]
    @test x[idx1 + 1] == time_dim_val[2]
    @test x[idx4] == time_dim_val[4]
    @test_throws ErrorException x[TimestepIndex(5)]

    x[idx1] = temp_dim_val[1]
    @test x[idx1] == temp_dim_val[1]
    reset_time_val(x, time_dim_val)

    @test x[TimestepValue(2000)] == time_dim_val[1]
    @test x[TimestepValue(2000; offset = 1)] == time_dim_val[2]
    @test x[TimestepValue(2000) + 1] == time_dim_val[2]
    @test_throws ErrorException x[TimestepValue(2005)]
    @test_throws ErrorException x[TimestepValue(2004)+1]

    x[TimestepValue(2000)] = temp_dim_val[1]
    @test x[TimestepValue(2000)] == temp_dim_val[1]
    reset_time_val(x, time_dim_val)

    # AbstractTimestep Indexing
    t = FixedTimestep{2001, 1, 3000}(1)
    @test hasvalue(x, t)
    @test !hasvalue(x, FixedTimestep{2000, 1, 2012}(10))

    t = FixedTimestep{2000, 1, 3000}(1)
    @test x[t] == 9 # x

    t2 = next_timestep(t)
    @test x[t2] == time_dim_val[2]
    x[t2] = temp_dim_val[2]
    @test x[t2] == temp_dim_val[2]
    reset_time_val(x, time_dim_val)

    t3 = next_timestep(t2)
    @test x[t3] == time_dim_val[3]
    x[t3] = temp_dim_val[3]
    @test x[t3] == temp_dim_val[3]
    reset_time_val(x, time_dim_val)

    # Deprecated int indexing now errors
    @test_throws ErrorException x[3] == time_dim_val[3]
    @test_throws ErrorException x[3] = temp_dim_val[3]

    #------------------------------------------------------------------------------
    # 2. Test TimestepVector - Variable Timestep
    #------------------------------------------------------------------------------

    years = (2000, 2005, 2015, 2025)
    x = TimestepVector{VariableTimestep{years}, Int}([9, 10, 11, 12])

    time_dim_val = [9, 10, 11, 12]
    temp_dim_val = [100, 101, 102, 103]

    #2a.  test hasvalue, getindex, and setindex! (with both matching years and
    # mismatched years)

    # Using a colon in the time dimension
    @test x[:] == time_dim_val
    x[:] = temp_dim_val
    @test x[:] == temp_dim_val
    reset_time_val(x, time_dim_val)

    # TimestepValue and TimestepIndex Indexing
    @test x[idx1] == time_dim_val[1]
    @test x[idx1 + 1] == time_dim_val[2]
    @test x[idx4] == time_dim_val[4]
    @test_throws ErrorException x[TimestepIndex(5)]

    x[idx1] = temp_dim_val[1]
    @test x[idx1] == temp_dim_val[1]
    reset_time_val(x, time_dim_val)

    @test x[TimestepValue(2000)] == time_dim_val[1]
    @test x[TimestepValue(2000; offset = 1)] ==  time_dim_val[2]
    @test x[TimestepValue(2015)] ==  time_dim_val[3]
    @test x[TimestepValue(2015; offset = 1)] ==  time_dim_val[4]
    @test x[TimestepValue(2000) + 1] ==  time_dim_val[2]
    @test_throws ErrorException x[TimestepValue(2014)]
    @test_throws ErrorException x[TimestepValue(2025)+1]

    x[TimestepValue(2015)] = temp_dim_val[3]
    @test x[TimestepValue(2015)] == temp_dim_val[3]
    reset_time_val(x, time_dim_val)

    # AbstractTimestep Indexing
    y2 = Tuple([2005:5:2010; 2015:10:3000])
    t = VariableTimestep{y2}()

    @test hasvalue(x, t)
    @test !hasvalue(x, VariableTimestep{years}(time_dim_val[2]))
    @test x[t] == time_dim_val[1]

    t2 =  next_timestep(t)
    @test x[t2] == time_dim_val[2]
    x[t2] = temp_dim_val[2]
    @test x[t2] == temp_dim_val[2]
    reset_time_val(x, time_dim_val)

    t3 = VariableTimestep{years}()
    @test x[t3] == time_dim_val[1]
    x[t3] = temp_dim_val[1]
    @test x[t3] == temp_dim_val[1]
    reset_time_val(x, time_dim_val)

    @test x[TimestepIndex(3)] == time_dim_val[3]
    x[TimestepIndex(3)] = temp_dim_val[3]
    @test x[TimestepIndex(3)] == temp_dim_val[3]
    reset_time_val(x, time_dim_val)

    #------------------------------------------------------------------------------
    # 3. Test TimestepMatrix - Fixed Timestep
    #------------------------------------------------------------------------------

    for ti = 1:2

        #3a.  test constructor (with both matching years
        # and mismatched years)

        y = TimestepMatrix{FixedTimestep{2000, 1, 2003}, Int, ti}(collect(reshape(1:8, 4, 2)))
        z = TimestepMatrix{FixedTimestep{2000, 2, 2003}, Int, ti}(collect(reshape(1:8, 4, 2)))

        time_dim_val = collect(reshape(1:8, 4, 2))
        temp_dim_val = collect(reshape(100:107, 4, 2))

        #3b.  test hasvalue, getindex, and setindex! (with both matching years and
        # mismatched years)

        # Using a colon in the time dimension
        y[:,:] = temp_dim_val
        @test y[:,:] == temp_dim_val
        y[:,:] = time_dim_val # reset
        if ti == 1
            @test y[:,1] == time_dim_val[:,1]
            y[:, 1] = temp_dim_val[:,1]
            @test y[:, 1] == temp_dim_val[:,1]
        else
            @test y[1,:] == time_dim_val[1,:]
            y[1,:] = temp_dim_val[1,:]
            @test y[1,:] == temp_dim_val[1,:]
        end
        reset_time_val(y, time_dim_val)

        # TimestepValue and TimestepIndex Indexing
        if ti == 1
            @test y[idx1, 1] == time_dim_val[1,1]
            @test y[idx1, 2] == time_dim_val[1,2]
            @test y[idx1 + 1, 1] == time_dim_val[2,1]
            @test y[idx4, 2] == time_dim_val[4,2]
            @test_throws ErrorException y[TimestepIndex(5), 2]

            y[idx1, 1] = temp_dim_val[1]
            @test y[idx1, 1] == temp_dim_val[1]
            reset_time_val(y, time_dim_val)

            @test y[TimestepValue(2000), 1] == time_dim_val[1, 1]
            @test y[TimestepValue(2000), 2] == time_dim_val[1, 2]
            @test y[TimestepValue(2001), :] == time_dim_val[2, :]
            @test y[TimestepValue(2000; offset = 1), 1] == time_dim_val[2,1]
            @test y[TimestepValue(2000) + 1, 1] == time_dim_val[2,1]
            @test_throws ErrorException y[TimestepValue(2005), 1]
            @test_throws ErrorException y[TimestepValue(2004)+1, 1]

            y[TimestepValue(2000), 1] = temp_dim_val[1]
            @test y[TimestepValue(2000), 1] == temp_dim_val[1]
            reset_time_val(y, time_dim_val)
        else
            @test y[1, idx1] == time_dim_val[1,1]
            @test y[2, idx1] == time_dim_val[2, 1]
            @test y[1, idx1 + 1] == time_dim_val[1, 2]
            @test y[2, TimestepIndex(2)] == time_dim_val[2,2]
            @test_throws ErrorException y[2, TimestepIndex(3)]

            y[1, idx1] = temp_dim_val[1]
            @test y[1, idx1] == temp_dim_val[1]
            reset_time_val(y, time_dim_val)

            @test y[1, TimestepValue(2000)] == time_dim_val[1,1]
            @test y[2, TimestepValue(2000)] == time_dim_val[2,1]
            @test y[:, TimestepValue(2001)] == time_dim_val[:,2]
            @test y[1, TimestepValue(2000; offset = 1)] == time_dim_val[1,2]
            @test y[1, TimestepValue(2000) + 1] == time_dim_val[1,2]
            @test_throws BoundsError y[1, TimestepValue(2003)]
            @test_throws BoundsError y[1, TimestepValue(2002)+1]

            y[1, TimestepValue(2000)] = temp_dim_val[1]
            @test y[1, TimestepValue(2000)] == temp_dim_val[1]
            reset_time_val(y, time_dim_val)
        end

        # AbstractTimestep Indexing
        t = FixedTimestep{2000, 1, 3000}(1)
        @test hasvalue(y, t, 1)
        @test !hasvalue(y, FixedTimestep{2000, 1, 3000}(10), 1)
        t = next_timestep(t)
        if ti == 1
            @test y[t,1] == time_dim_val[2,1]
            @test y[t,2] == time_dim_val[2,2]

            t2 = next_timestep(t)
            @test y[t2,1] == time_dim_val[3,1]
            @test y[t2,2] == time_dim_val[3,2]
            y[t2, 1] = temp_dim_val[3,1]
            @test y[t2, 1] == temp_dim_val[3,1]
            reset_time_val(y, time_dim_val)

            t3 = FixedTimestep{2000, 1, 2005}(1)
            @test y[t3, 1] == time_dim_val[1,1]
            @test y[t3, 2] == time_dim_val[1,2]
            y[t3, 1] = temp_dim_val[1,1]
            @test y[t3,1] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)

            #3c.  interval wider than 1 using z from above
            t = FixedTimestep{1980, 2, 3000}(1)

            @test z[t,1] == time_dim_val[1,1]
            @test z[t,2] == time_dim_val[1,2]

            t2 = next_timestep(t)
            @test z[t2,1] == time_dim_val[2,1]
            @test z[t2,2] == time_dim_val[2,2]

        else
            @test y[1, t] == time_dim_val[1,2]
            @test y[2, t] == time_dim_val[2,2]

            t2 = FixedTimestep{2000, 1, 2005}(1)
            @test y[1, t2] == time_dim_val[1,1]
            @test y[2, t2] == time_dim_val[2,1]
            y[1, t2] = temp_dim_val[1,1]
            @test y[1, t2] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)

            #3c.  interval wider than 1 using z from above
            t = FixedTimestep{1980, 2, 3000}(1)

            @test z[1, t] == time_dim_val[1,1]
            @test z[2, t] == time_dim_val[2,1]

            t2 = next_timestep(t)
            @test z[1, t2] == time_dim_val[1,2]
            @test z[2, t2] == time_dim_val[2,2]
        end

        @test y[idx1, 2] == time_dim_val[1,2]
        @test z[idx1, 2] == time_dim_val[1,2]
        y[idx1, 2] = temp_dim_val[1]
        z[idx1, 2] = temp_dim_val[1]
        @test y[idx1, 2] == z[idx1, 2] == temp_dim_val[1]

        reset_time_val(y, time_dim_val)
        reset_time_val(z, time_dim_val)
    end

    #------------------------------------------------------------------------------
    # 4. Test TimestepMatrix - Variable Timestep
    #------------------------------------------------------------------------------

    for ti = 1:2

        #4a.  test constructor (with both matching years
        # and mismatched years)

        if ti == 1
            years = Tuple([2000:5:2005; 2015:10:2025])
        else
            years = (2000, 2005)
        end
        y = TimestepMatrix{VariableTimestep{years}, Int, ti}(collect(reshape(1:8, 4, 2)))

        time_dim_val = collect(reshape(1:8, 4, 2))
        temp_dim_val = collect(reshape(100:107, 4, 2))

        #4b.  test hasvalue, getindex, setindex!, and lastindex (with both matching years and
        # mismatched years)

        # Using a colon in the time dimension
        y[:,:] = temp_dim_val
        @test y[:,:] == temp_dim_val
        y[:,:] = time_dim_val # reset
        if ti == 1
            @test y[:,1] == time_dim_val[:,1]
            y[:, 1] = temp_dim_val[:,1]
            @test y[:, 1] == temp_dim_val[:,1]
        else
            @test y[1,:] == time_dim_val[1,:]
            y[1,:] = temp_dim_val[1,:]
            @test y[1,:] == temp_dim_val[1,:]
        end
        reset_time_val(y, time_dim_val)

        # TimestepValue and TimestepIndex Indexing
        if ti == 1
            @test y[idx1, 1] == time_dim_val[1,1]
            @test y[idx1, 2] == time_dim_val[1,2]
            @test y[idx1 + 1, 1] == time_dim_val[2,1]
            @test y[idx4, 2] == time_dim_val[4,2]
            @test_throws ErrorException y[TimestepIndex(5),2]

            y[idx1, 1] = temp_dim_val[1,1]
            @test y[idx1, 1] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)

            @test y[TimestepValue(2000), 1] == time_dim_val[1,1]
            @test y[TimestepValue(2000), 2] == time_dim_val[1,2]
            @test y[TimestepValue(2000; offset = 1), 1] == time_dim_val[2,1]
            @test y[TimestepValue(2000) + 1, 1] == time_dim_val[2,1]
            @test y[TimestepValue(2015), 1] == time_dim_val[3,1]
            @test y[TimestepValue(2015) + 1, 2] == time_dim_val[4,2]
            @test_throws ErrorException y[TimestepValue(2006), 1]
            @test_throws ErrorException y[TimestepValue(2025)+1, 1]

            y[TimestepValue(2015), 1] = temp_dim_val[3,1]
            @test y[TimestepValue(2015), 1] == temp_dim_val[3,1]
            reset_time_val(y, time_dim_val)
        else
            @test y[1, idx1] == time_dim_val[1,1]
            @test y[2, idx1] == time_dim_val[2,1]
            @test y[1, idx1 + 1] == time_dim_val[1,2]
            @test y[2, TimestepIndex(2)] == time_dim_val[2,2]
            @test_throws ErrorException y[2, TimestepIndex(3)]

            y[1, idx1] = temp_dim_val[1,1]
            @test y[1, idx1] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)

            @test y[1, TimestepValue(2000)] == time_dim_val[1,1]
            @test y[2, TimestepValue(2000)] == time_dim_val[2,1]
            @test y[1, TimestepValue(2000; offset = 1)] == time_dim_val[1,2]
            @test y[1, TimestepValue(2000) + 1] == time_dim_val[1,2]
            @test y[1, TimestepValue(2005)] == time_dim_val[1,2]
            @test_throws ErrorException y[1, TimestepValue(2006)]
            @test_throws ErrorException y[1, TimestepValue(2005)+1]

            y[1, TimestepValue(2005)] = temp_dim_val[1,2]
            @test y[1, TimestepValue(2005)] == temp_dim_val[1,2]
            reset_time_val(y, time_dim_val)
        end

        # AbstractTimestep Indexing
        t = VariableTimestep{Tuple([2005:5:2010; 2015:10:3000])}()
        if ti == 1
            @test hasvalue(y, t, time_dim_val[1])
            @test !hasvalue(y, VariableTimestep{years}(10))

            t2 = next_timestep(t)
            @test y[t2,1] == time_dim_val[2,1]
            @test y[t2,2] == time_dim_val[2,2]

            t3 = next_timestep(t2)
            @test y[t3,1] == time_dim_val[3,1]
            @test y[t3,2] == time_dim_val[3,2]
            y[t3, 1] = temp_dim_val[3,1]
            @test y[t3, 1] == temp_dim_val[3,1]
            reset_time_val(y, time_dim_val)

            t3 = VariableTimestep{years}()
            @test y[t3, 1] == time_dim_val[1,1]
            @test y[t3, 2] == time_dim_val[1,2]
            y[t3, 1] = temp_dim_val[1,1]
            @test y[t3,1] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)

        else
            @test hasvalue(y, t, time_dim_val[1])
            @test !hasvalue(y, VariableTimestep{years}(10))

            t2 = next_timestep(t)
            @test y[1,t2] == time_dim_val[1,2]
            @test y[2,t2] == time_dim_val[2,2]

            t3 = VariableTimestep{years}()
            @test y[1, t3] == time_dim_val[1,1]
            @test y[2, t3] == time_dim_val[2,1]
            y[1,t3] = temp_dim_val[1,1]
            @test y[1,t3] == temp_dim_val[1,1]
            reset_time_val(y, time_dim_val)
        end

        @test y[idx1,2] == time_dim_val[1,2]
        y[idx1,2] = temp_dim_val[1,2]
        @test y[idx1,2] == temp_dim_val[1,2]
        reset_time_val(y, time_dim_val)
    end

    #------------------------------------------------------------------------------
    # 5. Test TimestepArray methods (3 dimensional)
    #------------------------------------------------------------------------------

    for ti = 1:2

        years = Tuple([2000:5:2005; 2015:10:2025])
        arr_fixed = TimestepArray{FixedTimestep{2000, 5, 2020}, Int, 3, ti}(collect(reshape(1:64, 4, 4, 4)))
        arr_variable = TimestepArray{VariableTimestep{years}, Int, 3, ti}(collect(reshape(1:64, 4, 4, 4)))

        time_dim_val = collect(reshape(1:64, 4, 4, 4))
        temp_dim_val = collect(reshape(100:163, 4, 4, 4))

        # Using a colon in the time dimension
        if ti == 1
            @test arr_fixed[:,1,1] == arr_variable[:,1,1] == time_dim_val[:,1,1]
            @test arr_fixed[:,2,3] == arr_variable[:,2,3] == time_dim_val[:,2,3]
            arr_fixed[:,1,1] = temp_dim_val[:,1,1]
            arr_variable[:,1,1] = temp_dim_val[:,1,1]
            @test arr_fixed[:,1,1] == arr_variable[:,1,1] == temp_dim_val[:,1,1]
            arr_fixed[:,:,2] = temp_dim_val[:,:,2]
            arr_variable[:,:,2] = temp_dim_val[:,:,2]
            @test arr_fixed[:,:,2] == arr_variable[:,:,2] == temp_dim_val[:,:,2]
            arr_fixed[:,:,:] = temp_dim_val
            arr_variable[:,:,:] = temp_dim_val
            @test arr_fixed[:,:,:] == arr_variable[:,:,:] == temp_dim_val[:,:,:]
        else
            @test arr_fixed[1,:,1] == arr_variable[1,:,1] == time_dim_val[1,:,1]
            @test arr_fixed[2,:,3] == arr_variable[2,:,3] == time_dim_val[2,:,3]
            arr_fixed[1,:,1] = temp_dim_val[1,:,1]
            arr_variable[1,:,1] = temp_dim_val[1,:,1]
            @test arr_fixed[1,:,1] == arr_variable[1,:,1] == temp_dim_val[1,:,1]
            arr_fixed[:,:,2] = temp_dim_val[:,:,2]
            arr_variable[:,:,2] = temp_dim_val[:,:,2]
            @test arr_fixed[:,:,2] == arr_variable[:,:,2] == temp_dim_val[:,:,2]
            arr_fixed[:,:,:] = temp_dim_val
            arr_variable[:,:,:] = temp_dim_val
            @test arr_fixed[:,:,:] == arr_variable[:,:,:] == temp_dim_val[:,:,:]
        end
        reset_time_val(arr_fixed, time_dim_val)
        reset_time_val(arr_variable, time_dim_val)

        @test_throws ErrorException arr_fixed[TimestepValue(2000)]
        @test_throws ErrorException arr_variable[TimestepValue(2000)]

        # Indexing with single TimestepIndex
        if ti == 1
            @test arr_fixed[idx1, 1, 1] == arr_variable[idx1, 1, 1] == time_dim_val[1,1,1]
            @test arr_fixed[TimestepIndex(3), 3, 3] == arr_variable[TimestepIndex(3), 3, 3] == time_dim_val[3,3,3]

            arr_fixed[idx1, 1, 1] = temp_dim_val[1,1,1]
            arr_variable[idx1, 1, 1] = temp_dim_val[1,1,1]
            @test arr_fixed[idx1, 1, 1] == arr_variable[idx1, 1, 1] == temp_dim_val[1,1,1]
            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            @test_throws ErrorException arr_fixed[idx1]
            @test_throws ErrorException arr_variable[idx1]

            # Indexing with Array{TimestepIndex, N}
            @test arr_fixed[TimestepIndex.([1,3]), 1, 1] == time_dim_val[[1,3], 1, 1]
            @test arr_variable[TimestepIndex.([2,4]), 1, 1] == time_dim_val[[2,4], 1, 1]

            # Indexing with Array{TimestepIndex, N} created by Colon syntax
            @test arr_fixed[idx1:TimestepIndex(3), 1, 1] == time_dim_val[[1:3...], 1, 1]
            @test arr_fixed[idx1:2:TimestepIndex(3), 1, 1] == time_dim_val[[1:2:3...], 1, 1]

            # Indexing with single TimestepValue
            @test arr_fixed[TimestepValue(2000), 1, 1] == arr_variable[TimestepValue(2000), 1, 1] == time_dim_val[1,1,1]
            @test arr_fixed[TimestepValue(2010), 3, 3] == arr_variable[TimestepValue(2015), 3, 3] == time_dim_val[3,3,3]

            arr_fixed[TimestepValue(2000), 1, 1] = time_dim_val[1,1,1]
            arr_variable[TimestepValue(2000), 1, 1] = time_dim_val[1,1,1]
            @test arr_fixed[TimestepValue(2000), 1, 1] == arr_variable[TimestepValue(2000), 1, 1] == time_dim_val[1,1,1]
            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            # Indexing with Array{TimestepValue, N}
            @test arr_fixed[TimestepValue.([2000, 2010]), 1, 1] == time_dim_val[[1,3],1,1]
            @test arr_variable[TimestepValue.([2000, 2005, 2025]), 1, 1] == time_dim_val[[1,2,4],1,1]

            arr_fixed[TimestepValue.([2000, 2010]), 1, 1] = temp_dim_val[[1,3],1,1]
            arr_variable[TimestepValue.([2000, 2005, 2025]), 1, 1] = temp_dim_val[[1,2,4],1,1]
            @test arr_fixed[TimestepValue.([2000, 2010]), 1, 1] == temp_dim_val[[1,3],1,1]
            @test arr_variable[TimestepValue.([2000, 2005, 2025]), 1, 1] == temp_dim_val[[1,2,4],1,1]

            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            @test arr_fixed[idx1,2,3] == time_dim_val[1,2,3]
            @test arr_variable[idx1,2,3] == time_dim_val[1,2,3]
            arr_fixed[idx1,2,3] = temp_dim_val[1,2,3]
            arr_variable[idx1,2,3] = temp_dim_val[1,2,3]
            @test arr_fixed[idx1,2,3] == arr_variable[idx1,2,3] == temp_dim_val[1,2,3]

        else

            @test arr_fixed[1, idx1, 1] == arr_variable[1, idx1, 1] == time_dim_val[1,1,1]
            @test arr_fixed[3, TimestepIndex(3), 3] == arr_variable[3, TimestepIndex(3), 3] == time_dim_val[3,3,3]

            arr_fixed[1, idx1, 1] = temp_dim_val[1,1,1]
            arr_variable[1, idx1, 1] = temp_dim_val[1,1,1]
            @test arr_fixed[1, idx1, 1] == arr_variable[1, idx1, 1] == temp_dim_val[1,1,1]
            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            # Indexing with Array{TimestepIndex, N}
            @test arr_fixed[1, TimestepIndex.([1,3]), 1] == time_dim_val[1, [1,3], 1]
            @test arr_variable[1, TimestepIndex.([2,4]), 1] == time_dim_val[1, [2,4], 1]

            # Indexing with Array{TimestepIndex, N} created by Colon syntax
            @test arr_fixed[1, idx1:TimestepIndex(3), 1] == time_dim_val[1, [1:3...], 1]
            @test arr_fixed[1, idx1:2:TimestepIndex(3), 1] == time_dim_val[1, [1:2:3...], 1]

            # Indexing with single TimestepValue
            @test arr_fixed[1, TimestepValue(2000), 1] == arr_variable[1, TimestepValue(2000), 1] == time_dim_val[1,1,1]
            @test arr_fixed[3, TimestepValue(2010), 3] == arr_variable[3, TimestepValue(2015), 3] == time_dim_val[3,3,3]

            arr_fixed[1, TimestepValue(2000), 1] = temp_dim_val[1,1,1]
            arr_variable[1, TimestepValue(2000), 1] = temp_dim_val[1,1,1]
            @test arr_fixed[1, TimestepValue(2000), 1] == arr_variable[1, TimestepValue(2000), 1] == temp_dim_val[1,1,1]
            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            # Indexing with Array{TimestepValue, N}
            @test arr_fixed[1, TimestepValue.([2000, 2010]), 1] == time_dim_val[1, [1,3],1]
            @test arr_variable[1, TimestepValue.([2000, 2005, 2025]), 1] == time_dim_val[1,[1,2,4],1]
            arr_fixed[1, TimestepValue.([2000, 2010]), 1] = temp_dim_val[1, [1,3],1]
            arr_variable[1, TimestepValue.([2000, 2005, 2025]), 1] = temp_dim_val[1,[1,2,4],1]
            @test arr_fixed[1, TimestepValue.([2000, 2010]), 1] == temp_dim_val[1, [1,3],1]
            @test arr_variable[1, TimestepValue.([2000, 2005, 2025]), 1] == temp_dim_val[1,[1,2,4],1]

            reset_time_val(arr_fixed, time_dim_val)
            reset_time_val(arr_variable, time_dim_val)

            @test arr_fixed[1,idx2,3] == time_dim_val[1,2,3]
            @test arr_variable[1,idx2,3] == time_dim_val[1,2,3]
            arr_fixed[1,idx2,3] = temp_dim_val[1,2,3]
            arr_variable[1,idx2,3] = temp_dim_val[1,2,3]
            @test arr_fixed[1,idx2,3] == arr_variable[1,idx2,3] == temp_dim_val[1,2,3]
        end

        reset_time_val(arr_fixed, time_dim_val)
        reset_time_val(arr_variable, time_dim_val)
    end

    # other methods
    time_dim_val = collect(reshape(1:64, 4, 4, 4))

    x_years = Tuple(2000:5:2015) #fixed
    y_years = Tuple([2000:5:2005; 2015:10:2025]) #variable

    x_vec = TimestepVector{FixedTimestep{2000, 5, 2015}, Int}(time_dim_val[:,1,1])
    x_mat = TimestepMatrix{FixedTimestep{2000, 5, 2015}, Int, 1}(time_dim_val[:,:,1])
    y_vec = TimestepVector{VariableTimestep{y_years}, Int}(time_dim_val[:,2,2])
    y_mat = TimestepMatrix{VariableTimestep{y_years}, Int, 1}(time_dim_val[:,:,2])

    @test first_period(x_vec) == first_period(x_mat) == x_years[1]
    @test first_period(y_vec) == first_period(y_mat) == y_years[1]
    @test last_period(x_vec) == last_period(x_mat) == x_years[end]
    @test last_period(y_vec) == last_period(y_mat) == y_years[end]

    @test size(x_vec) == size(y_vec) == (4,)
    @test size(x_mat) == size(y_mat) == (4,4)

    @test ndims(x_vec) == ndims(y_vec) == 1
    @test ndims(x_mat) == ndims(y_mat) == 2

    @test eltype(x_vec) == eltype(y_vec) == eltype(y_vec) == eltype(y_mat) == eltype(time_dim_val)

    @test x_vec[begin] == time_dim_val[:,1,1][begin]
    @test x_mat[begin,1] == time_dim_val[:,:,1][begin,1]
    @test x_mat[begin,2] == time_dim_val[:,:,1][begin,2]
    @test y_vec[begin] == time_dim_val[:,2,2][begin]
    @test y_mat[begin,1] == time_dim_val[:,:,2][begin,1]
    @test y_mat[begin,2] == time_dim_val[:,:,2][begin,2]

    @test x_vec[end] == time_dim_val[:,1,1][end]
    @test x_mat[end,1] == time_dim_val[:,:,1][end,1]
    @test x_mat[end,2] == time_dim_val[:,:,1][end,2]
    @test y_vec[end] == time_dim_val[:,2,2][end]
    @test y_mat[end,1] == time_dim_val[:,:,2][end,1]
    @test y_mat[end,2] == time_dim_val[:,:,2][end,2]

    #------------------------------------------------------------------------------
    # 6. Test that getindex for TimestepArrays doesn't allow access to `missing`
    #       values during `run` that haven't been computed yet.
    #------------------------------------------------------------------------------

    @defcomp foo begin
        par1 = Parameter(index=[time])
        var1 = Variable(index=[time])
        function run_timestep(p, v, d, t)
            if is_last(t)
                v.var1[t] = 0
            else
                v.var1[t] = p.par1[t+1]   # This is where the error will be thrown, if connected to an internal variable that has not yet been computed.
            end
        end
    end

    @defcomp bar begin
        par2 = Parameter(index=[time])
        var2 = Variable(index=[time])
        function run_timestep(p, v, d, t)
            if is_last(t)
                v.var2[t] = 0
            else
                v.var2[t] = p.par2[t+1]   # This is where the error will be thrown, if connected to an internal variable that has not yet been computed.
            end
        end
    end

    years = 2000:2010

    m = Model()
    set_dimension!(m, :time, years)
    add_comp!(m, foo, :first)
    add_comp!(m, bar, :second)
    connect_param!(m, :second => :par2, :first => :var1)
    update_param!(m, :first, :par1, 1:length(years))

    @test_throws MissingException run(m)

    #------------------------------------------------------------------------------
    # 7. Test TimestepArrays with time not as the first dimension
    #------------------------------------------------------------------------------

    @defcomp gdp begin
        growth = Parameter(index=[regions, foo, time, 2])   # test that time is not first but not last
        gdp = Variable(index=[regions, foo, time, 2])
        gdp0 = Parameter(index=[regions, foo, 2])

        pgrowth = Parameter(index=[regions, 3, time])       # test time as last
        pop = Variable(index=[regions, 3, time])

        mat = Parameter(index=[regions, time])              # test time as last for a matrix
        mat2 = Variable(index=[regions, time])

        function run_timestep(p, v, d, ts)
            if is_first(ts)
                v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* p.gdp0
                v.pop[:, :, ts] = zeros(2, 3)
            else
                v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* v.gdp[:, :, ts-1, :]
                v.pop[:, :, ts] = v.pop[:, :, ts-1] .+ p.pgrowth[:, :, ts]
            end
            v.mat2[:, ts] = p.mat[:, ts]
        end
    end

    time_index = 2000:2100
    regions = ["OECD","non-OECD"]
    nsteps=length(time_index)

    m = Model()
    set_dimension!(m, :time, time_index)
    set_dimension!(m, :regions, regions)
    set_dimension!(m, :foo, 3)
    add_comp!(m, gdp)
    update_param!(m, :gdp, :gdp0, [3; 7] .* ones(length(regions), 3, 2))
    update_param!(m, :gdp, :growth, [0.02; 0.03] .* ones(length(regions), 3, nsteps, 2))
    set_leftover_params!(m, Dict{String, Any}([
        "pgrowth" => ones(length(regions), 3, nsteps),
        "mat" => rand(length(regions), nsteps)
    ]))
    run(m)

    @test size(m[:gdp, :gdp]) == (length(regions), 3, length(time_index), 2)

    @test all(!ismissing, m[:gdp, :gdp])
    @test all(!ismissing, m[:gdp, :pop])
    @test all(!ismissing, m[:gdp, :mat2])

    #------------------------------------------------------------------------------
    # 8. Check broadcast assignment to underlying array
    #------------------------------------------------------------------------------

    x = Mimi.TimestepVector{Mimi.FixedTimestep{2005,10,2095}, Float64}(zeros(10))
    y = TimestepMatrix{FixedTimestep{2000, 1, 2003}, Float64, 1}(collect(reshape(zeros(8), 4, 2)))

    # colon and ints
    x[:] .= 10
    y[:] .= 10
    @test all(y.data .== 10)
    @test all(x.data .== 10)

    y[:,1] .= 20
    @test all(y.data[:,1] .== 20)

    reset_time_val(x, zeros(10))
    reset_time_val(y, collect(reshape(zeros(8), 4, 2)))

    # TimestepIndex
    y[TimestepIndex(2),:] .= 10
    @test all(y.data[2,:] .== 10)

    reset_time_val(x, zeros(10))
    reset_time_val(y, collect(reshape(zeros(8), 4, 2)))

    #------------------------------------------------------------------------------
    # 8. Test handling of offsets for TimestepValue and TimestepIndex with a TimestepMatrix
    #   --> this is a very specific test to handle PR #857, specifically for methods
    #       using offset - 1 in time.jl
    #------------------------------------------------------------------------------

    @defcomp testcomp begin

        var_tvalue = Variable(index=[time, regions])
        var_tindex = Variable(index=[time, regions])

        function run_timestep(p, v, d, t)
            for r in d.regions
                tvalue = TimestepValue(2003)
                tindex = TimestepIndex(1)

                v.var_tvalue[tvalue,r] = 999
                v.var_tindex[tindex,r] = 999
            end
        end
    end

    m = Model()
    set_dimension!(m, :time, 2000:2005)
    set_dimension!(m, :regions, ["A", "B"])
    add_comp!(m, testcomp, first = 2003)
    run(m)

    @test m[:testcomp, :var_tvalue][findfirst(i -> i == 2003, 2000:2005), :] == [999., 999.]
    @test m[:testcomp, :var_tindex][findfirst(i -> i == 2003, 2000:2005), :] == [999., 999.]
end
