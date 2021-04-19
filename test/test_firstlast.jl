module TestFirstLast

using Mimi 
using Test

import Mimi: time_labels, set_first_last!

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
@test m.md.namespace[:grosseconomy].first == 2015 # same as original model dim
@test m.md.namespace[:grosseconomy].last == 2110 # same as original model dim
@test m.md.namespace[:emissions].first == 2020 # explicitly set
@test m.md.namespace[:emissions].last == 2105 # explicitly set

# reset any parameters that have a time dimension
update_param!(m, :l, [(1. + 0.015)^t *6404 for t in 1:21])
update_param!(m,  :tfp, [(1 + 0.065)^t * 3.57 for t in 1:21])
update_param!(m, :s, ones(21).* 0.22)
update_param!(m, :sigma, [(1. - 0.05)^t *0.58 for t in 1:21])

run(m)

# test that there are missing values in :emissions variables outside of the component's 
# run period, and no missing values in the :grosseconomy variables
@test ismissing(m[:emissions, :E][1])
@test all(ismissing, m[:emissions, :E][20:21])
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

#
# TimestepIndex and TimestepValue
#

# TimestepIndex: Test Equality - should match up with t.t
@defcomp MyComp begin
	a 	= Variable(index=[time])
	b 	= Variable(index=[time])
	function run_timestep(p, v, d, t)
		v.a[t] = t == TimestepIndex(t.t)
		v.b[t] = 1.
	end
end

m = Model()
set_dimension!(m, :time, collect(1:15))
add_comp!(m, MyComp, first = 5, last = 10)
run(m)

for i in collect(1:15)
	@test m[:MyComp, :a][i] === m[:MyComp, :b][i]
end

# TimestepValue: Test Equality - should match up with the time index
@defcomp MyComp begin
	a 	= Variable(index=[time])
	b 	= Variable(index=[time])
	function run_timestep(p, v, d, t)
		v.a[t] = t == TimestepValue(t.t + 4)
		v.b[t] = 1.
	end
end

m = Model()
set_dimension!(m, :time, collect(1:15))
add_comp!(m, MyComp, first = 5, last = 10)
run(m)

for i in collect(1:15)
	@test m[:MyComp, :a][i] === m[:MyComp, :b][i]
end

# TimestepIndex: Test that Get and Set Index are Relative to Component, not Model
@defcomp MyComp begin
	a 	= Variable(index=[time])
	b 	= Variable(index=[time])
	function run_timestep(p, v, d, t)
		v.a[t] = t.t
		v.b[TimestepIndex(t.t)] = t.t
	end
end

m = Model()
set_dimension!(m, :time, collect(1:15))
add_comp!(m, MyComp, first = 5, last = 10)
run(m)
for (i, element) in enumerate(m[:MyComp, :a])
	@test element === m[:MyComp, :b][i]
end

@defcomp MyComp begin
	a 	= Variable(index=[time])
	function run_timestep(p, v, d, t)
		if t == TimestepIndex(1)
			v.a[TimestepIndex(1)] = 1
		else
			v.a[t] = 0
		end
	end
end

for year in collect(1995:1999)
	m = Model()
	set_dimension!(m, :time, collect(1995:2000))
	add_comp!(m, MyComp, first = year)
	run(m)
	idx = year - 1995 + 1
	@test m[:MyComp, :a][idx] == 1.0
end

# TimestepValue: Test that Get and Set Index are Relative to Component, not Model
@defcomp MyComp begin
	a 	= Variable(index=[time])
	function run_timestep(p, v, d, t)
		if t == TimestepValue(1999)
			v.a[TimestepValue(1999)] = 1
		else
			v.a[t] = 0
		end
	end
end

for year in collect(1995:1999)
	m = Model()
	set_dimension!(m, :time, collect(1995:2000))
	add_comp!(m, MyComp, first = year)
	run(m)
	@test m[:MyComp, :a][5] == 1.0
end

# test composite

@defcomp Comp1 begin
    par_1_1 = Parameter(index=[time])      # external input
    var_1_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_1_1[t] = p.par_1_1[t]
    end
end

@defcomp Comp2 begin
    par_2_1 = Parameter(index=[time])      # connected to Comp1.var_1_1
    par_2_2 = Parameter(index=[time])      # external input
    var_2_1 = Variable(index=[time])       # computed
    foo = Parameter()

    function run_timestep(p, v, d, t)
        v.var_2_1[t] = p.par_2_1[t] + p.foo * p.par_2_2[t]
    end
