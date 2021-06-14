module MyModel

using Mimi

include("region_parameters.jl")
include("gross_economy.jl")
include("emissions.jl")

export construct_MyModel

function construct_MyModel()

	m = Model()

	set_dimension!(m, :time, 2015:5:2110)
	# Note that the regions of your model must be specified here
	set_dimension!(m, :regions, [:Region1, :Region2, :Region3])

	add_comp!(m, grosseconomy)
	add_comp!(m, emissions)

	# update parameters for grosseconomy component
	update_param!(m, :grosseconomy, :l, l)
	update_param!(m, :grosseconomy, :tfp, tfp)
	update_param!(m, :grosseconomy, :s, s)
	update_param!(m, :grosseconomy, :depk, depk)
	update_param!(m, :grosseconomy, :k0, k0)
	update_param!(m, :grosseconomy, :share, 0.3)

	# update and connect parameters for emissions component
	update_param!(m, :emissions, :sigma, sigma)
	connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    return m
    
end

end #module
