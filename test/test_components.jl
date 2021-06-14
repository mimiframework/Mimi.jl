module TestComponents

using Mimi
using Test

import Mimi:
    compdefs, compdef, compkeys, has_comp, first_period,
    last_period, compmodule, compname, compinstance, dim_keys, dim_values,
    set_first_last!

my_model = Model()

# Try running model with no components
@test length(compdefs(my_model)) == 0
@test length(my_model) == 0
@test_throws ErrorException run(my_model)

# Now add several components to the module
@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])

    """
    Test docstring.
    """
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp testcomp2 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])

    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp testcomp3 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    cbox = Variable(index=[time, 5])    # anonymous dimension

    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

# Testing that you cannot add a component without a time dimension
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Start building up the model
set_dimension!(my_model, :time, 2015:5:2110)
add_comp!(my_model, testcomp1)

# Testing that you cannot add two components of the same name
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Testing to catch adding component twice
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Testing to catch if before or after does not exist
@test_throws ErrorException add_comp!(my_model, testcomp2, before=:testcomp3)

@test_throws ErrorException add_comp!(my_model, testcomp2, after=:testcomp3)

# Add more components to model
add_comp!(my_model, testcomp2)
add_comp!(my_model, testcomp3)

# Check addition of anonymous dimension
dvals = dim_values(my_model.md, Symbol(5))
dkeys = dim_keys(my_model.md, Symbol(5))
@test dvals == dkeys

comps = collect(compdefs(my_model))

# Test compdefs, compdef, compkeys, etc.
@test comps == collect(compdefs(my_model.md))
@test length(comps) == 3
@test compdef(my_model, :testcomp3).comp_id == comps[3].comp_id
@test_throws KeyError compdef(my_model, :testcomp4) #this component does not exist
@test [compkeys(my_model.md)...] == [:testcomp1, :testcomp2, :testcomp3]
@test has_comp(my_model.md, :testcomp1) == true
@test has_comp(my_model.md, :testcomp4) == false

@test compmodule(testcomp3) == Main.TestComponents
@test compname(testcomp3) == :testcomp3

@test length(my_model) == 3
add_comp!(my_model, testcomp3, :testcomp3_v2)
@test length(my_model) == 4


#------------------------------------------------------------------------------
#   Tests for component run periods when resetting the model's time dimension
#------------------------------------------------------------------------------

@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])

    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

# 1. Test resetting the time dimension without explicit first/last values

comp_def = testcomp1
@test comp_def.first === nothing   # original component definition's first and last values are unset
@test comp_def.last === nothing

m = Model()
set_dimension!(m, :time, 2001:2005)
add_comp!(m, testcomp1, :C) # Don't set the first and last values here
comp_def = compdef(m.md, :C)      # Get the component definition in the model
@test comp_def.first === 2001  
@test comp_def.last === 2005

update_param!(m, :C, :par1, zeros(5))
Mimi.build!(m)              # Build the model
ci = compinstance(m, :C)    # Get the component instance
@test ci.first == 2001 && ci.last == 2005      # no change  

set_dimension!(m, :time, 2000:2020) # Reset the time dimension
comp_def = compdef(m.md, :C)        # Get the component definition in the model
@test comp_def.first === 2001 && comp_def.last === 2005 # no change

update_param!(m, :C, :par1, zeros(21))
Mimi.build!(m)               # Build the model
ci = compinstance(m, :C)    # Get the component instance
@test ci.first == 2001 && ci.last == 2005 # no change

set_first_last!(m, :C, first = 2000, last = 2020)
comp_def = compdef(m.md, :C)        # Get the component definition in the model
@test comp_def.first == 2000 && comp_def.last == 2020 # change!

# 2. Test resetting the time dimension with explicit first/last values

m = Model()
set_dimension!(m, :time, 2000:2100)
add_comp!(m, testcomp1, :C; first = 2010, last = 2090)

comp_def = compdef(m.md, :C)      # Get the component definition in the model
@test comp_def.first == 2010 && comp_def.last == 2090

set_dimension!(m, :time, 1950:2090)
update_param!(m, :C, :par1, zeros(141))
Mimi.build!(m)               # Build the model

ci = compinstance(m, :C) # Get the component instance
@test ci.first == 2010 && ci.last == 2090 # The component instance's first and last values are the same as in the comp def

set_dimension!(m, :time, 1940:2200) # Reset the time dimension
update_param!(m, :C, :par1, zeros(261)) # Have to reset the parameter to have the same width as the model time dimension 

comp_def = compdef(m.md, :C)      # Get the component definition in the model
@test comp_def.first == 2010      # First and last values should still be the same
@test comp_def.last == 2090

Mimi.build!(m)               # Build the model
ci = compinstance(m, :C) # Get the component instance
@test ci.first == 2010      # The component instance's first and last values are the same as the comp def
@test ci.last == 2090

end #module