end

@defcomp Comp3 begin
    par_3_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_3_1 = Variable(index=[time])       # external output
    foo = Parameter(default=30)

    function run_timestep(p, v, d, t)
        # @info "Comp3 run_timestep"
        v.var_3_1[t] = p.par_3_1[t] * 2
    end
end

@defcomp Comp4 begin
    par_4_1 = Parameter(index=[time])      # connected to Comp2.var_2_1
    var_4_1 = Variable(index=[time])        # external output
    foo = Parameter(default=300)

    function run_timestep(p, v, d, t)
        # @info "Comp4 run_timestep"
        v.var_4_1[t] = p.par_4_1[t] * 2
    end
end

@defcomposite A begin
    Component(Comp1)
    Component(Comp2)

    foo1 = Parameter(Comp1.foo)
    foo2 = Parameter(Comp2.foo)

    var_2_1 = Variable(Comp2.var_2_1)

    connect(Comp2.par_2_1, Comp1.var_1_1)
    connect(Comp2.par_2_2, Comp1.var_1_1)
end

@defcomposite B begin
    Component(Comp3)
    Component(Comp4)

    foo3 = Parameter(Comp3.foo)
    foo4 = Parameter(Comp4.foo)

    var_3_1 = Variable(Comp3.var_3_1)
end

@defcomposite top begin
    Component(A)

    fooA1 = Parameter(A.foo1)
    fooA2 = Parameter(A.foo2)

    Component(B, first = 2010, last = 2015)
    foo3 = Parameter(B.foo3)
    foo4 = Parameter(B.foo4)

    var_3_1 = Variable(B.var_3_1)

    connect(B.par_3_1, A.var_2_1)
    connect(B.par_4_1, B.var_3_1)
end

# We have created the following composite structure:
#
#          top
#        /    \
#       A       B
#     /  \     /  \
#    1    2   3    4

m = Model()
set_dimension!(m, :time, 2005:2020)
add_comp!(m, top, nameof(top))

set_param!(m, :fooA1, 1)
set_param!(m, :fooA2, 2)
set_param!(m, :foo3, 10)
set_param!(m, :foo4, 20)
set_param!(m, :par_1_1, collect(1:length(time_labels(m))))

run(m)

# check that first and last moved through properly
@test m.md.namespace[:top].first == m.md.namespace[:top].namespace[:A].first == m.md.namespace[:top].namespace[:A].namespace[:Comp1].first== 2005
@test m.md.namespace[:top].last == m.md.namespace[:top].namespace[:A].last ==m.md.namespace[:top].namespace[:A].namespace[:Comp1].last == 2020

@test m.md.namespace[:top].namespace[:B].first == m.md.namespace[:top].namespace[:B].namespace[:Comp3].first== 2010
@test m.md.namespace[:top].namespace[:B].last ==m.md.namespace[:top].namespace[:B].namespace[:Comp3].last == 2015
 

 #
 # Test set_first_last! function 
 #

 m = Model()
 set_dimension!(m, :time, collect(2015:5:2110)) # 20 timesteps
 add_comp!(m, grosseconomy)  
 add_comp!(m, emissions)

 # check that the attributes of the ModelDef and ComponentDef(s) have been set
 # as expected
 @test collect(2015:5:2110) == time_labels(m.md) == [keys(m.md.namespace[:emissions].dim_dict[:time])...] == [keys(m.md.namespace[:grosseconomy].dim_dict[:time])...]
 @test m.md.first == m.md.namespace[:grosseconomy].first == m.md.namespace[:emissions].first
 @test m.md.last == m.md.namespace[:grosseconomy].last == m.md.namespace[:emissions].last

 # now set the emissions first and last and check
 set_first_last!(m, :emissions, first = 2020, last = 2105)

 @test collect(2015:5:2110) == time_labels(m.md) == [keys(m.md.namespace[:emissions].dim_dict[:time])...] == [keys(m.md.namespace[:grosseconomy].dim_dict[:time])...]
 @test m.md.first == m.md.namespace[:grosseconomy].first 
 @test m.md.last == m.md.namespace[:grosseconomy].last
 @test m.md.namespace[:emissions].first == 2020
 @test m.md.namespace[:emissions].last == 2105

 # check warnings
 @test_throws ErrorException set_first_last!(m, :grosseconomy, first = 2000) # too early
 @test_throws ErrorException set_first_last!(m, :grosseconomy, last = 3000)

end #module
