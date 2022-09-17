@testitem "GetDataframe" begin
    #------------------------------------------------------------------------------
    #   1. Test with 1 dimension
    #------------------------------------------------------------------------------

    model1 = Model()

    @defcomp testcomp1 begin
        var1 = Variable(index=[time])
        par1 = Parameter(index=[time])
        par_scalar = Parameter()

        function run_timestep(p, v, d, t)
            v.var1[t] = p.par1[t]
        end
    end

    late_first = 2030
    early_last = 2100

    @defcomp testcomp2 begin
        var2 = Variable(index=[time])
        par2 = Parameter(index=[time])

        function run_timestep(p, v, d, t)
            if TimestepValue(late_first) <= t <= TimestepValue(early_last)       # apply time constraints in the component
                v.var2[t] = p.par2[t]
            end
        end
    end

    years = collect(2015:5:2110)

    set_dimension!(model1, :time, years)
    add_comp!(model1, testcomp1)
    update_param!(model1, :testcomp1, :par1, years)
    update_param!(model1, :testcomp1, :par_scalar, 5.)

    add_comp!(model1, testcomp2)

    @test_throws ErrorException update_param!(model1, :testcomp2, :par2, late_first:5:early_last)
    @test ! (:par2 in keys(model1.md.model_params))  # Test that after the previous error, the :par2 didn't stay in the model's parameter list
    update_param!(model1, :testcomp2, :par2, years)

    # Test running before model built
    @test_throws ErrorException df = getdataframe(model1, :testcomp1, :var1)

    # Now run model
    run(model1)

    # Test trying to load a dataframe for a scalar parameter
    @test_throws ErrorException getdataframe(model1, :testcomp1, :par_scalar)

    # Test trying to getdataframe from a variable that does not exist in the component
    @test_throws ErrorException getdataframe(model1, :testcomp1, :var2)

    # Regular getdataframe
    df = getdataframe(model1, :testcomp1=>:var1, :testcomp1=>:par1, :testcomp2=>:var2, :testcomp2=>:par2)

    dim = Mimi.dimension(model1, :time)
    @test df.var1 == df.par1 == df.par2 == years
    @test all(ismissing, df.var2[1 : dim[late_first]-1])
    @test df.var2[dim[late_first] : dim[early_last]] == df.par2[dim[late_first] : dim[early_last]] == late_first:5:early_last
    @test all(ismissing, df.var2[dim[years[end]] : dim[early_last]])
    @test all(ismissing, df.var2[dim[early_last]+1 : dim[years[end]]])

    # Test trying to load an item into an existing dataframe where that item key already exists
    @test_throws UndefVarError _load_dataframe(model1, :testcomp1, :var1, df)


    #------------------------------------------------------------------------------
    #   2. Test with > 2 dimensions
    #------------------------------------------------------------------------------
    stepsize = 5
    years = collect(2015:stepsize:2110)
    regions = [:reg1, :reg2]
    rates   = [0.025, 0.05]

    nyears = length(years)
    nregions = length(regions)
    nrates = length(rates)

    @defcomp testcomp3 begin
        par3 = Parameter(index=[time, regions, rates])
        var3 = Variable(index=[time])
    end

    # A. Simple case where component has same time length as model

    model2 = Model()

    set_dimension!(model2, :time, years)
    set_dimension!(model2, :regions, regions)
    set_dimension!(model2, :rates, rates)

    data = Array{Int}(undef, nyears, nregions, nrates)
    data[:] = 1:(nyears * nregions * nrates)

    add_comp!(model2, testcomp3)
    update_param!(model2, :testcomp3, :par3, data)

    run(model2)

    df2 = getdataframe(model2, :testcomp3, :par3)
    @test size(df2) == (length(data), 4)

    # Test trying to combine two items with different dimensions into one dataframe
    @test_throws ErrorException getdataframe(model2, Pair(:testcomp3, :par3), Pair(:testcomp3, :var3))


    # B. Test with shorter time than model

    model3 = Model()
    set_dimension!(model3, :time, years)
    set_dimension!(model3, :regions, regions)
    set_dimension!(model3, :rates, rates)

    dim = Mimi.dimension(model3, :time)

    late_first = 2030
    early_last = 2100

    add_comp!(model3, testcomp3)

    indices = collect(late_first:stepsize:early_last)
    nindices = length(indices)

    valid_indices = collect(dim[late_first]:dim[early_last])
    nvalid = length(valid_indices)

    par3 = Array{Union{Missing,Float64}}(undef, nyears, nregions, nrates)
    par3[:] .= missing

    par3[valid_indices, :, :] = 1:(nindices * nregions * nrates)
    update_param!(model3, :testcomp3, :par3, par3)
    run(model3)

    df3 = getdataframe(model3, :testcomp3 => :par3)
    @test size(df3) == (nrates * nregions * nyears, 4)

    # Test that times outside the component's time span are padded with `missing` values
    @test all(ismissing, df3.par3[1 : (nrates * nregions * (dim[late_first] - 1))])

    nmissing = (Int((years[end] - early_last) / stepsize) * nregions * nrates - 1)

    @test all(ismissing, df3.par3[end - nmissing : end])

end
