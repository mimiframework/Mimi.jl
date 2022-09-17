@testitem "MarginalModels" begin
    @defcomp compA begin
        varA = Variable(index=[time])
        parA = Parameter(index=[time])
        
        function run_timestep(p, v, d, t)
            v.varA[t] = p.parA[t]
        end
    end

    x1 = collect(1:10)
    x2 = collect(2:2:20)

    model1 = Model()
    set_dimension!(model1, :time, collect(1:10))
    add_comp!(model1, compA)
    update_param!(model1, :compA, :parA, x1)

    mm = MarginalModel(model1, .5)

    model2 = mm.modified
    add_shared_param!(model2, :parA, x2; dims = [:time])
    connect_param!(model2, :compA, :parA, :parA)

    run(mm)

    for i in collect(1:10)
        @test mm[:compA, :varA][i] == 2*i
    end

    mm2 = create_marginal_model(model1, 0.5)
    @test_throws ErrorException mm2_modified = mm2.marginal     # test that trying to access by the old field name, "marginal", now errors
    mm2_modified = mm2.modified

    update_param!(mm2_modified, :compA, :parA, x2)

    run(mm2)

    for i in collect(1:10)
        @test mm2[:compA, :varA][i] == 2*i 
    end

end
