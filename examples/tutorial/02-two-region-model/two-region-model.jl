module tworegion

using Mimi

include("region_parameters.jl")
include("gross_economy.jl")
include("emissions.jl")

export my_model

@defmodel my_model begin

    index[time] = 2015:5:2110
    
    # Note that the regions of your model must be specified here
    index[regions] = ["Region1", "Region2", "Region3"]  

    # Order matters here. If the emissions component were defined first, the model would not run.
    component(grosseconomy)
    component(emissions)

    # Set parameters for the grosseconomy component
    grosseconomy.l     = l
    grosseconomy.tfp   = tfp
    grosseconomy.s     = s
    grosseconomy.depk  = depk
    grosseconomy.k0    = k0
    grosseconomy.share = 0.3

    # Set parameters for the emissions component
    emissions.sigma = sigma

    # Connect parameters
    grosseconomy.YGROSS => emissions.YGROSS
end

end # module
