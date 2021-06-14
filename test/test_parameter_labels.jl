module TestParameterLabels

using Mimi
using NamedArrays
using Test

############################################
#    BASIC TEST - use NamedArrays (1/3)    #
############################################

@defcomp compA begin
    regions = Index()

    y = Variable(index=[time, regions])
    x = Parameter(index=[time, regions])

    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.y[t, r] = p.x[t, r]
        end
    end
end
    
x = Array{Float64}(undef, 20, 3)
for t in 1:20
    x[t,1] = 1
    x[t,2] = 2
    x[t,3] = 3
end

region_labels = ["Region1", "Region2", "Region3"]
time_labels = collect(2015:5:2110)

x2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
for t in time_labels
    x2[:time => t, :regions => "Region1"] = 1
    x2[:time => t, :regions => "Region2"] = 2
    x2[:time => t, :regions => "Region3"] = 3
end

model1 = Model()
set_dimension!(model1, :time, time_labels)
set_dimension!(model1, :regions, region_labels)
add_comp!(model1, compA)
update_param!(model1, :compA, :x, x)

model2 = Model()
set_dimension!(model2, :time, time_labels)
set_dimension!(model2, :regions, region_labels)
add_comp!(model2, compA)
update_param!(model2, :compA, :x, x2) # should perform parameter dimension check

run(model1)
run(model2)

for t in 1:length(time_labels)
    for r in 1:length(region_labels)
        @test(model1[:compA, :y][t, r] == model2[:compA, :y][t, r])
    end
end

@test(size(getdataframe(model1, :compA, :y)) == (60, 3))

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
l = Array{Float64}(undef, 20, 3)
for t in 1:20
    l[t,1] = (1. + 0.015)^t *2000
    l[t,2] = (1. + 0.02)^t * 1250
    l[t,3] = (1. + 0.03)^t * 1700
end

tfp = Array{Float64}(undef, 20, 3)
for t in 1:20
    tfp[t,1] = (1 + 0.06)^t * 3.2
    tfp[t,2] = (1 + 0.03)^t * 1.8
    tfp[t,3] = (1 + 0.05)^t * 2.5
end

s = Array{Float64}(undef, 20, 3)
for t in 1:20
    s[t,1] = 0.21
    s[t,2] = 0.15
    s[t,3] = 0.28
end

depk = [0.11, 0.135 ,0.15]
k0   = [50.5, 22., 33.5]

sigma = Array{Float64}(undef, 20, 3)
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
    update_param!(my_model, :grosseconomy, :depk, depk)
    update_param!(my_model, :grosseconomy, :k0, k0)
    update_param!(my_model, :grosseconomy, :share, 0.3)

    #set parameters for emissions component
    update_param!(my_model, :emissions, :sigma, sigma2)
    connect_param!(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    run(my_model)
    return(my_model)

end


#DEFINE ALL THE PARAMETERS using NAMEDARRAYS
region_labels = ["Region1", "Region2", "Region3"]
time_labels = collect(2015:5:2110)

l2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
for t in 1:length(time_labels)
    l2[:time => time_labels[t], :regions => region_labels[1]] = (1. + 0.015)^t *2000
    l2[:time => time_labels[t], :regions => region_labels[2]] = (1. + 0.02)^t * 1250
    l2[:time => time_labels[t], :regions => region_labels[3]] = (1. + 0.03)^t * 1700
end

tfp2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
for t in 1:length(time_labels)
    tfp2[:time => time_labels[t], :regions => region_labels[1]] = (1 + 0.06)^t * 3.2
    tfp2[:time => time_labels[t], :regions => region_labels[2]] = (1 + 0.03)^t * 1.8
    tfp2[:time => time_labels[t], :regions => region_labels[3]] = (1 + 0.05)^t * 2.5
end

s2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
for t in 1:length(time_labels)
    s2[t, 1] = 0.21
    s2[t, 2] = 0.15
    s2[t, 3] = 0.28
end

depk2 = NamedArray([0.11, 0.135 ,0.15], (region_labels,), (:regions,))
k02   = NamedArray([50.5, 22., 33.5], (region_labels,), (:regions,))

sigma2 = NamedArray(Array{Float64}(undef, 20, 3), (time_labels, region_labels), (:time, :regions))
for t in 1:length(time_labels)
    sigma2[t, 1] = (1. - 0.05)^t * 0.58
    sigma2[t, 2] = (1. - 0.04)^t * 0.5
    sigma2[t, 3] = (1. - 0.045)^t * 0.6
end


function run_my_model2()

    my_model2 = Model()

    set_dimension!(my_model2, :time, collect(2015:5:2110))
    set_dimension!(my_model2, :regions, ["Region1", "Region2", "Region3"])  #Note that the regions of your model must be specified here

    add_comp!(my_model2, grosseconomy)
    add_comp!(my_model2, emissions)

    update_param!(my_model2, :grosseconomy, :l, l2)
    update_param!(my_model2, :grosseconomy, :tfp, tfp2)
    update_param!(my_model2, :grosseconomy, :s, s2)
    update_param!(my_model2, :grosseconomy, :depk,depk2)
    update_param!(my_model2, :grosseconomy, :k0, k02)
    update_param!(my_model2, :grosseconomy, :share, 0.3)

    #set parameters for emissions component
    update_param!(my_model2, :emissions, :sigma, sigma2)
    connect_param!(my_model2, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    run(my_model2)
    return(my_model2)

end

run1 = run_my_model()
run2 = run_my_model2()

#Check results

for t in 1:length(time_labels)
    for r in 1:length(region_labels)
        @test(run1[:grosseconomy, :YGROSS][t, r] == run2[:grosseconomy, :YGROSS][t, r])
        #println(run1[:grosseconomy, :YGROSS][t, r],", ", run2[:grosseconomy, :YGROSS][t, r])
        @test(run1[:grosseconomy, :K][t, r] == run2[:grosseconomy, :K][t, r])
        @test(run1[:emissions, :E][t, r] == run2[:emissions, :E][t, r])
    end
    @test(run1[:emissions, :E_Global][t] == run2[:emissions, :E_Global][t])
end



######################################################
#  set_param! option with list of dimension names  #
######################################################

model3 = Model()
set_dimension!(model3, :time, collect(2015:5:2110))
set_dimension!(model3, :regions, ["Region1", "Region2", "Region3"])
add_comp!(model3, compA)
set_param!(model3, :compA, :x, x, dims = [:time, :regions])
run(model3)

for t in 1:length(time_labels)
    for r in 1:length(region_labels)
        @test(model1[:compA, :y][t, r] == model3[:compA, :y][t, r])
    end
end


######################################################
#  update_param! option with list of dimension names  #
######################################################

model3 = Model()
set_dimension!(model3, :time, collect(2015:5:2110))
set_dimension!(model3, :regions, ["Region1", "Region2", "Region3"])
add_comp!(model3, compA)
add_shared_param!(model3, :x, x, dims = [:time, :regions])
connect_param!(model3, :compA, :x, :x)
run(model3)

for t in 1:length(time_labels)
    for r in 1:length(region_labels)
        @test(model1[:compA, :y][t, r] == model3[:compA, :y][t, r])
    end
end

end #module
