using Mimi

@defcomp grosseconomy begin
    YGROSS  = Variable(index=[time])    # Gross output
    K       = Variable(index=[time])    # Capital
    l       = Parameter(index=[time])   # Labor
    tfp     = Parameter(index=[time])   # Total factor productivity
    s       = Parameter(index=[time])   # Savings rate
    depk    = Parameter()               # Depreciation rate on capital - Note that it has no time index
    k0      = Parameter()               # Initial level of capital
    share   = Parameter()               # Capital share

    function run_timestep(p, v, d, t)
        # Define an equation for K
        if is_first(t)
            v.K[t]  = p.k0  # Note the use of v. and p. to distinguish between variables and parameters
        else
            v.K[t]  = (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
        end

        # Define an equation for YGROSS
        v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
    end
end

@defcomp emissions begin
    E       = Variable(index=[time])    # Total greenhouse gas emissions
    sigma   = Parameter(index=[time])   # Emissions output ratio
    YGROSS  = Parameter(index=[time])   # Gross output - Note that YGROSS is now a parameter

    function run_timestep(p, v, d, t)
        # Define an eqation for E
        v.E[t] = p.YGROSS[t] * p.sigma[t]   # Note the p. in front of YGROSS
    end
end

function construct_model()
	m = Model()

	set_dimension!(m, :time, collect(2015:5:2110))

	# Order matters here. If the emissions component were defined first, the model would not run.
	add_comp!(m, grosseconomy)  
	add_comp!(m, emissions)

	# Update parameters for the grosseconomy component
	update_param!(m, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
	update_param!(m, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
	update_param!(m, :grosseconomy, :s, ones(20).* 0.22)
	update_param!(m, :grosseconomy, :depk, 0.1)
	update_param!(m, :grosseconomy, :k0, 130.)
	update_param!(m, :grosseconomy, :share, 0.3)

	# Update and connect parameters for the emissions component
	update_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
	connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)  

	return m

end #end function

model = construct_model()

run(model)

# Show model results
model[:emissions, :E]

# Or, as a DataFrame
getdataframe(model, :emissions, :E)
