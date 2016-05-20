include("gross_economy.jl")
include("emissions.jl")

function run_my_model()

    my_model = Model()

    setindex(my_model, :time, [2015:5:2110])
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
    setparameter(my_model, :emissions, :sigma, sigma)
    connectparameter(my_model, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    run(my_model)
    return(my_model)

end
