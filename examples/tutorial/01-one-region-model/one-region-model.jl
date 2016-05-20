using Mimi

@defcomp grosseconomy begin
    YGROSS  = Variable(index=[time])    #Gross output
    K       = Variable(index=[time])    #Capital
    l       = Parameter(index=[time])   #Labor
    tfp     = Parameter(index=[time])   #Total factor productivity
    s       = Parameter(index=[time])   #Savings rate
    depk    = Parameter()               #Depreciation rate on capital - Note that it has no time index
    k0      = Parameter()               #Initial level of capital
    share   = Parameter()               #Capital share
end

function timestep(state::grosseconomy, t::Int)
    v = state.Variables
    p = state.Parameters

    #Define an equation for K
    if t == 1
        v.K[t]  = p.k0  #Note the use of v. and p. to distinguish between variables and parameters
    else
        v.K[t]  = (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
    end

    #Define an equation for YGROSS
    v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
end

@defcomp emissions begin
    E       = Variable(index=[time])    #Total greenhouse gas emissions
    sigma   = Parameter(index=[time])   #Emissions output ratio
    YGROSS  = Parameter(index=[time])   #Gross output - Note that YGROSS is now a parameter
end

function timestep(state::emissions, t::Int)
    v = state.Variables
    p = state.Parameters

    #Define an eqation for E
    v.E[t] = p.YGROSS[t] * p.sigma[t]   #Note the p. in front of YGROSS
end

my_model = Model()

setindex(my_model, :time, [2015:5:2110])

addcomponent(my_model, grosseconomy)  #Order matters here. If the emissions component were defined first, the model would not run.
addcomponent(my_model, emissions)

#Set parameters for the grosseconomy component
setparameter(my_model, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
setparameter(my_model, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
setparameter(my_model, :grosseconomy, :s, ones(20).* 0.22)
setparameter(my_model, :grosseconomy, :depk, 0.1)
setparameter(my_model, :grosseconomy, :k0, 130.)
setparameter(my_model, :grosseconomy, :share, 0.3)

#Set parameters for the emissions component
setparameter(my_model, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)  #Note that connectparameter was used here.

run(my_model)

#Check model results
my_model[:emissions, :E]
