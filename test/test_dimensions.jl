module TestDimensions

using Mimi
using Test

import Mimi:
    AbstractDimension, RangeDimension, Dimension, key_type,
    reset_compdefs

reset_compdefs()

dim_varargs = Dimension(:foo, :bar, :baz)   # varargs
dim_vec = Dimension([:foo, :bar, :baz]) # Vector		
dim_range = Dimension(2010:2100)     # AbstractRange	
rangedim = RangeDimension(2010:2100) # RangeDimension type	
dim_vals = Dimension(4) # Same as 1:4
dim_vals_abstract = AbstractDimension(dim_vals) # Abstract

@test key_type(dim_varargs) == Symbol
@test key_type(dim_vec) == Symbol
@test key_type(dim_range) == Int
@test key_type(dim_vals) == Int

@test length(dim_varargs) == 3
@test length(dim_vec) == 3
@test length(dim_vals) == 4
@test length(dim_range) == 91
@test length(rangedim) == 91
@test iterate(dim_varargs) == 1

@test iterate(dim_vec) == 1
@test iterate(dim_vals) == 1
@test iterate(dim_range) == 1
@test iterate(rangedim) == 2010

@test endof(dim_varargs) == :baz
@test endof(dim_vec) == :baz
@test endof(dim_range) == 2100
@test endof(dim_vals) == 4


@test Base.keys(rangedim) == [2010:2100...]
@test Base.values(rangedim) == [1:91...]

for i = 1:length(dim_range)
    @test getindex(dim_range, 2010 + i - 1) == i
end
@test dim_range[:] == [1:91...]
@test dim_varargs[:bar] == 2
@test dim_varargs[:] == [1,2,3]
@test dim_vals_abstract[1:4...]== [1:4...]
# @test rangedim[2011] == 2 # TODO: this errors..

@test get(dim_varargs, :bar, 999) == 2
@test get(dim_varargs, :new, 4) == 4 #adds a key/value pair
@test get(rangedim, 2010, 1) == 1 
# @test get(rangedim, 2101, 92) == 92 # TODO:  this errors ...

#test iteratable
dim_vals2 = Dimension(2:2:8)
keys = [2,4,6,8]
index = 1
state = iterate(dim_vals2)
while state != nothing
    (i, state) = iterate(dim_vals2, state)
    @test dim_vals2[keys[index]] == index
    index += 1
end

rangedim2 = RangeDimension(2:2:8)
keys = [2,4,6,8]
index = 1
state = iterate(rangedim2)
while state != nothing
    (i, state) = iterate(rangedim2, state)
    @test get(rangedim2, Base.keys(rangedim2)[index]) == index
    index += 1
end

@test getindex(dim_varargs, :bar) == 2
@test getindex(dim_varargs, :) == [1,2,3]


# Test resetting the time dimension

@defcomp foo2 begin x = Parameter(index=[time]) end 
m = Model()
set_dimension!(m, :time, 2000:2100)
@test_throws ErrorException add_comp!(m, foo2; first = 2005, last = 2105)   # Can't add a component longer than a model
add_comp!(m, foo2; first = 2005, last = 2095)

# Test that foo's time dimension is unchanged
set_dimension!(m, :time, 1990:2200)
@test m.md.comp_defs[:foo2].first == 2005
@test m.md.comp_defs[:foo2].last == 2095

# Test parameter connections
@test_throws ErrorException set_param!(m, :foo2, :x, 1990:2200) # too long
set_param!(m, :foo2, :x, 2005:2095) # Shouldn't throw an error

# Test that foo's time dimension is updated
set_dimension!(m, :time, 2010:2050)
@test m.md.comp_defs[:foo2].first == 2010
@test m.md.comp_defs[:foo2].last == 2050

end #module
