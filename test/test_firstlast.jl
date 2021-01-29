module TestFirstLast

using Mimi 
using Test

import Mimi: time_labels

#
# Define some Components
#

@defcomp grosseconomy begin
	YGROSS	= Variable(index=[time])	# Gross output
	K	    = Variable(index=[time])	# Capital
	l	    = Parameter(index=[time])	# Labor
	tfp	    = Parameter(index=[time])	# Total factor productivity
	s	    = Parameter(index=[time])	# Savings rate
	depk	= Parameter()			    # Depreciation rate on capital - Note that it has no time index
	k0	    = Parameter()			    # Initial level of capital
	share	= Parameter()			    # Capital share

	function run_timestep(p, v, d, t)
		if is_first(t)
			v.K[t] 	= p.k0	
		else
			v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
		end
		v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
	end
end

@defcomp grosseconomy2 begin
	YGROSS	= Variable(index=[time])	# Gross output
	K	    = Variable(index=[time])	# Capital
	l	    = Parameter(index=[time])	# Labor
	tfp	    = Parameter(index=[time])	# Total factor productivity
	s	    = Parameter(index=[time])	# Savings rate
	depk	= Parameter()			    # Depreciation rate on capital - Note that it has no time index
	k0	    = Parameter()			    # Initial level of capital
	share	= Parameter()			    # Capital share

	function run_timestep(p, v, d, t)
		if t == TimestepValue(2020)
			v.K[t] 	= p.k0	
		else
			v.K[t] 	= (1 - p.depk)^5 * v.K[t-1] + v.YGROSS[t-1] * p.s[t-1] * 5
		end
		v.YGROSS[t] = p.tfp[t] * v.K[t]^p.share * p.l[t]^(1-p.share)
	end
end

@defcomp emissions begin
	E 	    = Variable(index=[time])	# Total greenhouse gas emissions
	sigma	= Parameter(index=[time])	# Emissions output ratio
	YGROSS	= Parameter(index=[time])	# Gross output - Note that YGROSS is now a parameter

	function run_timestep(p, v, d, t)
		v.E[t] = p.YGROSS[t] * p.sigma[t]	# Note the p. in front of YGROSS
	end
end

#
# Test first and last for one component
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
add_comp!(m, grosseconomy)  
add_comp!(m, emissions, first = 2020, last = 2105)

# check the attributes
@test collect(2015:5:2110) == time_labels(m.md) == [keys(m.md.namespace[:emissions].dim_dict[:time])...] == [keys(m.md.namespace[:grosseconomy].dim_dict[:time])...]
@test m.md.first == m.md.namespace[:grosseconomy].first 
@test m.md.last == m.md.namespace[:grosseconomy].last
@test m.md.namespace[:emissions].first == 2020
@test m.md.namespace[:emissions].last == 2105

# Set parameters for the grosseconomy component
set_param!(m, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
set_param!(m, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
set_param!(m, :grosseconomy, :s, ones(20).* 0.22)
set_param!(m, :grosseconomy, :depk, 0.1)
set_param!(m, :grosseconomy, :k0, 130.)
set_param!(m, :grosseconomy, :share, 0.3)

# Set parameters for the emissions component
@test_throws ErrorException set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:19]) # needs to be length of model
set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)  

run(m)

# test that there are missing values in :emissions but not :grosseconomy
@test ismissing(m[:emissions, :E][1])
@test ismissing(m[:emissions, :E][20])
@test sum(ismissing.(m[:emissions, :E][2:19])) == 0
@test sum(ismissing.(m[:grosseconomy, :l])) == 0

# change the model dimension
set_dimension!(m, :time, collect(2015:5:2115))

# check that the first, last, and time have been updated properly
@test collect(2015:5:2115) == time_labels(m.md) == [keys(m.md.namespace[:emissions].dim_dict[:time])...] == [keys(m.md.namespace[:grosseconomy].dim_dict[:time])...]
@test m.md.first == m.md.namespace[:grosseconomy].first # grosseconomy first and last vary with model limits
@test m.md.last == m.md.namespace[:grosseconomy].last # grosseconomy first and last vary with model limits
@test m.md.namespace[:emissions].first == 2020 # emissions first and last are fixed
@test m.md.namespace[:emissions].last == 2105 # emissions first and last are fixed

# reset parameters with a time dimension
update_param!(m, :l, [(1. + 0.015)^t *6404 for t in 1:21])
update_param!(m,  :tfp, [(1 + 0.065)^t * 3.57 for t in 1:21])
update_param!(m, :s, ones(21).* 0.22)
update_param!(m, :sigma, [(1. - 0.05)^t *0.58 for t in 1:21])

run(m)

# test that there are missing values in :emissions but not :grosseconomy
@test ismissing(m[:emissions, :E][1])
@test sum(ismissing.(m[:emissions, :E][20:21])) == 2
@test sum(ismissing.(m[:emissions, :E][2:19])) == 0
@test sum(ismissing.(m[:grosseconomy, :l])) == 0

#
# Test bounds - both start late - with is_first()
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
add_comp!(m, grosseconomy, first = 2020)
add_comp!(m, emissions, first = 2020)

# Set parameters for the grosseconomy component
set_param!(m, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
set_param!(m, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
set_param!(m, :grosseconomy, :s, ones(20).* 0.22)
set_param!(m, :grosseconomy, :depk, 0.1)
set_param!(m, :grosseconomy, :k0, 130.)
set_param!(m, :grosseconomy, :share, 0.3)

# Set parameters for the emissions component
set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS) 

# this isn't going to run, because it doesnt set the initial value properly when it uses is_first()
@test_throws MissingException run(m) 

#
# Test bounds - both start late - without is_first()
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
add_comp!(m, grosseconomy2, first = 2020)
add_comp!(m, emissions, first = 2020)

# Set parameters for the grosseconomy component
set_param!(m, :grosseconomy2, :l, [(1. + 0.015)^t *6404 for t in 1:20])
set_param!(m, :grosseconomy2, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
set_param!(m, :grosseconomy2, :s, ones(20).* 0.22)
set_param!(m, :grosseconomy2, :depk, 0.1)
set_param!(m, :grosseconomy2, :k0, 130.)
set_param!(m, :grosseconomy2, :share, 0.3)

# Set parameters for the emissions component
set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connect_param!(m, :emissions, :YGROSS, :grosseconomy2, :YGROSS) 

# this will run!
run(m)
@test ismissing(m[:emissions, :E][20])
@test ismissing(m[:grosseconomy2, :YGROSS][20])


# Test bounds - both end early
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
add_comp!(m, grosseconomy, last = 2105)
add_comp!(m, emissions, last = 2105)

# Set parameters for the grosseconomy component
set_param!(m, :grosseconomy, :l, [(1. + 0.015)^t *6404 for t in 1:20])
set_param!(m, :grosseconomy, :tfp, [(1 + 0.065)^t * 3.57 for t in 1:20])
set_param!(m, :grosseconomy, :s, ones(20).* 0.22)
set_param!(m, :grosseconomy, :depk, 0.1)
set_param!(m, :grosseconomy, :k0, 130.)
set_param!(m, :grosseconomy, :share, 0.3)

# Set parameters for the emissions component
set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS) 

run(m) 

@test ismissing(m[:emissions, :E][20])
@test ismissing(m[:grosseconomy, :YGROSS][20])

end #module