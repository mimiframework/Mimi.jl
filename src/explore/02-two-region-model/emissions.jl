using Mimi                                          #Make sure to call Mimi again

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
