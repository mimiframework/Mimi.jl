using Mimi
using Test

import Mimi:
    Dimension, key_type

Mimi.reset_compdefs()

dim_varargs = Dimension(:foo, :bar, :baz)   # varargs
dim_vec = Dimension([:foo, :bar, :baz]) # Vector		
dim_range = Dimension(2010:2100)    # AbstractRange		
dim_vals = Dimension(4) # Same as 1:4

@test key_type(dim_varargs) == Symbol
@test key_type(dim_vec) == Symbol
@test key_type(dim_range) == Int
@test key_type(dim_vals) == Int

@test length(dim_varargs) == 3
@test length(dim_vec) == 3
@test length(dim_vals) == 4
@test length(dim_range) == 91

@test iterate(dim_varargs) == 1
@test iterate(dim_vec) == 1
@test iterate(dim_vals) == 1
@test iterate(dim_range) == 1

@test endof(dim_varargs) == :baz
@test endof(dim_vec) == :baz
@test endof(dim_range) == 2100
@test endof(dim_vals) == 4

for i = 1:length(dim_range)
    @test getindex(dim_range, 2010 + i - 1) == i
end
@test getindex(dim_range, :) == [1:91...]

@test getindex(dim_varargs, :bar) == 2
@test getindex(dim_varargs, :) == [1,2,3]
