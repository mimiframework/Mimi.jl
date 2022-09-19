@testitem "Mult_GetDataframe" begin
    using NamedArrays

    #####################################
    #  LARGER MULTIREGIONAL TEST (2/3)  #
    #####################################

    #GROSS ECONOMY COMPONENT
    @defcomp grosseconomy begin
        regions = Index()                           #Note that a regional index is defined here

        YGROSS  = Variable(index=[time, regions])   #Gross output
        K       = Variable(index=[time, regions])   #Capital
        l       = Parameter(index=[time, regions])  #Labor
        tfp     = Parameter(index=[time, regions])  #Total factor productivity
        s       = Parameter(index=[time, regions])  #Savings rate
        depk    = Parameter(index=[regions])        #Depreciation rate on capital - Note that it only has a region index
        k0      = Parameter(index=[regions])        #Initial level of capital
        share   = Parameter()                       #Capital share
        
        function run_timestep(p, v, d, t)
            #Define an equation for K
            for r in d.regions
                if is_first(t)
                    v.K[t,r] = p.k0[r]
                else
                    v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5
                end
            end
            
            #Define an equation for YGROSS
            for r in d.regions
                v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)
            end
        end
    end

    #EMISSIONS COMPONENT
    @defcomp emissions begin
        regions     = Index()                           #The regions index must be specified for each component

        E           = Variable(index=[time, regions])   #Total greenhouse gas emissions
        E_Global    = Variable(index=[time])            #Global emissions (sum of regional emissions)
        sigma       = Parameter(index=[time, regions])  #Emissions output ratio
        YGROSS      = Parameter(index=[time, regions])  #Gross output - Note that YGROSS is now a parameter
        
        function run_timestep(p, v, d, t)
            #Define an eqation for E
            for r in d.regions
                v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]
            end
            
            #Define an equation for E_Global
            for r in d.regions
                v.E_Global[t] = sum(v.E[t,:])
            end
        end
    end

    #DEFINE ALL THE PARAMETERS
    l = Array{Float64}(undef,20,3)
    for t in 1:20
        l[t,1] = (1. + 0.015)^t *2000
        l[t,2] = (1. + 0.02)^t * 1250
        l[t,3] = (1. + 0.03)^t * 1700
    end

    tfp = Array{Float64}(undef, 20,3)
    for t in 1:20
        tfp[t,1] = (1 + 0.06)^t * 3.2
        tfp[t,2] = (1 + 0.03)^t * 1.8
        tfp[t,3] = (1 + 0.05)^t * 2.5
    end

    s = Array{Float64}(undef, 20,3)
    for t in 1:20
        s[t,1] = 0.21
        s[t,2] = 0.15
        s[t,3] = 0.28
    end

    depk = [0.11, 0.135 ,0.15]
    k0   = [50.5, 22., 33.5]

    sigma = Array{Float64}(undef, 20,3)
    for t in 1:20
        sigma[t,1] = (1. - 0.05)^t * 0.58
        sigma[t,2] = (1. - 0.04)^t * 0.5
        sigma[t,3] = (1. - 0.045)^t * 0.6
    end

    #FUNCTION TO RUN MY MODEL
    function run_my_model()

        my_model = Model()

        set_dimension!(my_model, :time, collect(2015:5:2110))
        set_dimension!(my_model, :regions, ["Region1", "Region2", "Region3"])  #Note that the regions of your model must be specified here

        add_comp!(my_model, grosseconomy)
        add_comp!(my_model, emissions)

        update_param!(my_model, :grosseconomy, :l, l)
        update_param!(my_model, :grosseconomy, :tfp, tfp)
        update_param!(my_model, :grosseconomy, :s, s)
        update_param!(my_model, :grosseconomy, :depk,depk)
        update_param!(my_model, :grosseconomy, :k0, k0)
        update_param!(my_model, :grosseconomy, :share, 0.3)

        #set parameters for emissions component
        update_param!(my_model, :emissions, :sigma, sigma2)
        connect_param!(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)

        run(my_model)
        return(my_model)
    end


    # DEFINE ALL THE PARAMETERS using NAMEDARRAYS
    region_labels = ["Region1", "Region2", "Region3"]
    time_labels = collect(2015:5:2110)
    num_time_labels = length(time_labels)

    l2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
    for t in 1:num_time_labels
        l2[t, 1] = (1. + 0.015)^t *2000
        l2[t, 2] = (1. + 0.02)^t * 1250
        l2[t, 3] = (1. + 0.03)^t * 1700
    end

    tfp2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
    for t in 1:num_time_labels
        tfp2[t, 1] = (1 + 0.06)^t * 3.2
        tfp2[t, 2] = (1 + 0.03)^t * 1.8
        tfp2[t, 3] = (1 + 0.05)^t * 2.5
    end

    s2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
    for t in 1:num_time_labels
        s2[t, 1] = 0.21
        s2[t, 2] = 0.15
        s2[t, 3] = 0.28
    end

    depk2 = NamedArray([0.11, 0.135 ,0.15], (region_labels,), (:regions,))
    k02   = NamedArray([50.5, 22., 33.5], (region_labels,), (:regions,))

    sigma2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
    for t in 1:num_time_labels
        sigma2[t, 1] = (1. - 0.05)^t * 0.58
        sigma2[t, 2] = (1. - 0.04)^t * 0.5
        sigma2[t, 3] = (1. - 0.045)^t * 0.6
    end

    run1 = run_my_model()

    expanded_get_dataframe = getdataframe(run1, :grosseconomy =>(:YGROSS, :K))
    curr_get_dataframe = getdataframe(run1, :grosseconomy, :YGROSS)
    @test(expanded_get_dataframe[!, 3] == curr_get_dataframe[!, 3])

    expanded_get_dataframe = getdataframe(run1, :grosseconomy => :YGROSS, :emissions => :E)
    curr_get_dataframe = getdataframe(run1, :emissions, :E)
    @test(expanded_get_dataframe[!, 4] == curr_get_dataframe[!, 3])


    #################
    ## MORE TESTS ###
    #################
    my_model = Model()
    set_dimension!(my_model, :time, collect(2015:5:2110))

    #Testing that you cannot add two components of the same name
    @defcomp testcomp1 begin
        var1 = Variable(index=[time])
        par1 = Parameter(index=[time])
        
        function run_timestep(p, v, d, t)
            v.var1[t] = p.par1[t]
        end
    end


    par = collect(2015:5:2110)
    add_comp!(my_model, testcomp1)

    update_param!(my_model, :testcomp1, :par1, par)
    run(my_model)

    #Regular getdataframe
    dataframe = getdataframe(my_model, :testcomp1 => :var1)
    @test(dataframe[!, 2] == par)

    #Test trying to getdataframe from component that does not exist
    @test_throws ErrorException getdataframe(my_model, :testcomp1 => :var2)

end
