using Mimi
using NamedArrays
using Base.Test

@defcomp compA begin
    regions = Index()

    y = Variable(index=[time, regions])
    x = Parameter(index=[time, regions])

end

function run_timestep(state::compA, t::Int)
    v = state.Variables
    p = state.Parameters
    d = state.Dimensions

    for r in d.regions
        v.y[t, r] = p.x[t, r]
    end
end

x = Array(Float64,20,3)
for t in 1:20
    x[t,1] = 1
    x[t,2] = 2
    x[t,3] = 3
end

region_labels = ["Region1", "Region2", "Region3"]
time_labels = collect(2015:5:2110)
x2 = NamedArray(Array(Float64,20,3), (time_labels, region_labels), (:time, :regions))
for t in 1:20
    x[t,1] = 1
    x[t,2] = 2
    x[t,3] = 3
end

model1 = Model()
setindex(model1, :time, collect(2015:5:2110))
setindex(model1, :regions, ["Region1", "Region2", "Region3"])
addcomponent(model1, compA)
setparameter(model1, :compA, :x, x)

model2 = Model()
setindex(model2, :time, collect(2015:5:2110))
setindex(model2, :regions, ["Region1", "Region2", "Region3"])
addcomponent(model2, compA)
setparameter(model2, :compA, :x, x2)

run(model1)
run(model2)

for t in range(1, length(time_labels))
    for r in range(1, length(region_labels))
        @test(model1[:compA, :y][t, r] == model2[:compA, :y][t, r])
        #println(model1[:compA, :y][t, r], model2[:compA, :y][t, r])
    end
end


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
end


function run_timestep(state::grosseconomy, t::Int)
    v = state.Variables
    p = state.Parameters
    d = state.Dimensions                        #Note that the regional dimension is defined here and parameters and variables are indexed by 'r'

    #Define an equation for K
    for r in d.regions
        if t == 1
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

#EMISSIONS COMPONENT
@defcomp emissions begin
    regions     = Index()                           #The regions index must be specified for each component

    E           = Variable(index=[time, regions])   #Total greenhouse gas emissions
    E_Global    = Variable(index=[time])            #Global emissions (sum of regional emissions)
    sigma       = Parameter(index=[time, regions])  #Emissions output ratio
    YGROSS      = Parameter(index=[time, regions])  #Gross output - Note that YGROSS is now a parameter
end


function run_timestep(state::emissions, t::Int)
    v = state.Variables
    p = state.Parameters
    d = state.Dimensions

    #Define an eqation for E
    for r in d.regions
        v.E[t,r] = p.YGROSS[t,r] * p.sigma[t,r]
    end

    #Define an equation for E_Global
    for r in d.regions
        v.E_Global[t] = sum(v.E[t,:])
    end
end

#DEFINE ALL THE PARAMETERS
l = Array(Float64,20,3)
for t in 1:20
    l[t,1] = (1. + 0.015)^t *2000
    l[t,2] = (1. + 0.02)^t * 1250
    l[t,3] = (1. + 0.03)^t * 1700
end

tfp = Array(Float64,20,3)
for t in 1:20
    tfp[t,1] = (1 + 0.06)^t * 3.2
    tfp[t,2] = (1 + 0.03)^t * 1.8
    tfp[t,3] = (1 + 0.05)^t * 2.5
end

s = Array(Float64,20,3)
for t in 1:20
    s[t,1] = 0.21
    s[t,2] = 0.15
    s[t,3] = 0.28
end

depk = [0.11, 0.135 ,0.15]
k0   = [50.5, 22., 33.5]

sigma = Array(Float64,20,3)
for t in 1:20
    sigma[t,1] = (1. - 0.05)^t * 0.58
    sigma[t,2] = (1. - 0.04)^t * 0.5
    sigma[t,3] = (1. - 0.045)^t * 0.6
end

