@testitem "ComponentsOrdering" begin
    my_model = Model()

    #Testing that you cannot add two components of the same name
    @defcomp testcomp1 begin
        var1 = Variable(index=[time])
        par1 = Parameter(index=[time])
        
        function run_timestep(p, v, d, t)
            v.var1[t] = p.par1[t]
        end
    end

    @defcomp testcomp2 begin
        var1 = Variable(index=[time])
        par1 = Parameter(index=[time])
        
        function run_timestep(p, v, d, t)
            v.var1[t] = p.par1[t]
        end
    end

    @defcomp testcomp3 begin
        var1 = Variable(index=[time])
        par1 = Parameter(index=[time])
        
        function run_timestep(p, v, d, t)
            v.var1[t] = p.par1[t]
        end
    end

    set_dimension!(my_model, :time, 2015:5:2110)
    add_comp!(my_model, testcomp1)

    @test_throws ErrorException add_comp!(my_model, testcomp1)

    # Testing to catch adding component twice
    @test_throws ErrorException add_comp!(my_model, testcomp1)

    # Testing to catch if before or after does not exist
    @test_throws ErrorException add_comp!(my_model, testcomp2, before=:testcomp3)

    @test_throws ErrorException add_comp!(my_model, testcomp2, after=:testcomp3)
end
