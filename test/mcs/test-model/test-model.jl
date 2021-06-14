module TestModel

using Mimi

include("region_parameters.jl")
include("gross_economy.jl")
include("emissions.jl")

export create_model

function create_model()

	m = Model()

	set_dimension!(m, :time, collect(2015:5:2110))
	set_dimension!(m, :regions, [:Region1, :Region2, :Region3])

	add_comp!(m, grosseconomy)
	add_comp!(m, emissions)

	# set parameters for grosseconomy component
	update_param!(m, :grosseconomy, :l, l)
	update_param!(m, :grosseconomy, :tfp, tfp)
	update_param!(m, :grosseconomy, :s, s)
	update_param!(m, :grosseconomy, :depk,depk)
	update_param!(m, :grosseconomy, :k0, k0)
	update_param!(m, :grosseconomy, :share, 0.3)
	update_param!(m, :grosseconomy, :tester, zeros(Mimi.dim_count(m.md, :time), 
												Mimi.dim_count(m.md, :regions)))

	# set and connect parameters for emissions component
	update_param!(m, :emissions, :sigma, sigma)
	connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)

    return m
end

end # module