#FUNCTION TO RUN MY MODEL
function run_my_model()

    my_model = Model()

    setindex(my_model, :time, collect(2015:5:2110))
    setindex(my_model, :regions, ["Region1", "Region2", "Region3"])  #Note that the regions of your model must be specified here

    addcomponent(my_model, grosseconomy)
    addcomponent(my_model, emissions)

    setparameter(my_model, :grosseconomy, :l, l)
    setparameter(my_model, :grosseconomy, :tfp, tfp)
    setparameter(my_model, :grosseconomy, :s, s)
    setparameter(my_model, :grosseconomy, :depk,depk)
    setparameter(my_model, :grosseconomy, :k0, k0)
    setparameter(my_model, :grosseconomy, :share, 0.3)

    #set parameters for emissions component
    setparameter(my_model, :emissions, :sigma, sigma2)
    connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    run(my_model)
    return(my_model)

end


#DEFINE ALL THE PARAMETERS using NAMEDARRAYS
region_labels = ["Region1", "Region2", "Region3"]
time_labels = collect(2015:5:2110)

l2 = NamedArray(Array(Float64,20,3), (time_labels, region_labels), (:time, :regions))
for t in time_labels
    l2[t,1] = (1. + 0.015)^t *2000
    l2[t,2] = (1. + 0.02)^t * 1250
    l2[t,3] = (1. + 0.03)^t * 1700
end

tfp2 = NamedArray(Array(Float64,20,3), (time_labels, region_labels), (:time, :regions))
for t in time_labels
    tfp2[t,1] = (1 + 0.06)^t * 3.2
    tfp2[t,2] = (1 + 0.03)^t * 1.8
    tfp2[t,3] = (1 + 0.05)^t * 2.5
end

s2 = NamedArray(Array(Float64,20,3), (time_labels, region_labels), (:time, :regions))
for t in time_labels
    s2[t,1] = 0.21
    s2[t,2] = 0.15
    s2[t,3] = 0.28
end

depk2 = NamedArray([0.11, 0.135 ,0.15], (region_labels,), (:regions,))
k02   = NamedArray([50.5, 22., 33.5], (region_labels,), (:regions,))

sigma2 = NamedArray(Array(Float64,20,3), (time_labels, region_labels), (:time, :regions))
for t in time_labels
    sigma2[t,1] = (1. - 0.05)^t * 0.58
    sigma2[t,2] = (1. - 0.04)^t * 0.5
    sigma2[t,3] = (1. - 0.045)^t * 0.6
end


function run_my_model2()

    my_model2 = Model()

    setindex(my_model2, :time, collect(2015:5:2110))
    setindex(my_model2, :regions, ["Region1", "Region2", "Region3"])  #Note that the regions of your model must be specified here

    addcomponent(my_model2, grosseconomy)
    addcomponent(my_model2, emissions)

    setparameter(my_model2, :grosseconomy, :l, l2)
    setparameter(my_model2, :grosseconomy, :tfp, tfp2)
    setparameter(my_model2, :grosseconomy, :s, s2)
    setparameter(my_model2, :grosseconomy, :depk,depk2)
    setparameter(my_model2, :grosseconomy, :k0, k02)
    setparameter(my_model2, :grosseconomy, :share, 0.3)

    #set parameters for emissions component
    setparameter(my_model2, :emissions, :sigma, sigma)
    connectparameter(my_model2, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    run(my_model2)
    return(my_model2)

end

run1 = run_my_model()
run2 = run_my_model2()

#Check results

for t in range(1, length(time_labels))
    for r in range(1, length(region_labels))
        @test(run1[:grosseconomy, :YGROSS][t, r] == run2[:grosseconomy, :YGROSS][t, r])
        @test(run1[:grosseconomy, :K][t, r] == run2[:grosseconomy, :K][t, r])
        @test(run1[:emissions, :E][t, r] == run2[:emissions, :E][t, r])
        @test(run1[:emissions, :E_Global][t, r] == run2[:emissions, :E_Global][t, r])
    end
end
