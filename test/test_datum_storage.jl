@testitem "DatumStorage" begin
    comp_first = 2003
    comp_last = 2008

    @defcomp foo begin
        v = Variable(index = [time])
        function run_timestep(p, v, d, ts)
            # implement "short component" via time checking
            if TimestepValue(comp_first) <= ts <= TimestepValue(comp_last)
                v.v[ts] = gettime(ts)
            end
        end
    end

    @defcomp bar begin
        region = Index()
        v = Variable(index = [time, region])
        function run_timestep(p, v, d, ts)
            v.v[ts, :] .= gettime(ts)
        end
    end

    years = 2001:2010
    regions = [:A, :B]

    nyears = length(years)
    nregions = length(regions)

    #------------------------------------------------------------------------------
    # 1. Single dimension case, fixed timesteps
    #------------------------------------------------------------------------------

    m = Model()
    set_dimension!(m, :time, years)
    add_comp!(m, foo)

    run(m)
    v = m[:foo, :v]
    @test length(v) == nyears # Test that the array allocated for variable v is the full length of the time dimension

    # Test that the missing values were filled in before/after the first/last values
    for (i, y) in enumerate(years)
        if y < comp_first || y > comp_last
            @test ismissing(v[i])
        else
            @test v[i] == y
        end
    end

    #------------------------------------------------------------------------------
    # 2. Multi-dimension case, fixed timesteps
    #------------------------------------------------------------------------------

    m2 = Model()

    @defcomp baz begin
        region = Index()
        v = Variable(index = [time, region])
        function run_timestep(p, v, d, ts)
            # implement "short component" via time checking
            if TimestepValue(comp_first) <= ts <= TimestepValue(comp_last)
                v.v[ts, :] .= gettime(ts)
            end
        end
    end

    set_dimension!(m2, :time, years)
    set_dimension!(m2, :region, regions)

    add_comp!(m2, baz)

    run(m2)
    v2 = m2[:baz, :v]
    @test size(v2) == (nyears, nregions) # Test that the array allocated for variable v is the full length of the time dimension

    # Test that the missing values were filled in before/after the first/last values
    for (i, y) in enumerate(years)
        if y < comp_first || y > comp_last
            [@test ismissing(v2[i, j]) for j in 1:nregions]
        else
            [@test v2[i, j]==y for j in 1:nregions]
        end
    end


    #------------------------------------------------------------------------------
    # 3. Single dimension case, variable timesteps
    #------------------------------------------------------------------------------

    years_variable = [2000:2004..., 2005:5:2030...]
    foo2_first = 2003
    foo2_last = 2010

    m = Model()
    set_dimension!(m, :time, years_variable)

    @defcomp foo2 begin
        v = Variable(index = [time])
        function run_timestep(p, v, d, ts)
            # implement "short component" via time checking
            if TimestepValue(foo2_first) <= ts <= TimestepValue(foo2_last)
                v.v[ts] = gettime(ts)
            end
        end
    end

    add_comp!(m, foo2)

    run(m)
    v = m[:foo2, :v]
    @test length(v) == length(years_variable) # Test that the array allocated for variable v is the full length of the time dimension

    # Test that the missing values were filled in before/after the first/last values
    for (i, y) in enumerate(years_variable)
        if y < foo2_first || y > foo2_last
            @test ismissing(v[i])
        else
            @test v[i] == y
        end
    end

    #------------------------------------------------------------------------------
    # 4. Multi-dimension case, variable timesteps
    #------------------------------------------------------------------------------

    m2 = Model()

    buz_first = 2003
    buz_last = 2010

    @defcomp buz begin
        region = Index()
        v = Variable(index = [time, region])
        function run_timestep(p, v, d, ts)
            # implement "short component" via time checking
            if TimestepValue(buz_first) <= ts <= TimestepValue(buz_last)
                v.v[ts, :] .= gettime(ts)
            end
        end
    end

    set_dimension!(m2, :time, years_variable)
    set_dimension!(m2, :region, regions)
    add_comp!(m2, buz)
    run(m2)
    v2 = m2[:buz, :v]
    @test size(v2) == (length(years_variable), nregions) # Test that the array allocated for variable v is the full length of the time dimension

    # Test that the missing values were filled in before/after the first/last values
    for (i, y) in enumerate(years_variable)
        if y < buz_first || y > buz_last
            [@test ismissing(v2[i, j]) for j in 1:nregions]
        else
            [@test v2[i, j]==y for j in 1:nregions]
        end
    end
end
