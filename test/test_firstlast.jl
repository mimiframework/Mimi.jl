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

@defcomp emissions begin
	E 	    = Variable(index=[time])	# Total greenhouse gas emissions
	sigma	= Parameter(index=[time])	# Emissions output ratio
	YGROSS	= Parameter(index=[time])	# Gross output - Note that YGROSS is now a parameter

	function run_timestep(p, v, d, t)
		v.E[t] = p.YGROSS[t] * p.sigma[t]	# Note the p. in front of YGROSS
	end
end

#
# Test using first and last for one (the second) component
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
add_comp!(m, grosseconomy)  
add_comp!(m, emissions, first = 2020, last = 2105)

# check that the attributes of the ModelDef and ComponentDef(s) have been set_dimension
# as expected
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
@test_throws ErrorException set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:19]) # the parameter needs to be length of model
set_param!(m, :emissions, :sigma, [(1. - 0.05)^t *0.58 for t in 1:20])
connect_param!(m, :emissions, :YGROSS, :grosseconomy, :YGROSS)  

run(m)

# test that there are missing values in :emissions variables outside of the component's 
# run period, and no missing values in the :grosseconomy variables
@test ismissing(m[:emissions, :E][1])
@test ismissing(m[:emissions, :E][20])
@test sum(ismissing.(m[:emissions, :E][2:19])) == 0
@test sum(ismissing.(m[:grosseconomy, :l])) == 0

# change the model dimension (widen it)
set_dimension!(m, :time, collect(2015:5:2115))

# check that the first, last, and time have been updated properly for both the 
# ModelDef and ComponentDef(s)
@test collect(2015:5:2115) == time_labels(m.md) == [keys(m.md.namespace[:emissions].dim_dict[:time])...] == [keys(m.md.namespace[:grosseconomy].dim_dict[:time])...]
@test m.md.first == m.md.namespace[:grosseconomy].first # grosseconomy first and last vary with model limits
@test m.md.last == m.md.namespace[:grosseconomy].last # grosseconomy first and last vary with model limits
@test m.md.namespace[:emissions].first == 2020 # emissions first and last are fixed
@test m.md.namespace[:emissions].last == 2105 # emissions first and last are fixed

# reset any parameters that have a time dimension
update_param!(m, :l, [(1. + 0.015)^t *6404 for t in 1:21])
update_param!(m,  :tfp, [(1 + 0.065)^t * 3.57 for t in 1:21])
update_param!(m, :s, ones(21).* 0.22)
update_param!(m, :sigma, [(1. - 0.05)^t *0.58 for t in 1:21])

run(m)

# test that there are missing values in :emissions variables outside of the component's 
# run period, and no missing values in the :grosseconomy variables
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

run(m) 

# neither component should have a value for the first timestep
@test ismissing(m[:emissions, :E][1])
@test ismissing(m[:grosseconomy, :YGROSS][1])


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

#
# Test bounds - components starting or ending before/after the model
#

m = Model()
set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps

# components cannot start before or end after the model's time dimension
@test_throws ErrorException add_comp!(m, grosseconomy, first = 2000)
add_comp!(m, grosseconomy)
@test_throws ErrorException add_comp!(m, emissions, last = 2120)

#
# Test is_first and is_last
#

# is_first and is_last should be equivalent to comparing the timestep to the first
# and last years provided, and t.t should be 1 when the year is first i.e. the 
# first year the component actually runs for.

@defcomp MyComp begin
	a 	= Variable(index=[time])	
	function run_timestep(p, v, d, t)
		if t == TimestepValue(2) v.a[t] = -999
		elseif t == TimestepValue(9) v.a[t] = 999
		else v.a[t] = t.t
		end
	end
end

@defcomp MyComp2 begin
	a 	= Variable(index=[time])	
	function run_timestep(p, v, d, t)
		if is_first(t) v.a[t] = -999
		elseif is_last(t) v.a[t] = 999
		else v.a[t] = t.t
		end
	end
end

m = Model()
set_dimension!(m, :time, collect(1:10))
add_comp!(m, MyComp, first = 2, last = 9)
run(m)

m2 = Model()
set_dimension!(m2, :time, collect(1:10))
add_comp!(m2, MyComp, first = 2, last = 9)
run(m2)

@test ismissing(m[:MyComp, :a][1])
@test ismissing(m[:MyComp, :a][end])
@test (m[:MyComp, :a])[2:9] == (m2[:MyComp, :a])[2:9] == [-999., 2., 3., 4., 5., 6., 7., 999.]

end #module