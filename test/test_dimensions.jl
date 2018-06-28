using Mimi
using Base.Test

import Mimi:
    Dimension, key_type

Mimi.reset_compdefs()

dim_varargs = Dimension(:foo, :bar, :baz)   # varargs
dim_vec = Dimension([:foo, :bar, :baz]) # Vector		
dim_range = Dimension(2010:2100)    # Range		
dim_vals = Dimension(4) # Same as 1:4

@test key_type(dim_varargs) == Symbol
@test key_type(dim_vec) == Symbol
@test key_type(dim_range) == Int
@test key_type(dim_vals) == Int

@test length(dim_vals) == 4
@test start(dim_vals) == 1